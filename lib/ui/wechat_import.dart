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
  String? _error;
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
      final parsed = await response.timeout(const Duration(seconds: 60));
      if (parsed is String) throw FormatException(parsed);
      final items = await widget.controller.store.previewWechat(
        parsed as List<WechatRow>,
      );
      if (mounted && generation == _generation) setState(() => _items = items);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : '读取失败，请检查文件并重试',
        );
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
            title: Text(item.needsConfirmation ? '确认这笔交易的含义' : '调整分类'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.needsConfirmation
                        ? '${item.reason}\n退款不会自动抵扣原消费。作为收入或支出导入将影响统计，请确认。'
                        : '分类建议仅供参考，可以手动调整。',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EntryKind>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: '作为'),
                    items: EntryKind.values
                        .map(
                          (k) => DropdownMenuItem(
                            value: k,
                            child: Text(k == EntryKind.expense ? '支出' : '收入'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => update(() {
                      kind = value!;
                      category = widget.controller.forKind(kind).isEmpty
                          ? ''
                          : suggestImportCategory(
                              item.row,
                              kind,
                              widget.controller.categories,
                            );
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(kind),
                    initialValue: cats.isEmpty ? null : category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '分类'),
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
                  if (cats.isEmpty) const Text('没有可用分类，请先在分类管理中启用或添加分类。'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: cats.isEmpty
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('确认并选入'),
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
        title: const Text('批量设置已选账单分类'),
        children: widget.controller.categories
            .where((c) => c.active)
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, c),
                child: Text(
                  '${c.kind == EntryKind.income ? '收入' : '支出'} · ${c.name}',
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
      title: '导入 $selected 笔微信账单？',
      body: '将新增选中的账单，不覆盖已有记录。建议先在设置中保存完整备份。',
      action: '确认导入',
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
      if (mounted) setState(() => _error = '导入失败，原账本未更改。请重新选择文件预览，检查分类及待确认账单。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _status(ImportItem item) => switch (item.disposition) {
    ImportDisposition.ready => '可导入',
    ImportDisposition.review => item.confirmed ? '已确认' : '待确认',
    ImportDisposition.invalid => '异常',
    ImportDisposition.excluded => '不入账',
    ImportDisposition.duplicate => '重复',
    ImportDisposition.conflict => '冲突',
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
          title: const Text('导入微信账单'),
          leading: IconButton(
            tooltip: '返回',
            onPressed: _saving ? null : () => Navigator.maybePop(context),
            icon: const Icon(LucideIcons.chevronLeft),
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '本机解析 CSV / .xlsx，不上传账单。退款、转账等需单独确认。文件上限 20 MB / 20,000 条。',
                          ),
                          const SizedBox(height: 12),
                          if (_error != null)
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          if (_result != null)
                            Text(
                              '导入完成：成功 ${_result!.inserted} 笔，重复跳过 ${_result!.duplicates} 笔，未选入 ${_result!.unselected} 笔。',
                            ),
                          if (_reading || _saving) ...[
                            const LinearProgressIndicator(),
                            const SizedBox(height: 8),
                            Text(_saving ? '正在提交，请稍候…' : '正在读取与解析…'),
                          ],
                          if (_reading)
                            TextButton(
                              onPressed: () {
                                _cancel();
                                setState(() => _reading = false);
                              },
                              child: const Text('取消解析'),
                            ),
                          if (!_reading && !_saving)
                            OutlinedButton(
                              onPressed: _pick,
                              child: Text(
                                items == null ? '选择微信账单文件' : '重新选择文件',
                              ),
                            ),
                          if (items != null) ...[
                            Text(
                              '共 ${items.length} 笔 · 可导入 ${items.where((i) => i.disposition == ImportDisposition.ready).length} · 重复 ${items.where((i) => i.disposition == ImportDisposition.duplicate).length}\n待确认 ${items.where((i) => i.disposition == ImportDisposition.review && !i.confirmed).length} · 异常/冲突 ${items.where((i) => i.disposition == ImportDisposition.invalid || i.disposition == ImportDisposition.conflict).length} · 不入账 ${items.where((i) => i.disposition == ImportDisposition.excluded).length}',
                            ),
                            Text(
                              '已选 ${selected.length} 笔 · 收入 ${money(income)} · 支出 ${money(expense)}',
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
                                                (!i.needsConfirmation ||
                                                    i.confirmed);
                                          }
                                        }),
                                  child: const Text('选择可导入账单'),
                                ),
                                TextButton(
                                  onPressed: _saving || _reading
                                      ? null
                                      : () => setState(() {
                                          for (final i in items) {
                                            i.selected = false;
                                          }
                                        }),
                                  child: const Text('全部取消'),
                                ),
                                TextButton(
                                  onPressed: _saving || _reading ? null : _bulk,
                                  child: const Text('批量分类'),
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
                                      item.needsConfirmation &&
                                      !item.confirmed) {
                                    _edit(item);
                                  } else {
                                    setState(() => item.selected = value!);
                                  }
                                },
                          title: Text(
                            '${row.date == null ? "无效日期" : dayKey(row.date!)} · ${row.cents == null ? "无效金额" : money(row.cents!)} · ${_status(item)}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '原文件第 ${row.line} 行 · ${row.cells[1]} · ${row.cells[7]}',
                              ),
                              Text(
                                row.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.reason.isNotEmpty) Text(item.reason),
                              if (!item.blocked)
                                TextButton(
                                  onPressed: _saving || _reading
                                      ? null
                                      : () => _edit(item),
                                  child: Text(
                                    '${item.kind == EntryKind.income ? "收入" : "支出"} · ${widget.controller.category(item.categoryId).name} · 调整',
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
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving || _reading || selected.isEmpty
                            ? null
                            : _save,
                        child: Text('导入 ${selected.length} 笔'),
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
