import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'common.dart';
import 'entry_editor.dart';
import 'theme.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key, required this.controller, this.initialFilter});
  final LedgerController controller;
  final EntryFilter? initialFilter;
  @override
  State<LedgerScreen> createState() => LedgerScreenState();
}

class LedgerScreenState extends State<LedgerScreen> {
  late EntryFilter _filter;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  List<LedgerEntry> _entries = [];
  Map<String, Totals> _daily = {};
  Totals _totals = const Totals();
  bool _loading = true, _more = false, _calendar = false;
  String? _error;
  int _generation = 0, _revision = -1;
  @override
  void initState() {
    super.initState();
    final window = PeriodWindow(Period.month, DateTime.now());
    _filter =
        widget.initialFilter ??
        EntryFilter(start: window.start, end: window.end);
    _search.text = _filter.search;
    _reload();
    widget.controller.addListener(_changed);
    _scroll.addListener(_scrollChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_revision != widget.controller.revision) _reload();
  }

  void _scrollChanged() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 400 &&
        !_loading &&
        !_more &&
        !_calendar &&
        _entries.length < _totals.count) {
      _loadMore();
    }
  }

  void applyFilter(EntryFilter filter) {
    _debounce?.cancel();
    _filter = filter;
    _search.text = filter.search;
    _calendar = false;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _reload();
  }

  Future<void> _reload() async {
    _revision = widget.controller.revision;
    final generation = ++_generation;
    final filter = _filter;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _more = false;
      });
    }
    try {
      final results = await Future.wait<Object>([
        widget.controller.store.entries(filter),
        widget.controller.store.totals(filter),
        widget.controller.store.dailyTotals(filter),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries = results[0] as List<LedgerEntry>;
        _totals = results[1] as Totals;
        _daily = results[2] as Map<String, Totals>;
        _loading = false;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = errorText(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final generation = _generation;
    setState(() => _more = true);
    try {
      final next = await widget.controller.store.entries(
        _filter,
        offset: _entries.length,
      );
      if (mounted && generation == _generation) {
        setState(() => _entries.addAll(next));
      }
    } catch (error) {
      if (mounted) message(context, errorText(error));
    } finally {
      if (mounted && generation == _generation) setState(() => _more = false);
    }
  }

  void _filters({
    EntryKind? kind,
    String? category,
    String? payment,
    bool clearKind = false,
    bool clearCategory = false,
    bool clearPayment = false,
    String? search,
    DateTime? start,
    DateTime? end,
  }) {
    _filter = EntryFilter(
      start: start ?? _filter.start,
      end: end ?? _filter.end,
      kind: clearKind ? null : kind ?? _filter.kind,
      categoryId: clearCategory ? null : category ?? _filter.categoryId,
      payment: clearPayment ? null : payment ?? _filter.payment,
      search: search ?? _filter.search,
    );
    _reload();
  }

  void _shift(int delta) {
    final date = _filter.start ?? DateTime.now();
    final window = PeriodWindow(
      Period.month,
      DateTime(date.year, date.month + delta),
    );
    _filters(start: window.start, end: window.end);
  }

  String get _rangeLabel {
    final start = _filter.start;
    final end = _filter.end;
    if (start == null || end == null) return '全部日期';
    if (start.day == 1 && end == DateTime(start.year, start.month + 1)) {
      return '${start.year}年${start.month}月';
    }
    if (end.difference(start).inDays == 1) {
      return '${start.year}年${start.month}月${start.day}日';
    }
    return '${dayKey(start)} — ${dayKey(end.subtract(const Duration(days: 1)))}';
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: DateTimeRange(
        start: _filter.start ?? DateTime.now(),
        end: (_filter.end ?? DateTime.now().add(const Duration(days: 1)))
            .subtract(const Duration(days: 1)),
      ),
      helpText: '筛选账单日期',
      saveText: '应用',
    );
    if (range != null) {
      _filters(
        start: range.start,
        end: DateTime(range.end.year, range.end.month, range.end.day + 1),
      );
    }
  }

  Future<void> _day(DateTime day) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          DaySheet(controller: widget.controller, date: day, filter: _filter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = InkColors.of(context);
    final rows = <Object>[];
    String? previous;
    for (final entry in _entries) {
      final key = dayKey(entry.date);
      if (previous != key) {
        rows.add(key);
        previous = key;
      }
      rows.add(entry);
    }
    return CustomScrollView(
      controller: _scroll,
      key: const PageStorageKey('ledger'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '账单',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: '导出筛选账单',
                      onPressed: widget.controller.busy
                          ? null
                          : () async {
                              try {
                                final saved = await widget.controller.exportCsv(
                                  _filter,
                                );
                                if (saved && context.mounted) {
                                  message(context, '账单已导出');
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  message(context, errorText(error));
                                }
                              }
                            },
                      icon: const Icon(LucideIcons.download, size: 21),
                    ),
                    IconButton(
                      tooltip: '选择日期范围',
                      onPressed: _pickRange,
                      icon: const Icon(LucideIcons.calendarDays, size: 21),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: '上个月',
                      onPressed: (_filter.start?.year ?? 2000) <= 1900
                          ? null
                          : () => _shift(-1),
                      icon: const Icon(LucideIcons.chevronLeft, size: 18),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: _pickRange,
                        child: Text(
                          _rangeLabel,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: ink.ink),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '下个月',
                      onPressed: (_filter.start?.year ?? 2000) >= 2100
                          ? null
                          : () => _shift(1),
                      icon: const Icon(LucideIcons.chevronRight, size: 18),
                    ),
                  ],
                ),
                ChoiceStrip(
                  labels: const ['列表', '日历'],
                  index: _calendar ? 1 : 0,
                  onChanged: (i) => setState(() => _calendar = i == 1),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: '搜索备注或分类',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _search.text.isNotEmpty
                        ? IconButton(
                            tooltip: '清除搜索',
                            onPressed: () {
                              _debounce?.cancel();
                              _search.clear();
                              _filters(search: '');
                            },
                            icon: const Icon(LucideIcons.x, size: 18),
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {});
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 250),
                      () => _filters(search: value),
                    );
                  },
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip<String>(
                        context,
                        _filter.kind == null
                            ? '全部类型'
                            : _filter.kind == EntryKind.expense
                            ? '支出'
                            : '收入',
                        [
                          const PopupMenuItem(
                            value: 'all',
                            child: Text('全部类型'),
                          ),
                          const PopupMenuItem(
                            value: 'expense',
                            child: Text('支出'),
                          ),
                          const PopupMenuItem(
                            value: 'income',
                            child: Text('收入'),
                          ),
                        ],
                        (value) => _filters(
                          kind: value == 'all'
                              ? null
                              : EntryKind.values.byName(value),
                          clearKind: value == 'all',
                          clearCategory: true,
                        ),
                      ),
                      const SizedBox(width: 7),
                      _chip<String>(
                        context,
                        _filter.categoryId == null
                            ? '全部分类'
                            : widget.controller
                                  .category(_filter.categoryId!)
                                  .name,
                        [
                          const PopupMenuItem(
                            value: 'all',
                            child: Text('全部分类'),
                          ),
                          ...widget.controller.categories
                              .where(
                                (c) =>
                                    _filter.kind == null ||
                                    c.kind == _filter.kind,
                              )
                              .map(
                                (c) => PopupMenuItem(
                                  value: c.id,
                                  child: Text(
                                    '${c.name}${c.active ? '' : '（已停用）'}',
                                  ),
                                ),
                              ),
                        ],
                        (value) => _filters(
                          category: value == 'all' ? null : value,
                          clearCategory: value == 'all',
                        ),
                      ),
                      const SizedBox(width: 7),
                      _chip<String>(
                        context,
                        _filter.payment ?? '支付方式',
                        [
                          const PopupMenuItem(
                            value: 'all',
                            child: Text('全部支付方式'),
                          ),
                          ...paymentMethods.map(
                            (p) => PopupMenuItem(value: p, child: Text(p)),
                          ),
                        ],
                        (value) => _filters(
                          payment: value == 'all' ? null : value,
                          clearPayment: value == 'all',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Panel(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '收入',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 5),
                            FittedBox(
                              child: Text(
                                money(_totals.income),
                                style: TextStyle(
                                  color: ink.income,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '支出',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 5),
                            FittedBox(
                              child: Text(
                                money(_totals.expense),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else if (_error != null)
          SliverToBoxAdapter(
            child: EmptyView(
              title: '读取账单失败',
              subtitle: _error!,
              action: TextButton(onPressed: _reload, child: const Text('重试')),
            ),
          )
        else if (_calendar)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(child: _buildCalendar(context)),
          )
        else if (rows.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyView(
              title: '没有符合条件的账单',
              subtitle: '试着调整筛选条件，或点击下方记一笔。',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                if (row is String) {
                  final total = _daily[row] ?? const Totals();
                  return Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '支出 ${money(total.expense)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: ink.panel,
                    border: Border(
                      bottom: BorderSide(color: ink.border, width: 0.6),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: EntryTile(
                      entry: row as LedgerEntry,
                      controller: widget.controller,
                      onTap: () => showEntryEditor(
                        context,
                        widget.controller,
                        entry: row,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (!_calendar && !_loading && _entries.length < _totals.count)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: _more ? null : _loadMore,
                child: Text(
                  _more ? '正在加载…' : '加载更多（${_entries.length}/${_totals.count}）',
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  Widget _chip<T>(
    BuildContext context,
    String label,
    List<PopupMenuEntry<T>> options,
    ValueChanged<T> choose,
  ) => PopupMenuButton<T>(
    onSelected: choose,
    itemBuilder: (_) => options,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        border: Border.all(color: InkColors.of(context).border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          const Icon(LucideIcons.chevronDown, size: 13),
        ],
      ),
    ),
  );
  Widget _buildCalendar(BuildContext context) {
    final ink = InkColors.of(context), month = _filter.start ?? DateTime.now();
    final first = DateTime(month.year, month.month),
        length = DateTime(month.year, month.month + 1, 0).day,
        offset = first.weekday - 1;
    return Column(
      children: [
        Panel(
          child: Column(
            children: [
              Text(
                '${month.year}年${month.month}月',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: ['一', '二', '三', '四', '五', '六', '日']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 61,
                ),
                itemCount: ((offset + length + 6) ~/ 7) * 7,
                itemBuilder: (context, index) {
                  final number = index - offset + 1;
                  if (number < 1 || number > length) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime(month.year, month.month, number),
                      day = _daily[dayKey(date)];
                  final today = dayKey(date) == dayKey(DateTime.now());
                  return InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => _day(date),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$number',
                          style: TextStyle(
                            color: today ? ink.accent : ink.ink,
                            fontWeight: today
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 5),
                        if (day != null)
                          FittedBox(
                            child: Text(
                              day.expense > 0
                                  ? '−${money(day.expense, symbol: false)}'
                                  : '+${money(day.income, symbol: false)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: day.expense > 0
                                    ? ink.accent
                                    : ink.income,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '点击日期查看账单，或写一段当天的小记。\n金额遵循当前筛选条件。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class DaySheet extends StatefulWidget {
  const DaySheet({
    super.key,
    required this.controller,
    required this.date,
    required this.filter,
  });
  final LedgerController controller;
  final DateTime date;
  final EntryFilter filter;
  @override
  State<DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<DaySheet> {
  final _note = TextEditingController();
  late Future<List<LedgerEntry>> _future;
  bool _saving = false, _ready = false;
  @override
  void initState() {
    super.initState();
    _future = _read();
  }

  Future<List<LedgerEntry>> _read() async {
    if (!_ready) {
      final note = await widget.controller.store.note(widget.date);
      if (mounted) {
        _note.text = note;
        _ready = true;
      }
    }
    final end = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day + 1,
    );
    return widget.controller.store.entries(
      EntryFilter(
        start: widget.date,
        end: end,
        kind: widget.filter.kind,
        categoryId: widget.filter.categoryId,
        payment: widget.filter.payment,
        search: widget.filter.search,
      ),
      limit: null,
    );
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dayKey(widget.date),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '为这一天记账',
                  onPressed: () async {
                    await showEntryEditor(
                      context,
                      widget.controller,
                      date: widget.date,
                    );
                    if (mounted) {
                      setState(() {
                        _future = _read();
                      });
                    }
                  },
                  icon: const Icon(LucideIcons.plus),
                ),
              ],
            ),
            AsyncContent(
              future: _future,
              retry: () => setState(() {
                _future = _read();
              }),
              builder: (entries) => Column(
                children: [
                  if (entries.isEmpty)
                    const EmptyView(
                      title: '这一天还没有符合条件的账单',
                      subtitle: '可以补记账单，也可以留下小记。',
                    )
                  else
                    ...entries.map(
                      (entry) => EntryTile(
                        entry: entry,
                        controller: widget.controller,
                        onTap: () async {
                          await showEntryEditor(
                            context,
                            widget.controller,
                            entry: entry,
                          );
                          if (mounted) {
                            setState(() {
                              _future = _read();
                            });
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _note,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: '每日小记',
                      hintText: '今天有哪些值得记下的事情？',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: !_ready || _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              try {
                                await widget.controller.saveNote(
                                  widget.date,
                                  _note.text,
                                );
                                if (context.mounted) {
                                  FocusScope.of(context).unfocus();
                                  message(context, '小记已保存');
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  message(context, errorText(error));
                                }
                              } finally {
                                if (mounted) setState(() => _saving = false);
                              }
                            },
                      child: Text(_saving ? '保存中…' : '保存小记'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
