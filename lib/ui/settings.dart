import '../l10n/localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/controller.dart';
import '../core/models.dart';
import 'common.dart';
import 'ai.dart';
import 'theme.dart';
import 'wechat_import.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final LedgerController controller;
  Future<void> _backup(BuildContext context) async {
    try {
      final saved = await controller.backup(
        dialogTitle: tr(context).fullBackup,
      );
      if (saved && context.mounted) {
        message(context, tr(context).fullBackupSaved);
      }
    } catch (error) {
      if (context.mounted) message(context, errorText(context, error));
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final backup = await controller.pickBackup();
      if (backup == null || !context.mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr(context).restoreThisBackup),
          content: Text(
            tr(context).thisFileContainsPEntriesRestoringReplaces(
              ((backup['entries'] as List).length).toString(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: Text(tr(context).cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'backup'),
              child: Text(tr(context).backUpCurrentLedgerFirst),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'restore'),
              child: Text(tr(context).replaceAndRestore),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'cancel' || !context.mounted) return;
      if (choice == 'backup') {
        final saved = await controller.backup(
          dialogTitle: tr(context).fullBackup,
        );
        if (!saved || !context.mounted) return;
        final proceed = await confirm(
          context,
          title: tr(context).currentLedgerBackedUp,
          body: tr(context).replaceTheCurrentLedgerWithTheSelected,
          action: tr(context).replaceAndRestore,
        );
        if (!proceed || !context.mounted) return;
      }
      await controller.restore(backup);
      if (context.mounted) message(context, tr(context).ledgerRestored);
    } catch (error) {
      if (context.mounted) message(context, errorText(context, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = InkColors.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 104),
      children: [
        Text(
          tr(context).settings,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: 8),
        Text(
          tr(context).yourQuietPersonalIncomeAndExpenseJournal,
          style: TextStyle(color: ink.muted),
        ),
        SizedBox(height: 24),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(LucideIcons.languages, size: 23),
                title: Text(tr(context).language),
                subtitle: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const ValueKey('language-selector'),
                    icon: const Icon(LucideIcons.chevronDown, size: 20),
                    isExpanded: true,
                    value: LanguageSettings.instance.choice,
                    items: LanguageSettings.choices
                        .map(
                          (choice) => DropdownMenuItem(
                            value: choice,
                            child: Text(switch (choice) {
                              'en' => 'English',
                              'zh-Hans' => '简体中文',
                              'zh-Hant' => '繁體中文',
                              'ja' => '日本語',
                              _ => tr(context).followSystem,
                            }),
                          ),
                        )
                        .toList(),
                    onChanged: controller.busy
                        ? null
                        : (value) async {
                            if (value == null) return;
                            try {
                              await LanguageSettings.instance.select(value);
                            } catch (_) {
                              if (context.mounted) {
                                message(
                                  context,
                                  tr(context).languageSaveFailed,
                                );
                              }
                            }
                          },
                  ),
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: Icon(
                  controller.dark ? LucideIcons.sun : LucideIcons.moon,
                  size: 23,
                ),
                title: Text(tr(context).darkTheme),
                subtitle: Text(
                  controller.dark
                      ? tr(context).cWarmDarkGray
                      : tr(context).aWarmWhiteAndTerracotta,
                ),
                value: controller.dark,
                onChanged: controller.busy
                    ? null
                    : (_) async {
                        try {
                          await controller.toggleTheme();
                        } catch (error) {
                          if (context.mounted) {
                            message(context, errorText(context, error));
                          }
                        }
                      },
              ),
              Divider(indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: Icon(LucideIcons.zap, size: 23),
                title: Text(tr(context).reduceMotion),
                subtitle: Text(tr(context).reducePageAndChartAnimations),
                value: controller.reducedMotion,
                onChanged: controller.busy
                    ? null
                    : (value) async {
                        try {
                          await controller.setReducedMotion(value);
                        } catch (error) {
                          if (context.mounted) {
                            message(context, errorText(context, error));
                          }
                        }
                      },
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _row(
                context,
                LucideIcons.shapes,
                tr(context).categories,
                tr(context).customizeNamesIconsAndEnabledStatus,
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CategoryScreen(controller: controller),
                  ),
                ),
              ),
              Divider(indent: 16, endIndent: 16),
              _row(
                context,
                LucideIcons.chartNoAxesCombined,
                tr(context).monthlyBudget,
                tr(context).setOverallAndCategoryBudgets,
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => BudgetScreen(
                      controller: controller,
                      date: DateTime.now(),
                    ),
                  ),
                ),
              ),
              Divider(indent: 16, endIndent: 16),
              _row(
                context,
                LucideIcons.messageSquare,
                tr(context).aiService,
                tr(context).optionalOnlineAnalysisConfigureServiceAndLocal,
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AiSettingsScreen(service: controller.ai),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _row(
                context,
                LucideIcons.download,
                tr(context).importWechatStatements,
                tr(context).csvXlsxPreviewDeduplicationAndCategoryReview,
                controller.busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              WechatImportScreen(controller: controller),
                        ),
                      ),
              ),
              Divider(indent: 16, endIndent: 16),
              _row(
                context,
                LucideIcons.download,
                tr(context).fullBackup,
                tr(context).includesAllEntriesBudgetsDailyNotesAnd,
                controller.busy ? null : () => _backup(context),
              ),
              Divider(indent: 16, endIndent: 16),
              _row(
                context,
                LucideIcons.upload,
                tr(context).restoreBackup,
                tr(context).replaceTheLedgerUsingAJsonBackup,
                controller.busy ? null : () => _restore(context),
              ),
              Divider(indent: 16, endIndent: 16),
              _row(
                context,
                LucideIcons.fileSpreadsheet,
                tr(context).exportAllEntries,
                tr(context).csvFileExportFilteredEntriesFromThe,
                controller.busy
                    ? null
                    : () async {
                        try {
                          final saved = await controller.exportCsv(
                            EntryFilter(),
                            dialogTitle: tr(context).exportAllEntries,
                          );
                          if (saved && context.mounted) {
                            message(context, tr(context).allEntriesExported);
                          }
                        } catch (error) {
                          if (context.mounted) {
                            message(context, errorText(context, error));
                          }
                        }
                      },
              ),
            ],
          ),
        ),
        if (controller.busy)
          Padding(
            padding: EdgeInsets.all(18),
            child: LinearProgressIndicator(),
          ),
        SizedBox(height: 22),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(tr(context).dataAndPrivacy),
              SizedBox(height: 10),
              Text(
                tr(context).yourLedgerStaysOnThisDeviceWorks,
                style: TextStyle(fontSize: 13, color: ink.muted, height: 1.7),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        Text(
          tr(context).pPersonalOfflineLedger(
            (String.fromEnvironment(
              'FLUTTER_BUILD_NAME',
              defaultValue: '1.2.0-beta.2',
            )).toString(),
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: tr(context).message,
            applicationVersion: String.fromEnvironment(
              'FLUTTER_BUILD_NAME',
              defaultValue: '1.2.0-beta.2',
            ),
          ),
          child: Text(tr(context).openSourceLicenses),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? tap,
  ) => ListTile(
    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    leading: Icon(icon, size: 24, color: InkColors.of(context).ink),
    title: Text(title),
    subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    trailing: Icon(LucideIcons.chevronRight, size: 18),
    onTap: tap,
    enabled: tap != null,
  );
}

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key, required this.controller, required this.date});
  final LedgerController controller;
  final DateTime date;
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late DateTime _month;
  late Future<List<BudgetStatus>> _future;
  @override
  void initState() {
    super.initState();
    _month = widget.date;
    _reload();
  }

  void _reload() {
    _future = widget.controller.store.budgets(_month);
  }

  Future<void> _edit(String id, BudgetStatus? status) async {
    final title = id.isEmpty
        ? tr(context).monthlyOverallBudget
        : tr(context).pBudget(
            (categoryLabel(context, widget.controller.category(id))).toString(),
          );
    final amount = await _amountDialog(context, title, status?.limit);
    if (amount == null || !mounted) return;
    try {
      await widget.controller.setBudget(_month, id, amount < 0 ? null : amount);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) message(context, errorText(context, error));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context).monthlyBudget)),
    body: ListView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 30),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: tr(context).previousMonth,
              onPressed: _month.year <= 1900
                  ? null
                  : () => setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                      _reload();
                    }),
              icon: Icon(LucideIcons.chevronLeft, size: 20),
            ),
            Expanded(
              child: Text(
                tr(context)
                    .pP((_month.year).toString(), (_month.month).toString()),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: tr(context).nextMonth,
              onPressed: _month.year >= 2100
                  ? null
                  : () => setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                      _reload();
                    }),
              icon: Icon(LucideIcons.chevronRight, size: 20),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () async {
            if (!await confirm(
              context,
              title: tr(context).copyLastMonthSBudgets,
              body: tr(context).onlyAddsBudgetsNotYetSetThis,
              action: tr(context).copy,
            )) {
              return;
            }
            try {
              final count = await widget.controller.copyBudgets(_month);
              if (context.mounted) {
                setState(_reload);
                message(
                  context,
                  count == 0
                      ? tr(context).noBudgetsToCopyOrAllBudgets
                      : tr(context).copiedPBudgets((count).toString()),
                );
              }
            } catch (error) {
              if (context.mounted) message(context, errorText(context, error));
            }
          },
          icon: Icon(LucideIcons.copy, size: 16),
          label: Text(tr(context).copyLastMonthSBudgets269),
        ),
        SizedBox(height: 10),
        AsyncContent(
          future: _future,
          retry: () => setState(_reload),
          builder: (statuses) {
            final mapped = {for (final b in statuses) b.categoryId: b};
            final categories = widget.controller.categories.where(
              (c) =>
                  c.kind == EntryKind.expense &&
                  (c.active || mapped.containsKey(c.id)),
            );
            return Column(
              children: [
                _budget(
                  context,
                  '',
                  tr(context).overallExpenseBudget,
                  mapped[''],
                ),
                SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr(context).categoryBudgets,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(height: 12),
                ...categories.map(
                  (category) => Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _budget(
                      context,
                      category.id,
                      categoryLabel(context, category),
                      mapped[category.id],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: 10),
        Text(
          tr(context).overallAndCategoryBudgetsAreTrackedSeparately,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
  Widget _budget(
    BuildContext context,
    String id,
    String title,
    BudgetStatus? status,
  ) => Panel(
    onTap: () => _edit(id, status),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (id.isNotEmpty) ...[
              Icon(
                categoryGlyph(widget.controller.category(id).icon),
                size: 22,
              ),
              SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Icon(
              LucideIcons.pencil,
              size: 17,
              color: InkColors.of(context).muted,
            ),
          ],
        ),
        SizedBox(height: 14),
        if (status == null)
          Text(
            tr(context).notSetTapToAdd,
            style: TextStyle(color: InkColors.of(context).muted),
          )
        else
          BudgetMeter(status: status),
      ],
    ),
  );
}

Future<int?> _amountDialog(
  BuildContext context,
  String title,
  int? cents,
) async {
  final text = TextEditingController(
    text: cents == null ? '' : moneyInput(cents),
  );
  bool invalidAmount = false;
  final result = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: text,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            prefixText: '¥ ',
            hintText: tr(context).enterBudgetAmount,
            errorText: invalidAmount
                ? tr(context).enterAValidAmountWithUpTo
                : null,
          ),
        ),
        actions: [
          if (cents != null)
            TextButton(
              onPressed: () => Navigator.pop(context, -1),
              child: Text(tr(context).removeBudget),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context).cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = parseMoney(text.text);
              if (value == null) {
                setState(() => invalidAmount = true);
                return;
              }
              Navigator.pop(context, value);
            },
            child: Text(tr(context).save),
          ),
        ],
      ),
    ),
  );
  // The dialog route may still be animating while its text field is mounted.
  await Future<void>.delayed(Duration(milliseconds: 300));
  text.dispose();
  return result;
}

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  EntryKind _kind = EntryKind.expense;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _edit([Category? category]) async {
    final result = await showDialog<Category>(
      context: context,
      builder: (_) => CategoryDialog(
        category: category,
        kind: _kind,
        order: widget.controller.categories.length,
      ),
    );
    if (result == null) return;
    try {
      await widget.controller.saveCategory(result);
    } catch (error) {
      if (mounted) message(context, errorText(context, error));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr(context).categories),
      actions: [
        IconButton(
          tooltip: tr(context).addCategory,
          onPressed: () => _edit(),
          icon: Icon(LucideIcons.plus),
        ),
      ],
    ),
    body: ListView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 30),
      children: [
        KindSwitch(
          value: _kind,
          onChanged: (kind) => setState(() => _kind = kind),
        ),
        SizedBox(height: 16),
        ...widget.controller.categories
            .where((c) => c.kind == _kind)
            .map(
              (category) => Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Panel(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  child: Row(
                    children: [
                      Icon(categoryGlyph(category.icon), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _edit(category),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(categoryLabel(context, category)),
                                Text(
                                  category.active
                                      ? tr(context).tapToChangeNameOrIcon
                                      : tr(context).disabledHistoryPreserved,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Switch(
                        value: category.active,
                        onChanged: (value) async {
                          try {
                            await widget.controller.saveCategory(
                              category.copyWith(active: value),
                            );
                          } catch (error) {
                            if (context.mounted) {
                              message(context, errorText(context, error));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _edit(),
          icon: Icon(LucideIcons.plus, size: 18),
          label: Text(
            tr(context).addPCategory(
              (_kind == EntryKind.expense
                      ? tr(context).expenses
                      : tr(context).income)
                  .toString(),
            ),
          ),
        ),
      ],
    ),
  );
}

class CategoryDialog extends StatefulWidget {
  const CategoryDialog({
    super.key,
    this.category,
    required this.kind,
    required this.order,
  });
  final Category? category;
  final EntryKind kind;
  final int order;
  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  late TextEditingController _name;
  late String _icon;
  bool _invalidName = false;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name);
    _icon = widget.category?.icon ?? 'more';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.category == null
          ? tr(context).addCategory
          : tr(context).editCategory,
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: tr(context).categoryName,
              errorText: _invalidName ? tr(context).enterACategoryName : null,
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: iconKeys
                .map(
                  (icon) => IconButton(
                    tooltip: icon,
                    onPressed: () => setState(() => _icon = icon),
                    style: IconButton.styleFrom(
                      side: BorderSide(
                        color: _icon == icon
                            ? InkColors.of(context).accent
                            : Colors.transparent,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(
                      categoryGlyph(icon),
                      size: 24,
                      color: InkColors.of(context).ink,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context).cancel),
      ),
      FilledButton(
        onPressed: () {
          if (_name.text.trim().isEmpty) {
            setState(() => _invalidName = true);
            return;
          }
          Navigator.pop(
            context,
            widget.category?.copyWith(name: _name.text.trim(), icon: _icon) ??
                Category(
                  id: newId(),
                  name: _name.text.trim(),
                  icon: _icon,
                  kind: widget.kind,
                  order: widget.order,
                ),
          );
        },
        child: Text(tr(context).save),
      ),
    ],
  );
}
