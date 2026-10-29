import '../l10n/localization.dart';
import '../l10n/system_messages.dart';
import '../core/ai_client.dart';
import '../core/failures.dart';
export '../core/failures.dart' show LocalizedFailure;

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

String errorText(BuildContext context, Object error) =>
    (error is LocalizedFailure
        ? localizedFailure(context, error.code)
        : error is FormatException
        ? systemMessage(context, error.message.toString())
        : error is AiFailure
        ? systemMessage(context, error.message)
        : null) ??
    tr(context).operationFailedPleaseRetryYourExistingData;

String? localizedFailure(BuildContext context, String code) => switch (code) {
  'youHaveUnsavedChangesSaveTheConfiguration' => tr(
    context,
  ).youHaveUnsavedChangesSaveTheConfiguration,
  'saveTheConfigurationFirst' => tr(context).saveTheConfigurationFirst,
  'youHaveUnsavedChangesSaveBeforeRefreshing' => tr(
    context,
  ).youHaveUnsavedChangesSaveBeforeRefreshing,
  'saveTheKeyForThisAddressFirst' => tr(context).saveTheKeyForThisAddressFirst,
  'modelRefreshCancelledThePreviousListIs' => tr(
    context,
  ).modelRefreshCancelledThePreviousListIs,
  'cannotCheckTheLatestLedgerPleaseRetry' => tr(
    context,
  ).cannotCheckTheLatestLedgerPleaseRetry,
  'importFailedYourOriginalLedgerIsUnchanged' => tr(
    context,
  ).importFailedYourOriginalLedgerIsUnchanged,
  _ => null,
};
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  String? action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action ?? tr(context).confirm),
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
          tooltip: tr(context).viewP((text).toString()),
          onPressed: onTap,
          icon: Icon(LucideIcons.chevronRight, size: 18),
        ),
    ],
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.title, this.subtitle, this.action});
  final String? title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 30, horizontal: 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LucideIcons.notebookPen,
          size: 32,
          color: InkColors.of(context).muted,
        ),
        SizedBox(height: 14),
        Text(
          title ?? tr(context).noEntriesYet,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 8),
        Text(
          subtitle ?? tr(context).startWithOneEntryAndKeepTrack,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (action != null) ...[SizedBox(height: 18), action!],
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
          title: tr(context).cannotReadDataRightNow,
          subtitle: tr(context).pleaseRetryYourLedgerFileWillNot,
          action: TextButton(onPressed: retry, child: Text(tr(context).retry)),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return Padding(
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
    labels: [tr(context).expenses, tr(context).income],
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
      padding: EdgeInsets.all(3),
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
                  constraints: BoxConstraints(minHeight: 36),
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
          tooltip: tr(context).previousPeriod,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 32, minHeight: 48),
          onPressed: window.start.year <= 1900
              ? null
              : () => onChanged(window.shift(-1)),
          icon: Icon(LucideIcons.chevronLeft, size: 18),
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
                helpText: tr(context).chooseP(
                  (window.period == Period.year
                          ? tr(context).year
                          : tr(context).date)
                      .toString(),
                ),
              );
              if (picked != null) {
                onChanged(PeriodWindow(window.period, picked));
              }
            },
            child: Text(
              periodLabel(context, window),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: InkColors.of(context).ink, fontSize: 14),
            ),
          ),
        ),
        IconButton(
          tooltip: tr(context).nextPeriod,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 32, minHeight: 48),
          onPressed: window.end.year > 2100
              ? null
              : () => onChanged(window.shift(1)),
          icon: Icon(LucideIcons.chevronRight, size: 18),
        ),
      ],
    );
    final periodPicker = ChoiceStrip(
      labels: [tr(context).day, tr(context).month, tr(context).year156],
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
              SizedBox(width: 8),
              SizedBox(width: 132, child: periodPicker),
            ],
          );
        }
        return Column(
          children: [datePicker, SizedBox(height: 4), periodPicker],
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
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(categoryGlyph(category.icon), size: 25, color: ink.ink),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.note.isEmpty
                        ? categoryLabel(context, category)
                        : entry.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${categoryLabel(context, category)} · ${paymentLabel(context, entry.payment)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
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
          '${over ? tr(context).overBudget : tr(context).remaining} ${money(status.remaining.abs())}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: over ? ink.danger : ink.ink,
            fontSize: 17,
          ),
        ),
        SizedBox(height: 12),
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
            SizedBox(width: 12),
            Text(
              '${(status.ratio * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        SizedBox(height: 9),
        Text(
          tr(context).usedPBudgetP(
            (money(status.spent)).toString(),
            (money(status.limit)).toString(),
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (status.ratio >= 0.8) ...[
          SizedBox(height: 9),
          Text(
            status.ratio >= 1
                ? tr(context).budgetReachedWatchUpcomingExpenses
                : tr(context).overOfBudgetUsed,
            style: TextStyle(fontSize: 12, color: ink.danger),
          ),
        ],
      ],
    );
  }
}
