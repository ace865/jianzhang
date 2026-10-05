import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'charts.dart';
import 'common.dart';
import 'theme.dart';

typedef AnalysisData = ({
  List<CategoryTotal> categories,
  List<TrendPoint> trend,
});

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    required this.controller,
    required this.openLedger,
  });
  final LedgerController controller;
  final ValueChanged<EntryFilter> openLedger;
  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  PeriodWindow _window = PeriodWindow(Period.month, DateTime.now());
  EntryKind _kind = EntryKind.expense;
  late Future<AnalysisData> _future;
  int _revision = -1;
  @override
  void initState() {
    super.initState();
    _reload();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_revision != widget.controller.revision && mounted) setState(_reload);
  }

  void _reload() {
    _revision = widget.controller.revision;
    _future = _read(_window, _kind);
  }

  Future<AnalysisData> _read(PeriodWindow window, EntryKind kind) async {
    final results = await Future.wait<Object>([
      widget.controller.store.categoryTotals(window, kind),
      widget.controller.store.trend(window),
    ]);
    return (
      categories: results[0] as List<CategoryTotal>,
      trend: results[1] as List<TrendPoint>,
    );
  }

  void _openCategory(String id) => widget.openLedger(
    EntryFilter(
      start: _window.start,
      end: _window.end,
      kind: _kind,
      categoryId: id,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final ink = InkColors.of(context);
    return ListView(
      key: const PageStorageKey('analysis'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
      children: [
        Text('收支分析', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        WindowPicker(
          window: _window,
          onChanged: (value) => setState(() {
            _window = value;
            _reload();
          }),
        ),
        const SizedBox(height: 14),
        KindSwitch(
          value: _kind,
          onChanged: (value) => setState(() {
            _kind = value;
            _reload();
          }),
        ),
        const SizedBox(height: 18),
        AsyncContent(
          future: _future,
          retry: () => setState(_reload),
          builder: (data) {
            final total = data.categories.fold<int>(0, (s, c) => s + c.cents);
            return Column(
              children: [
                Panel(
                  child: Column(
                    children: [
                      SectionTitle(
                        '分类占比',
                        trailing: Text(
                          _window.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      CategoryRing(
                        items: data.categories,
                        income: _kind == EntryKind.income,
                        reducedMotion:
                            widget.controller.reducedMotion ||
                            MediaQuery.disableAnimationsOf(context),
                        onCategory: _openCategory,
                      ),
                      ...data.categories.asMap().entries.map((pair) {
                        final item = pair.value,
                            category = widget.controller.category(
                              item.categoryId,
                            );
                        return InkWell(
                          onTap: () => _openCategory(item.categoryId),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color:
                                        ink.chart[pair.key % ink.chart.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(category.name),
                                      Text(
                                        '${item.count} 笔',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  money(item.cents),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                SizedBox(
                                  width: 42,
                                  child: Text(
                                    '${(item.cents / total * 100).toStringAsFixed(1)}%',
                                    textAlign: TextAlign.right,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                if (_window.period != Period.day) ...[
                  const SizedBox(height: 14),
                  Panel(
                    child: Column(
                      children: [
                        SectionTitle(
                          _window.period == Period.year
                              ? '年度收支对比'
                              : _kind == EntryKind.expense
                              ? '月度支出趋势'
                              : '月度收入趋势',
                          trailing: Text(
                            _window.label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (_window.period == Period.year)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                Text(
                                  '● 收入',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ink.income,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Text(
                                  '● 支出',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ink.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SpendingTrend(
                          points: data.trend,
                          yearly: _window.period == Period.year,
                          income: _kind == EntryKind.income,
                          reducedMotion:
                              widget.controller.reducedMotion ||
                              MediaQuery.disableAnimationsOf(context),
                          onPoint: (index) {
                            final date = _window.period == Period.year
                                ? DateTime(_window.date.year, index + 1)
                                : DateTime(
                                    _window.date.year,
                                    _window.date.month,
                                    index + 1,
                                  );
                            final win = PeriodWindow(
                              _window.period == Period.year
                                  ? Period.month
                                  : Period.day,
                              date,
                            );
                            widget.openLedger(
                              EntryFilter(
                                start: win.start,
                                end: win.end,
                                kind: _window.period == Period.year
                                    ? null
                                    : _kind,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
