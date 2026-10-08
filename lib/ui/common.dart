import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'theme.dart';

void message(BuildContext context, String text) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

String errorText(Object error) =>
    error is FormatException ? error.message : '操作未完成，请重试。原有数据仍保留。';
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  String action = '确认',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final ink = InkColors.of(context);
    return Material(
      color: ink.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ink.border, width: 0.7),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.onTap});
  final String text;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
      ?trailing,
      if (onTap != null)
        IconButton(
          tooltip: '查看$text',
          onPressed: onTap,
          icon: const Icon(LucideIcons.chevronRight, size: 18),
        ),
    ],
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.title = '还没有记录',
    this.subtitle = '记下第一笔，让每一笔花费都有迹可循。',
    this.action,
  });
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LucideIcons.notebookPen,
          size: 32,
          color: InkColors.of(context).muted,
        ),
        const SizedBox(height: 14),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.future,
    required this.builder,
    this.retry,
  });
  final Future<T> future;
  final Widget Function(T) builder;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return EmptyView(
          title: '暂时无法读取数据',
          subtitle: '请重试，账本文件不会被清空。',
          action: TextButton(onPressed: retry, child: const Text('重试')),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return builder(snapshot.data as T);
    },
  );
}

class KindSwitch extends StatelessWidget {
  const KindSwitch({super.key, required this.value, required this.onChanged});
  final EntryKind value;
  final ValueChanged<EntryKind> onChanged;
  @override
  Widget build(BuildContext context) => ChoiceStrip(
    labels: const ['支出', '收入'],
    index: value.index,
    onChanged: (i) => onChanged(EntryKind.values[i]),
  );
}

class ChoiceStrip extends StatelessWidget {
  const ChoiceStrip({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final ink = InkColors.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: ink.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: List.generate(
          labels.length,
          (i) => Expanded(
            child: Semantics(
              selected: index == i,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(i),
                child: Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(minHeight: 36),
                  decoration: BoxDecoration(
                    color: index == i ? ink.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: index == i ? ink.onAccent : ink.muted,
                      fontWeight: index == i
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WindowPicker extends StatelessWidget {
  const WindowPicker({
    super.key,
    required this.window,
    required this.onChanged,
  });
  final PeriodWindow window;
  final ValueChanged<PeriodWindow> onChanged;
  @override
  Widget build(BuildContext context) {
    final datePicker = Row(
      children: [
        IconButton(
          tooltip: '上一期',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 48),
          onPressed: window.start.year <= 1900
              ? null
              : () => onChanged(window.shift(-1)),
          icon: const Icon(LucideIcons.chevronLeft, size: 18),
        ),
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: window.date,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100, 12, 31),
                helpText: '选择${window.period == Period.year ? '年份' : '日期'}',
              );
              if (picked != null) {
                onChanged(PeriodWindow(window.period, picked));
              }
            },
            child: Text(
              window.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: InkColors.of(context).ink, fontSize: 14),
            ),
          ),
        ),
        IconButton(
          tooltip: '下一期',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 48),
          onPressed: window.end.year > 2100
              ? null
              : () => onChanged(window.shift(1)),
          icon: const Icon(LucideIcons.chevronRight, size: 18),
        ),
      ],
    );
    final periodPicker = ChoiceStrip(
      labels: const ['日', '月', '年'],
      index: window.period.index,
      onChanged: (i) => onChanged(PeriodWindow(Period.values[i], window.date)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 340 &&
            MediaQuery.textScalerOf(context).scale(14) <= 16) {
          return Row(
            children: [
              Expanded(child: datePicker),
              const SizedBox(width: 8),
              SizedBox(width: 132, child: periodPicker),
            ],
          );
        }
        return Column(
          children: [datePicker, const SizedBox(height: 4), periodPicker],
        );
      },
    );
  }
}

class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.controller,
    required this.onTap,
  });
  final LedgerEntry entry;
  final LedgerController controller;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final category = controller.category(entry.categoryId);
    final ink = InkColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(categoryGlyph(category.icon), size: 25, color: ink.ink),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.note.isEmpty ? category.name : entry.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${category.name} · ${entry.payment}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.kind == EntryKind.income ? '+' : '−'}${money(entry.cents)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: entry.kind == EntryKind.income ? ink.income : ink.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetMeter extends StatelessWidget {
  const BudgetMeter({super.key, required this.status});
  final BudgetStatus status;
  @override
  Widget build(BuildContext context) {
    final ink = InkColors.of(context);
    final over = status.remaining < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${over ? '已超支' : '剩余'} ${money(status.remaining.abs())}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: over ? ink.danger : ink.ink,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: status.ratio.clamp(0, 1),
                  minHeight: 7,
                  backgroundColor: ink.border,
                  color: over ? ink.danger : ink.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(status.ratio * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          '已用 ${money(status.spent)} · 预算 ${money(status.limit)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (status.ratio >= 0.8) ...[
          const SizedBox(height: 9),
          Text(
            status.ratio >= 1 ? '已达到预算，请留意后续支出' : '预算已使用 80% 以上',
            style: TextStyle(fontSize: 12, color: ink.danger),
          ),
        ],
      ],
    );
  }
}
