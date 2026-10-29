import '../l10n/system_messages.dart';
import '../l10n/localization.dart';

import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/controller.dart';
import '../core/models.dart';
import '../core/wechat_import.dart';
import 'common.dart';

Future<void> _parseWorker(
  (SendPort, Uint8List, String, RootIsolateToken) args,
) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.$4);
  try {
    final rows = await parseWechatFile(args.$2, args.$3);
    for (final row in rows) {
      row.sourceKey;
      row.fingerprint;
    }
    args.$1.send(rows);
  } catch (error) {
    args.$1.send(error is FormatException ? error.message : '文件读取失败，请重新导出');
  }
}

class WechatImportScreen extends StatefulWidget {
  const WechatImportScreen({
    super.key,
    required this.controller,
    this.initialItems,
  });
  final LedgerController controller;
  final List<ImportItem>? initialItems;
  @override
  State<WechatImportScreen> createState() => _WechatImportScreenState();
}

class _WechatImportScreenState extends State<WechatImportScreen> {
  List<ImportItem>? _items;
  bool _reading = false, _saving = false;
  int _generation = 0;
  Isolate? _worker;
  ReceivePort? _port;
  Object? _error;
  ImportResult? _result;
  @override
  void initState() {
    super.initState();
    _items = widget.initialItems;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    _generation++;
    _worker?.kill(priority: Isolate.immediate);
    _worker = null;
    _port?.close();
    _port = null;
  }

  Future<void> _pick() async {
    if (_reading || _saving) return;
    final generation = ++_generation;
    setState(() {
      _reading = true;
      _error = null;
      _result = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );
      if (file == null) return;
      if ((await file.length() ?? 0) > importMaxBytes) {
        throw const FormatException('文件超过 20 MB，请分段导出');
      }
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (!mounted || generation != _generation) return;
        if (buffer.length + chunk.length > importMaxBytes) {
          throw const FormatException('文件超过 20 MB，请分段导出');
        }
        buffer.add(chunk);
      }
      if (!mounted || generation != _generation) return;
      final port = ReceivePort();
      _port = port;
      final response = port.first;
      _worker = await Isolate.spawn(_parseWorker, (
        port.sendPort,
        buffer.takeBytes(),
        file.name.split('.').last.toLowerCase(),
        RootIsolateToken.instance!,
      ));
      if (!mounted || generation != _generation) {
        _worker?.kill();
        return;
      }
      final parsed = await response.timeout(Duration(seconds: 60));
      if (parsed is String) throw FormatException(parsed);
      final items = await widget.controller.store.previewWechat(
        parsed as List<WechatRow>,
      );
      if (mounted && generation == _generation) setState(() => _items = items);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error);
      }
    } finally {
      if (generation == _generation) {
        _worker?.kill();
        _worker = null;
        _port?.close();
        _port = null;
        if (mounted) setState(() => _reading = false);
      }
    }
  }

  Future<void> _edit(ImportItem item) async {
    if (item.blocked || _saving || _reading) return;
    var kind = item.kind ?? EntryKind.expense;
    var category = item.categoryId;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final cats = widget.controller.forKind(kind);
          if (!cats.any((c) => c.id == category)) {
            category = cats.isEmpty ? '' : cats.first.id;
          }
          return AlertDialog(
            title: Text(
              item.needsConfirmation
                  ? tr(context).confirmWhatThisTransactionMeans
                  : tr(context).adjustCategory,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.needsConfirmation
                        ? tr(context).pRefundsDoNotAutomaticallyOffsetThe(
                            (systemMessage(context, item.reason) ??
                                tr(context).needsConfirmation),
                          )
                        : tr(context).categorySuggestionsAreForReferenceAndCan,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<EntryKind>(
                    initialValue: kind,
                    decoration: InputDecoration(
                      labelText: tr(context).importAs,
                    ),
                    items: EntryKind.values
                        .map(
                          (k) => DropdownMenuItem(
                            value: k,
                            child: Text(
                              k == EntryKind.expense
                                  ? tr(context).expenses
                                  : tr(context).income,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => update(() {
                      kind = value!;
                      category = widget.controller.forKind(kind).isEmpty
                          ? ''
                          : (suggestImportCategory(
                                  item.row,
                                  kind,
                                  widget.controller.categories,
                                ) ??
                                '');
                    }),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(kind),
                    initialValue: cats.isEmpty ? null : category,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr(context).category,
                    ),
                    items: cats
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => category = value!,
                  ),
                  if (cats.isEmpty)
                    Text(tr(context).noCategoriesAvailableAddOrEnableA),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr(context).cancel),
              ),
              FilledButton(
                onPressed: cats.isEmpty
                    ? null
                    : () => Navigator.pop(context, true),
                child: Text(tr(context).confirmAndSelect),
              ),
            ],
          );
        },
      ),
    );
    if (approved == true && mounted) {
      setState(() {
        item.kind = kind;
        item.categoryId = category;
        item.confirmed = true;
        item.selected = true;
      });
    }
  }

  Future<void> _bulk() async {
    final category = await showDialog<Category>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr(context).setCategoryForSelectedEntries),
        children: widget.controller.categories
            .where((c) => c.active)
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, c),
                child: Text(
                  '${c.kind == EntryKind.income ? tr(context).income : tr(context).expenses} · ${c.name}',
                ),
              ),
            )
            .toList(),
      ),
    );
    if (category != null && mounted) {
      setState(() {
        for (final item in _items!) {
          if (item.selected && item.kind == category.kind) {
            item.categoryId = category.id;
          }
        }
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _reading || _items == null) return;
    final selected = _items!.where((i) => i.selected).length;
    if (selected == 0) return;
    final yes = await confirm(
      context,
      title: tr(context).importPWechatEntries((selected).toString()),
      body: tr(context).addsSelectedEntriesWithoutOverwritingExistingRecords,
      action: tr(context).confirmImport,
    );
    if (!yes || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.controller.importWechat(_items!);
      if (mounted) {
        setState(() {
          _result = result;
          _items = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = const LocalizedFailure(
            'importFailedYourOriginalLedgerIsUnchanged',
            '',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _status(ImportItem item) => item.needsCategory
      ? tr(context).missingCategory
      : switch (item.disposition) {
          ImportDisposition.ready => tr(context).readyToImport,
          ImportDisposition.review =>
            item.confirmed
                ? tr(context).confirmed
                : tr(context).needsConfirmation,
          ImportDisposition.invalid => tr(context).invalid,
          ImportDisposition.excluded => tr(context).excluded,
          ImportDisposition.duplicate => tr(context).duplicate,
          ImportDisposition.conflict => tr(context).conflict,
        };

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final selected = items?.where((i) => i.selected).toList() ?? [];
    final income = selected
        .where((i) => i.kind == EntryKind.income)
        .fold<int>(0, (s, i) => s + i.row.cents!);
    final expense = selected
        .where((i) => i.kind == EntryKind.expense)
        .fold<int>(0, (s, i) => s + i.row.cents!);
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context).importWechatStatements),
          leading: IconButton(
            tooltip: tr(context).back,
            onPressed: _saving ? null : () => Navigator.maybePop(context),
            icon: Icon(LucideIcons.chevronLeft),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        constraints.maxHeight * (items == null ? 0.95 : 0.52),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(tr(context).csvXlsxIsParsedOnThisDevice),
                          SizedBox(height: 12),
                          if (_error != null)
                            Text(
                              errorText(context, _error!),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          if (_result != null)
                            Text(
                              tr(context)
                                  .importCompletePAddedPDuplicatesSkipped(
                                    (_result!.inserted).toString(),
                                    (_result!.duplicates).toString(),
                                    (_result!.unselected).toString(),
                                  ),
                            ),
                          if (_reading || _saving) ...[
                            LinearProgressIndicator(),
                            SizedBox(height: 8),
                            Text(
                              _saving
                                  ? tr(context).submittingPleaseWait
                                  : tr(context).readingAndParsing,
                            ),
                          ],
                          if (_reading)
                            TextButton(
                              onPressed: () {
                                _cancel();
                                setState(() => _reading = false);
                              },
                              child: Text(tr(context).cancelParsing),
                            ),
                          if (!_reading && !_saving)
                            OutlinedButton(
                              onPressed: _pick,
                              child: Text(
                                items == null
                                    ? tr(context).chooseWechatStatementFile
                                    : tr(context).chooseAnotherFile,
                              ),
                            ),
                          if (items != null) ...[
                            Text(
                              tr(context).totalPReadyPDuplicatesPReview(
                                (items.length).toString(),
                                (items
                                        .where(
                                          (i) =>
                                              i.disposition ==
                                                  ImportDisposition.ready &&
                                              !i.needsCategory,
                                        )
                                        .length)
                                    .toString(),
                                (items
                                        .where(
                                          (i) =>
                                              i.disposition ==
                                              ImportDisposition.duplicate,
                                        )
                                        .length)
                                    .toString(),
                                (items
                                        .where(
                                          (i) =>
                                              i.disposition ==
                                                  ImportDisposition.review &&
                                              !i.confirmed,
                                        )
                                        .length)
                                    .toString(),
                                (items
                                        .where(
                                          (i) =>
                                              i.disposition ==
                                                  ImportDisposition.invalid ||
                                              i.disposition ==
                                                  ImportDisposition.conflict,
                                        )
                                        .length)
                                    .toString(),
                                (items
                                        .where(
                                          (i) =>
                                              i.disposition ==
                                              ImportDisposition.excluded,
                                        )
                                        .length)
                                    .toString(),
                              ),
                            ),
                            Text(
                              tr(context).missingCategoryPSelectedPIncomeP(
                                (items.where((i) => i.needsCategory).length)
                                    .toString(),
                                (selected.length).toString(),
                                (money(income)).toString(),
                                (money(expense)).toString(),
                              ),
                            ),
                            Wrap(
                              children: [
                                TextButton(
                                  onPressed: _saving || _reading
                                      ? null
                                      : () => setState(() {
                                          for (final i in items) {
                                            i.selected =
                                                !i.blocked &&
                                                !i.needsCategory &&
                                                (!i.needsConfirmation ||
                                                    i.confirmed);
                                          }
                                        }),
                                  child: Text(
                                    tr(context).selectImportableEntries,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _saving || _reading
                                      ? null
                                      : () => setState(() {
                                          for (final i in items) {
                                            i.selected = false;
                                          }
                                        }),
                                  child: Text(tr(context).deselectAll),
                                ),
                                TextButton(
                                  onPressed: _saving || _reading ? null : _bulk,
                                  child: Text(tr(context).bulkCategory),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (items != null)
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index], row = item.row;
                        return CheckboxListTile(
                          value: item.selected,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: item.blocked || _saving || _reading
                              ? null
                              : (value) {
                                  if (value == true &&
                                      (item.needsCategory ||
                                          (item.needsConfirmation &&
                                              !item.confirmed))) {
                                    _edit(item);
                                  } else {
                                    setState(() => item.selected = value!);
                                  }
                                },
                          title: Text(
                            '${row.date == null ? tr(context).invalidDate : dateLabel(context, row.date!)} · ${row.cents == null ? tr(context).invalidAmount : money(row.cents!)} · ${_status(item)}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(context).sourceRowPPP(
                                  (row.line).toString(),
                                  (row.cells[1]).toString(),
                                  (row.cells[7]).toString(),
                                ),
                              ),
                              Text(
                                row.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.reason.isNotEmpty)
                                Text(
                                  systemMessage(context, item.reason) ??
                                      tr(context).needsConfirmation,
                                ),
                              if (item.needsCategory)
                                Text(
                                  tr(context).noAvailableCategoryAddOrEnableOne,
                                ),
                              if (!item.blocked)
                                TextButton(
                                  onPressed: _saving || _reading
                                      ? null
                                      : () => _edit(item),
                                  child: Text(
                                    tr(context).pPAdjust(
                                      (item.kind == EntryKind.income
                                              ? tr(context).income
                                              : tr(context).expenses)
                                          .toString(),
                                      (item.needsCategory
                                              ? tr(context).categoryNotSet
                                              : categoryLabel(
                                                  context,
                                                  widget.controller.category(
                                                    item.categoryId,
                                                  ),
                                                ))
                                          .toString(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                if (items != null)
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving || _reading || selected.isEmpty
                            ? null
                            : _save,
                        child: Text(
                          tr(context)
                              .importPEntries((selected.length).toString()),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
