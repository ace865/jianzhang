import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';
import 'common.dart';
import 'theme.dart';

class SpendingTrend extends StatelessWidget {
  const SpendingTrend({
    super.key,
    required this.points,
    this.yearly = false,
    this.income = false,
    this.reducedMotion = false,
    this.onPoint,
  });
  final List<TrendPoint> points;
  final bool yearly, income, reducedMotion;
  final ValueChanged<int>? onPoint;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty ||
        points.every((p) => p.expense == 0 && p.income == 0)) {
      return const EmptyView(title: '趋势会出现在这里', subtitle: '记录收支后，即可看到花费的变化。');
    }
    final ink = InkColors.of(context);
    final maxValue =
        points.fold<int>(
          0,
          (v, p) => math.max(
            v,
            yearly
                ? math.max(p.expense, p.income)
                : income
                ? p.income
                : p.expense,
          ),
        ) /
        100;
    final maxY = math.max(1.0, maxValue * 1.2);
    final bottomTitles = AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: points.length <= 7
            ? 1
            : points.length <= 12
            ? 2
            : 5,
        getTitlesWidget: (value, meta) {
          final i = value.round();
          if (i < 0 || i >= points.length) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              points[i].label,
              style: TextStyle(fontSize: 10, color: ink.muted),
            ),
          );
        },
      ),
    );
    final titles = FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: bottomTitles,
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 42,
          interval: maxY / 3,
          getTitlesWidget: (value, meta) => Text(
            value >= 10000
                ? '${(value / 10000).toStringAsFixed(1)}万'
                : value.toStringAsFixed(0),
            style: TextStyle(fontSize: 10, color: ink.muted),
          ),
        ),
      ),
    );
    final grid = FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: maxY / 3,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: ink.border, strokeWidth: 0.7),
    );
    final duration = Duration(milliseconds: reducedMotion ? 0 : 240);
    return Semantics(
      label: yearly ? '每月收入与支出对比图' : '${income ? '收入' : '支出'}趋势图',
      child: SizedBox(
        height: 140,
        child: Padding(
          padding: const EdgeInsets.only(top: 18, right: 10),
          child: yearly
              ? BarChart(
                  BarChartData(
                    maxY: maxY,
                    minY: 0,
                    gridData: grid,
                    borderData: FlBorderData(show: false),
                    titlesData: titles,
                    alignment: BarChartAlignment.spaceAround,
                    barGroups: List.generate(
                      points.length,
                      (i) => BarChartGroupData(
                        x: i,
                        barsSpace: 2,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].income / 100,
                            color: ink.income,
                            width: 6,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                          ),
                          BarChartRodData(
                            toY: points[i].expense / 100,
                            color: ink.accent,
                            width: 6,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchCallback: (event, response) {
                        if (event is FlTapUpEvent && response?.spot != null) {
                          onPoint?.call(response!.spot!.touchedBarGroupIndex);
                        }
                      },
                    ),
                  ),
                  duration: duration,
                )
              : LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: math.max(1, points.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxY,
                    titlesData: titles,
                    gridData: grid,
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          points.length,
                          (i) => FlSpot(
                            i.toDouble(),
                            (income ? points[i].income : points[i].expense) /
                                100,
                          ),
                        ),
                        isCurved: false,
                        color: income ? ink.income : ink.accent,
                        barWidth: 2.5,
                        dotData: FlDotData(show: points.length <= 12),
                        belowBarData: BarAreaData(
                          show: true,
                          color: (income ? ink.income : ink.accent).withValues(
                            alpha: 0.07,
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchCallback: (event, response) {
                        if (event is FlTapUpEvent &&
                            response?.lineBarSpots?.isNotEmpty == true) {
                          onPoint?.call(
                            response!.lineBarSpots!.first.spotIndex,
                          );
                        }
                      },
                    ),
                  ),
                  duration: duration,
                ),
        ),
      ),
    );
  }
}

class CategoryRing extends StatelessWidget {
  const CategoryRing({
    super.key,
    required this.items,
    required this.income,
    this.reducedMotion = false,
    this.onCategory,
  });
  final List<CategoryTotal> items;
  final bool income, reducedMotion;
  final ValueChanged<String>? onCategory;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyView(title: '还没有分类数据', subtitle: '记录一笔收支，看看钱花在哪里。');
    }
    final ink = InkColors.of(context),
        total = items.fold<int>(0, (sum, c) => sum + c.cents);
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              centerSpaceRadius: 68,
              sectionsSpace: 2,
              sections: List.generate(
                items.length,
                (i) => PieChartSectionData(
                  value: items[i].cents.toDouble(),
                  color: ink.chart[i % ink.chart.length],
                  radius: 28,
                  showTitle: false,
                ),
              ),
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) return;
                  final index = response?.touchedSection?.touchedSectionIndex;
                  if (index != null && index >= 0 && index < items.length) {
                    onCategory?.call(items[index].categoryId);
                  }
                },
              ),
            ),
            duration: Duration(milliseconds: reducedMotion ? 0 : 240),
          ),
          IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  income ? '总收入' : '总支出',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 125,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      money(total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
