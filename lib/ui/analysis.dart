import '../l10n/localization.dart';

import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'charts.dart';
import 'ai.dart';
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
      key: PageStorageKey('analysis'),
      padding: EdgeInsets.fromLTRB(20, 18, 20, 104),
      children: [
        Text(
          tr(context).incomeAndExpenseAnalysis,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: 12),
        WindowPicker(
          window: _window,
          onChanged: (value) => setState(() {
            _window = value;
            _reload();
          }),
        ),
        SizedBox(height: 14),
        KindSwitch(
          value: _kind,
          onChanged: (value) => setState(() {
            _kind = value;
            _reload();
          }),
        ),
        SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(tr(context).aiAnalysis),
              SizedBox(height: 8),
              Text(
                tr(context).pPAnalysisSummariesOnlyWithA(
                  (periodLabel(context, _window)).toString(),
                  (_kind == EntryKind.expense
                          ? tr(context).expenses
                          : tr(context).income)
                      .toString(),
                ),
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AiAnalysisScreen(
                      controller: widget.controller,
                      window: _window,
                      focus: _kind,
                    ),
                  ),
                ),
                child: Text(tr(context).viewGenerateAnalysis),
              ),
            ],
          ),
        ),
        SizedBox(height: 18),
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
                        tr(context).categoryBreakdown,
                        trailing: Text(
                          periodLabel(context, _window),
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
                            padding: EdgeInsets.symmetric(vertical: 12),
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
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(categoryLabel(context, category)),
                                      Text(
                                        tr(context).pEntries(item.count),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  money(item.cents),
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                SizedBox(width: 15),
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
                  SizedBox(height: 14),
                  Panel(
                    child: Column(
                      children: [
                        SectionTitle(
                          _window.period == Period.year
                              ? tr(context).annualIncomeAndExpenses
                              : _kind == EntryKind.expense
                              ? tr(context).monthlyExpenseTrend
                              : tr(context).monthlyIncomeTrend,
                          trailing: Text(
                            periodLabel(context, _window),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (_window.period == Period.year)
                          Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                Text(
                                  tr(context).income131,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ink.income,
                                  ),
                                ),
                                SizedBox(width: 18),
                                Text(
                                  tr(context).expenses132,
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
