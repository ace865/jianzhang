import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'common.dart';
import 'theme.dart';

Future<void> showEntryEditor(
  BuildContext context,
  LedgerController controller, {
  LedgerEntry? entry,
  DateTime? date,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (context) =>
      EntryEditor(controller: controller, entry: entry, date: date),
);

class EntryEditor extends StatefulWidget {
  const EntryEditor({
    super.key,
    required this.controller,
    this.entry,
    this.date,
  });
  final LedgerController controller;
  final LedgerEntry? entry;
  final DateTime? date;
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  late EntryKind _kind;
  late String _amount, _category, _payment;
  late DateTime _date;
  late TextEditingController _note;
  final _noteFocus = FocusNode();
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _kind = entry?.kind ?? EntryKind.expense;
    _amount = entry == null ? '' : moneyInput(entry.cents);
    _category =
        entry?.categoryId ??
        widget.controller.forKind(_kind).firstOrNull?.id ??
        '';
    _date = entry?.date ?? widget.date ?? onlyDay(DateTime.now());
    _payment = entry?.payment ?? '未注明';
    _note = TextEditingController(text: entry?.note ?? '');
    _noteFocus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _key(String value) {
    if (_saving) return;
    setState(() {
      if (value == '⌫') {
        if (_amount.isNotEmpty) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
        return;
      }
      if (value == '.') {
        if (!_amount.contains('.')) {
          _amount = _amount.isEmpty ? '0.' : '$_amount.';
        }
        return;
      }
      if (_amount.contains('.') && _amount.split('.')[1].length >= 2) return;
      if (!_amount.contains('.') && _amount.length >= 9) return;
      _amount = _amount == '0' ? value : '$_amount$value';
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final cents = parseMoney(_amount);
    if (cents == null) {
      message(context, '请输入大于 0、最多两位小数的金额');
      return;
    }
    if (_category.isEmpty) {
      message(context, '请先在设置中添加或启用分类');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.save(
        LedgerEntry(
          id: widget.entry?.id ?? newId(),
          kind: _kind,
          cents: cents,
          categoryId: _category,
          date: _date,
          payment: _payment,
          note: _note.text.trim(),
          createdAt:
              widget.entry?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (mounted) {
        Navigator.pop(context);
        message(context, widget.entry == null ? '已记下这一笔' : '账单已更新');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        message(context, errorText(error));
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirm(
      context,
      title: '删除这笔账单？',
      body:
          '${dayKey(_date)} · ${money(widget.entry!.cents)}\n删除后，相关统计和预算会同步更新。',
      action: '删除',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.controller.delete(widget.entry!.id);
      if (mounted) {
        Navigator.pop(context);
        message(context, '账单已删除');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        message(context, errorText(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = InkColors.of(context);
    final categories = widget.controller.forKind(
      _kind,
      include: widget.entry?.categoryId,
    );
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final height = math.max(
      280.0,
      MediaQuery.sizeOf(context).height * 0.91 - bottom,
    );
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: height,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ink.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 22, right: 10, top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.entry == null ? '记一笔' : '编辑账单',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (widget.entry != null)
                        IconButton(
                          tooltip: '删除账单',
                          onPressed: _saving ? null : _delete,
                          icon: Icon(
                            LucideIcons.trash2,
                            size: 20,
                            color: ink.danger,
                          ),
                        ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.x, size: 22),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KindSwitch(
                          value: _kind,
                          onChanged: (value) {
                            if (_saving) return;
                            setState(() {
                              _kind = value;
                              _category =
                                  widget.controller
                                      .forKind(value)
                                      .firstOrNull
                                      ?.id ??
                                  '';
                            });
                          },
                        ),
                        GestureDetector(
                          onTap: () => _noteFocus.unfocus(),
                          child: Semantics(
                            label: '金额 ${_amount.isEmpty ? '0' : _amount} 元',
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '¥ ${_amount.isEmpty ? '0.00' : _amount}',
                                  key: const ValueKey('entry-amount'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(fontSize: 38),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (categories.isEmpty)
                          const EmptyView(
                            title: '还没有可用分类',
                            subtitle: '请到设置中的分类管理添加或启用分类。',
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) => Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: categories
                                  .map(
                                    (category) => SizedBox(
                                      width: (constraints.maxWidth - 12) / 4,
                                      child: Semantics(
                                        selected: category.id == _category,
                                        button: true,
                                        label: '${category.name}分类',
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          onTap: _saving
                                              ? null
                                              : () => setState(
                                                  () => _category = category.id,
                                                ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  categoryGlyph(category.icon),
                                                  size: 26,
                                                  color: ink.ink,
                                                ),
                                                const SizedBox(height: 7),
                                                Text(
                                                  category.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: ink.ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Container(
                                                  width: 32,
                                                  height: 2,
                                                  color:
                                                      _category == category.id
                                                      ? ink.accent
                                                      : Colors.transparent,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Panel(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              _field(
                                context,
                                LucideIcons.calendarDays,
                                '日期',
                                dayKey(_date),
                                () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _date,
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime(2100, 12, 31),
                                  );
                                  if (date != null && mounted) {
                                    setState(() => _date = date);
                                  }
                                },
                              ),
                              const Divider(),
                              _field(
                                context,
                                LucideIcons.wallet,
                                '支付方式',
                                _payment,
                                () async {
                                  final value =
                                      await showModalBottomSheet<String>(
                                        context: context,
                                        showDragHandle: true,
                                        builder: (context) => SafeArea(
                                          child: ListView(
                                            shrinkWrap: true,
                                            children: paymentMethods
                                                .map(
                                                  (method) => ListTile(
                                                    title: Text(method),
                                                    trailing: method == _payment
                                                        ? const Icon(
                                                            LucideIcons.check,
                                                            size: 20,
                                                          )
                                                        : null,
                                                    onTap: () => Navigator.pop(
                                                      context,
                                                      method,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ),
                                      );
                                  if (value != null && mounted) {
                                    setState(() => _payment = value);
                                  }
                                },
                              ),
                              const Divider(),
                              TextField(
                                controller: _note,
                                focusNode: _noteFocus,
                                maxLength: 500,
                                minLines: 1,
                                maxLines: 3,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _noteFocus.unfocus(),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(
                                    LucideIcons.notebookPen,
                                    size: 18,
                                  ),
                                  hintText: '备注（可选）',
                                  counterText: '',
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!_noteFocus.hasFocus)
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 2.7,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 8,
                            children:
                                [
                                      '1',
                                      '2',
                                      '3',
                                      '4',
                                      '5',
                                      '6',
                                      '7',
                                      '8',
                                      '9',
                                      '.',
                                      '0',
                                      '⌫',
                                    ]
                                    .map(
                                      (key) => Material(
                                        color: ink.panel,
                                        borderRadius: BorderRadius.circular(10),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          onTap: () => _key(key),
                                          onLongPress: key == '⌫'
                                              ? () =>
                                                    setState(() => _amount = '')
                                              : null,
                                          child: Center(
                                            child: key == '⌫'
                                                ? const Icon(
                                                    LucideIcons.delete,
                                                    size: 20,
                                                  )
                                                : Text(
                                                    key,
                                                    style: const TextStyle(
                                                      fontSize: 21,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.entry == null ? '保存账单' : '保存修改'),
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

  Widget _field(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    VoidCallback tap,
  ) => InkWell(
    onTap: _saving ? null : tap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 13, color: InkColors.of(context).muted),
          ),
          const SizedBox(width: 5),
          const Icon(LucideIcons.chevronRight, size: 16),
        ],
      ),
    ),
  );
}
