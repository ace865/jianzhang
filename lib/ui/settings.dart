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
      final saved = await controller.backup();
      if (saved && context.mounted) message(context, '完整备份已保存');
    } catch (error) {
      if (context.mounted) message(context, errorText(error));
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final backup = await controller.pickBackup();
      if (backup == null || !context.mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('恢复这份备份？'),
          content: Text(
            '文件包含 ${(backup['entries'] as List).length} 笔账单。\n\n恢复会替换当前账本中的全部账单、分类、预算、小记和设置，不会合并。建议先保存现有账本的备份。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'backup'),
              child: const Text('先备份现有账本'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'restore'),
              child: const Text('替换并恢复'),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'cancel' || !context.mounted) return;
      if (choice == 'backup') {
        final saved = await controller.backup();
        if (!saved || !context.mounted) return;
        final proceed = await confirm(
          context,
          title: '现有账本已备份',
          body: '现在用选中的备份替换当前账本？',
          action: '替换并恢复',
        );
        if (!proceed || !context.mounted) return;
      }
      await controller.restore(backup);
      if (context.mounted) message(context, '账本已恢复');
    } catch (error) {
      if (context.mounted) message(context, errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = InkColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 104),
      children: [
        Text('设置', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('属于你的，安静的收支手账。', style: TextStyle(color: ink.muted)),
        const SizedBox(height: 24),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                secondary: Icon(
                  controller.dark ? LucideIcons.sun : LucideIcons.moon,
                  size: 23,
                ),
                title: const Text('深色主题'),
                subtitle: Text(controller.dark ? 'C · 深色暖灰' : 'A · 暖白陶土'),
                value: controller.dark,
                onChanged: controller.busy
                    ? null
                    : (_) async {
                        try {
                          await controller.toggleTheme();
                        } catch (error) {
                          if (context.mounted) {
                            message(context, errorText(error));
                          }
                        }
                      },
              ),
              const Divider(indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(LucideIcons.zap, size: 23),
                title: const Text('流畅优先'),
                subtitle: const Text('减少页面和图表动画'),
                value: controller.reducedMotion,
                onChanged: controller.busy
                    ? null
                    : (value) async {
                        try {
                          await controller.setReducedMotion(value);
                        } catch (error) {
                          if (context.mounted) {
                            message(context, errorText(error));
                          }
                        }
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _row(
                context,
                LucideIcons.shapes,
                '分类管理',
                '自定义分类名称、图标和启用状态',
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CategoryScreen(controller: controller),
                  ),
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              _row(
                context,
                LucideIcons.chartNoAxesCombined,
                '月度预算',
                '设置总预算和分类预算',
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
              const Divider(indent: 16, endIndent: 16),
              _row(
                context,
                LucideIcons.messageSquare,
                'AI 服务',
                '可选联网分析 · 配置接口与管理本地聊天',
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
        const SizedBox(height: 16),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _row(
                context,
                LucideIcons.download,
                '导入微信账单',
                'CSV / .xlsx · 预览、去重与分类确认',
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
              const Divider(indent: 16, endIndent: 16),
              _row(
                context,
                LucideIcons.download,
                '完整备份',
                '包含全部账单、预算、小记及设置',
                controller.busy ? null : () => _backup(context),
              ),
              const Divider(indent: 16, endIndent: 16),
              _row(
                context,
                LucideIcons.upload,
                '恢复备份',
                '使用简账 JSON 备份文件替换账本',
                controller.busy ? null : () => _restore(context),
              ),
              const Divider(indent: 16, endIndent: 16),
              _row(
                context,
                LucideIcons.fileSpreadsheet,
                '导出全部账单',
                'CSV 文件；筛选导出请前往账单页',
                controller.busy
                    ? null
                    : () async {
                        try {
                          final saved = await controller.exportCsv(
                            const EntryFilter(),
                          );
                          if (saved && context.mounted) {
                            message(context, '全部账单已导出');
                          }
                        } catch (error) {
                          if (context.mounted) {
                            message(context, errorText(error));
                          }
                        }
                      },
              ),
            ],
          ),
        ),
        if (controller.busy)
          const Padding(
            padding: EdgeInsets.all(18),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 22),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('数据与隐私'),
              const SizedBox(height: 10),
              Text(
                '账本保存在这台设备上，无需账号，离线可用。只有你主动使用 AI 时，统计汇总和必要聊天上下文才发送到你配置的服务地址；不上传单笔账单、备注或小记。\n\n请定期保存账本备份。卸载应用或清除数据会删除本机账本及 AI 历史；AI 记录和密钥不包含在账本备份中。CSV 文件不用于恢复。账本备份未加密，请保存在信任的位置。',
                style: TextStyle(fontSize: 13, color: ink.muted, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '简账 ${const String.fromEnvironment('FLUTTER_BUILD_NAME', defaultValue: '1.2.0-beta.2')} · 个人离线账本',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: '简账',
            applicationVersion: const String.fromEnvironment(
              'FLUTTER_BUILD_NAME',
              defaultValue: '1.2.0-beta.2',
            ),
          ),
          child: const Text('开源许可'),
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    leading: Icon(icon, size: 24, color: InkColors.of(context).ink),
    title: Text(title),
    subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    trailing: const Icon(LucideIcons.chevronRight, size: 18),
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
        ? '月度总预算'
        : '${widget.controller.category(id).name}预算';
    final amount = await _amountDialog(context, title, status?.limit);
    if (amount == null || !mounted) return;
    try {
      await widget.controller.setBudget(_month, id, amount < 0 ? null : amount);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) message(context, errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('月度预算')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '上个月',
              onPressed: _month.year <= 1900
                  ? null
                  : () => setState(() {
                      _month = DateTime(_month.year, _month.month - 1);
                      _reload();
                    }),
              icon: const Icon(LucideIcons.chevronLeft, size: 20),
            ),
            Expanded(
              child: Text(
                '${_month.year}年${_month.month}月',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: '下个月',
              onPressed: _month.year >= 2100
                  ? null
                  : () => setState(() {
                      _month = DateTime(_month.year, _month.month + 1);
                      _reload();
                    }),
              icon: const Icon(LucideIcons.chevronRight, size: 20),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () async {
            if (!await confirm(
              context,
              title: '复制上月预算？',
              body: '只补充本月尚未设置的预算，不覆盖已有额度。',
              action: '复制',
            )) {
              return;
            }
            try {
              final count = await widget.controller.copyBudgets(_month);
              if (context.mounted) {
                setState(_reload);
                message(
                  context,
                  count == 0 ? '上月没有可复制的预算，或本月已全部设置' : '已复制 $count 项预算',
                );
              }
            } catch (error) {
              if (context.mounted) message(context, errorText(error));
            }
          },
          icon: const Icon(LucideIcons.copy, size: 16),
          label: const Text('复制上月预算'),
        ),
        const SizedBox(height: 10),
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
                _budget(context, '', '总支出预算', mapped['']),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '分类预算',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                ...categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _budget(
                      context,
                      category.id,
                      category.name,
                      mapped[category.id],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          '总预算和分类预算分别统计，分类额度之和不必等于总预算。',
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
              const SizedBox(width: 12),
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
        const SizedBox(height: 14),
        if (status == null)
          Text(
            '未设置 · 点击添加',
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
  String? error;
  final result = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: text,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            prefixText: '¥ ',
            hintText: '请输入预算金额',
            errorText: error,
          ),
        ),
        actions: [
          if (cents != null)
            TextButton(
              onPressed: () => Navigator.pop(context, -1),
              child: const Text('移除预算'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = parseMoney(text.text);
              if (value == null) {
                setState(() => error = '请输入有效金额，最多两位小数');
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  // The dialog route may still be animating while its text field is mounted.
  await Future<void>.delayed(const Duration(milliseconds: 300));
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
      if (mounted) message(context, errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('分类管理'),
      actions: [
        IconButton(
          tooltip: '添加分类',
          onPressed: () => _edit(),
          icon: const Icon(LucideIcons.plus),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      children: [
        KindSwitch(
          value: _kind,
          onChanged: (kind) => setState(() => _kind = kind),
        ),
        const SizedBox(height: 16),
        ...widget.controller.categories
            .where((c) => c.kind == _kind)
            .map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      Icon(categoryGlyph(category.icon), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _edit(category),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(category.name),
                                Text(
                                  category.active
                                      ? '点击修改名称或图标'
                                      : '已停用 · 历史记录保留',
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
                              message(context, errorText(error));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(LucideIcons.plus, size: 18),
          label: Text('添加${_kind == EntryKind.expense ? '支出' : '收入'}分类'),
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
  String? _error;
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
    title: Text(widget.category == null ? '添加分类' : '编辑分类'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            maxLength: 20,
            decoration: InputDecoration(labelText: '分类名称', errorText: _error),
          ),
          const SizedBox(height: 12),
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
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (_name.text.trim().isEmpty) {
            setState(() => _error = '请输入分类名称');
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
        child: const Text('保存'),
      ),
    ],
  );
}
