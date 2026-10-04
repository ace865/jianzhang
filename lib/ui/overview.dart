import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'charts.dart';
import 'common.dart';
import 'entry_editor.dart';
import 'settings.dart';
import 'theme.dart';

typedef OverviewData = ({
  Totals totals,
  List<TrendPoint> trend,
  List<BudgetStatus> budgets,
  List<LedgerEntry> recent,
});

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({
    super.key,
    required this.controller,
    required this.openLedger,
  });
  final LedgerController controller;
  final ValueChanged<EntryFilter> openLedger;
  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  PeriodWindow _window = PeriodWindow(Period.month, DateTime.now());
  late Future<OverviewData> _future;
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
    _future = _read(_window);
  }

  Future<OverviewData> _read(PeriodWindow window) async {
    final filter = EntryFilter(start: window.start, end: window.end);
    final results = await Future.wait<Object>([
      widget.controller.store.totals(filter),
      widget.controller.store.trend(window),
      widget.controller.store.budgets(window.date),
      widget.controller.store.entries(filter, limit: 4),
    ]);
    return (
      totals: results[0] as Totals,
      trend: results[1] as List<TrendPoint>,
      budgets: results[2] as List<BudgetStatus>,
      recent: results[3] as List<LedgerEntry>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = InkColors.of(context);
    return ListView(
      key: const PageStorageKey('overview'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '简账',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              key: const ValueKey('theme-toggle'),
              tooltip: widget.controller.dark ? '切换到浅色主题' : '切换到深色主题',
              onPressed: () async {
                try {
                  await widget.controller.toggleTheme();
                } catch (error) {
                  if (context.mounted) message(context, errorText(error));
                }
              },
              icon: Icon(
                widget.controller.dark ? LucideIcons.sun : LucideIcons.moon,
                size: 23,
              ),
            ),
          ],
        ),
        WindowPicker(
          window: _window,
          onChanged: (window) => setState(() {
            _window = window;
            _reload();
          }),
        ),
        const SizedBox(height: 10),
        AsyncContent(
          future: _future,
          retry: () => setState(_reload),
          builder: (data) {
            final totalBudget = data.budgets
                .where((b) => b.categoryId.isEmpty)
                .firstOrNull;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_window.shortLabel}支出',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          money(data.totals.expense),
                          key: const ValueKey('overview-expense'),
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              context,
                              '收入',
                              data.totals.income,
                              ink.income,
                            ),
                          ),
                          Container(width: 1, height: 38, color: ink.border),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _metric(
                              context,
                              '结余',
                              data.totals.balance,
                              ink.ink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_window.period == Period.month) ...[
                  Panel(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => BudgetScreen(
                          controller: widget.controller,
                          date: _window.date,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '月度预算',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 18,
                              color: ink.muted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (totalBudget != null)
                          BudgetMeter(status: totalBudget)
                        else
                          Text(
                            '设置预算，让花费更有分寸',
                            style: TextStyle(color: ink.muted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_window.period != Period.day) ...[
                  Panel(
                    child: Column(
                      children: [
                        SectionTitle(
                          _window.period == Period.year ? '年度收支' : '支出趋势',
                          trailing: Text(
                            _window.label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        SpendingTrend(
                          points: data.trend,
                          yearly: _window.period == Period.year,
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
                            final period = _window.period == Period.year
                                ? Period.month
                                : Period.day;
                            final win = PeriodWindow(period, date);
                            widget.openLedger(
                              EntryFilter(
                                start: win.start,
                                end: win.end,
                                kind: _window.period == Period.year
                                    ? null
                                    : EntryKind.expense,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Panel(
                  child: Column(
                    children: [
                      SectionTitle(
                        '最近账单',
                        onTap: () => widget.openLedger(
                          EntryFilter(start: _window.start, end: _window.end),
                        ),
                      ),
                      if (data.recent.isEmpty)
                        EmptyView(
                          action: TextButton(
                            onPressed: () => showEntryEditor(
                              context,
                              widget.controller,
                              date: _window.period == Period.day
                                  ? _window.date
                                  : null,
                            ),
                            child: const Text('记下第一笔'),
                          ),
                        )
                      else
                        ...data.recent.map(
                          (entry) => EntryTile(
                            entry: entry,
                            controller: widget.controller,
                            onTap: () => showEntryEditor(
                              context,
                              widget.controller,
                              entry: entry,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _metric(BuildContext context, String label, int value, Color color) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              money(value),
              style: TextStyle(
                color: color,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}
