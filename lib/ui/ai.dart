import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/ai_client.dart';
import '../core/ai_models.dart';
import '../core/ai_service.dart';
import '../core/ai_snapshot.dart';
import '../core/controller.dart';
import '../core/models.dart';
import 'common.dart';
import 'theme.dart';
import 'ai_settings.dart';
export 'ai_settings.dart' show AiSettingsScreen;

String _aiError(Object error) => error is AiFailure
    ? error.message
    : error is FormatException
    ? error.message
    : 'AI 操作未完成。账本不受影响，请检查设备存储或重试。';

class AiAnalysisScreen extends StatefulWidget {
  const AiAnalysisScreen({
    super.key,
    required this.controller,
    required this.window,
    required this.focus,
  });
  final LedgerController controller;
  final PeriodWindow window;
  final EntryKind focus;
  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  AiService get _service => widget.controller.ai;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  AiSnapshot? _snapshot;
  AiConversation? _conversation;
  String? _error;
  bool _loading = true, _preparing = false, _stale = false;
  int _revision = -1, _refreshGeneration = 0;
  @override
  void initState() {
    super.initState();
    _service.addListener(_changed);
    widget.controller.addListener(_ledgerChanged);
    _load();
  }

  void _changed() {
    if (!mounted) return;
    final follow =
        _service.busy &&
        _scroll.hasClients &&
        _scroll.position.extentAfter < 80;
    setState(() {});
    if (follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  void _ledgerChanged() {
    if (_revision != widget.controller.revision) _checkData();
  }

  Future<void> _load() async {
    try {
      await _service.initialize();
      _snapshot = await readAiSnapshot(
        widget.controller.store,
        widget.window,
        widget.focus,
      );
      _conversation = _service.cached(_snapshot!);
      _revision = widget.controller.revision;
    } catch (error) {
      _error = _aiError(error);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkData() async {
    final generation = ++_refreshGeneration;
    final old = _conversation?.snapshot ?? _snapshot;
    if (old == null) return;
    try {
      final fresh = await readAiSnapshot(
        widget.controller.store,
        old.window,
        old.focus,
      );
      if (!mounted || generation != _refreshGeneration) return;
      setState(() {
        _revision = widget.controller.revision;
        _stale = old.digest != fresh.digest;
        if (_conversation == null) _snapshot = fresh;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '无法核对最新账本，请重试。');
    }
  }

  @override
  void dispose() {
    _refreshGeneration++;
    _service.removeListener(_changed);
    widget.controller.removeListener(_ledgerChanged);
    if (_service.busy) _service.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _settings() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AiSettingsScreen(service: _service),
      ),
    );
    if (!mounted) return;
    if (_conversation != null && !_service.history.contains(_conversation)) {
      _conversation = null;
    }
    await _checkData();
    setState(() {});
  }

  Future<bool> _preview(AiConversation conversation, String question) async {
    final selected = _service.config!;
    final body = aiRequest(selected, aiMessages(conversation, question));
    final first = !await _service.storage.consented(selected);
    if (!mounted) return false;
    final result =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(first ? '确认接收地址与数据范围' : '确认本次发送'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '接收地址：${selected.endpoint}\n模型：${selected.model}\n\n仅含统计汇总、分类名称和本对话必要上下文，不含账单明细。可能产生 API 费用，删除本地记录不删除服务商副本。',
                    ),
                    const SizedBox(height: 12),
                    const Text('追问只携带原报告和最近六轮完整问答，较早聊天保留本机但不再发送。'),
                    ExpansionTile(
                      trailing: const Icon(LucideIcons.chevronDown, size: 18),
                      tilePadding: EdgeInsets.zero,
                      title: const Text('查看实际发送内容'),
                      children: [
                        SelectableText(
                          body,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认并发送'),
              ),
            ],
          ),
        ) ??
        false;
    if (result) await _service.storage.consent(selected);
    return result;
  }

  Future<void> _send({bool regenerate = false}) async {
    if (_preparing || _service.busy) return;
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      if (_service.config == null) {
        await _settings();
        if (!mounted || _service.config == null) return;
      }
      AiConversation conversation;
      String question;
      if (regenerate ||
          _conversation == null ||
          !_conversation!.hasReport ||
          !_service.compatible(_conversation!)) {
        final old = _conversation?.snapshot;
        final snapshot = await readAiSnapshot(
          widget.controller.store,
          old?.window ?? widget.window,
          old?.focus ?? widget.focus,
        );
        if (!snapshot.available) {
          throw const FormatException('该期间没有已记录数据，或属于未来期间，未发送请求。');
        }
        if (!regenerate) {
          final cache = _service.cached(snapshot);
          if (cache != null) {
            setState(() {
              _conversation = cache;
              _stale = false;
            });
            return;
          }
        }
        conversation = AiConversation(
          snapshot: snapshot,
          config: _service.config!,
        );
        question = '请分析这份收支汇总：主要分类、与上期变化、月度预算（如有）及可执行建议。不要编造缺失数据。';
      } else {
        conversation = _conversation!;
        question = _input.text.trim();
      }
      if (!await _preview(conversation, question) || !mounted) return;
      setState(() {
        _conversation = conversation;
        _snapshot = conversation.snapshot;
      });
      _input.clear();
      await _service.send(conversation, question);
      await _checkData();
    } catch (error) {
      if (mounted) setState(() => _error = _aiError(error));
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _history() async {
    final selected = await Navigator.push<AiConversation>(
      context,
      MaterialPageRoute(builder: (_) => AiHistoryScreen(service: _service)),
    );
    if (!mounted) return;
    setState(() {
      if (selected != null) {
        _conversation = selected;
      } else if (_conversation != null &&
          !_service.history.contains(_conversation)) {
        _conversation = null;
      }
    });
    await _checkData();
  }

  @override
  Widget build(BuildContext context) {
    final ink = InkColors.of(context);
    final disabled = _loading || _preparing || _service.busy;
    final conversation = _conversation;
    final persistenceError = conversation == null
        ? null
        : _service.persistenceErrors[conversation.id];
    final snapshot = conversation?.snapshot ?? _snapshot;
    final compatible =
        conversation == null || _service.compatible(conversation);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 分析'),
        actions: [
          IconButton(
            tooltip: '历史',
            onPressed: disabled ? null : _history,
            icon: const Icon(LucideIcons.history),
          ),
          IconButton(
            tooltip: 'AI 服务',
            onPressed: disabled ? null : _settings,
            icon: const Icon(LucideIcons.settings2),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(_error!),
                    ),
                  if (snapshot != null) ...[
                    Text(
                      snapshot.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('本地事实 · AI 不负责计算'),
                          const SizedBox(height: 12),
                          Text(
                            '收入 ${money(snapshot.data['income'])}\n支出 ${money(snapshot.data['expense'])}\n结余 ${money(snapshot.data['income'] - snapshot.data['expense'])}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '统计范围：${snapshot.data['start']} 至 ${snapshot.data['end_exclusive']}（不含末日）\n比较范围：${snapshot.data['comparison']['start']} 至 ${snapshot.data['comparison']['end_exclusive']}（不含末日）\n生成依据时间：${snapshot.capturedAt.toLocal().toString().split('.').first}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (snapshot
                                  .data['comparison']['change_basis_points'] ==
                              null)
                            const Text('上期为零，不计算增长百分比。'),
                          if (snapshot
                                  .data['comparison']['change_basis_points'] !=
                              null)
                            Text(
                              '较上期变化：${(snapshot.data['comparison']['change_basis_points'] / 100).toStringAsFixed(2)}%（本地计算）',
                            ),
                          ExpansionTile(
                            trailing: const Icon(
                              LucideIcons.chevronDown,
                              size: 18,
                            ),
                            tilePadding: EdgeInsets.zero,
                            title: const Text('查看统计汇总'),
                            children: [
                              SelectableText(
                                snapshot.text,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '仅代表已记录账目，不包含未来账单。AI 建议可能有误，不会修改账本。',
                      style: TextStyle(color: ink.muted),
                    ),
                    if (_stale)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('账本已更新，本对话仍基于旧数据；可重新分析。'),
                      ),
                    if (!compatible)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('服务或模型已改变。旧对话只供查看，不会转发，请生成新报告。'),
                      ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed:
                              disabled ||
                                  !snapshot.available ||
                                  persistenceError != null
                              ? null
                              : () => _send(regenerate: conversation != null),
                          child: Text(
                            conversation == null ? '生成分析' : '重新分析 · 新对话',
                          ),
                        ),
                        if (_service.config == null)
                          TextButton(
                            onPressed: disabled ? null : _settings,
                            child: const Text('配置 AI 服务'),
                          ),
                        if (_service.busy)
                          TextButton(
                            onPressed: _service.stop,
                            child: const Text('停止生成'),
                          ),
                      ],
                    ),
                    if (!snapshot.available)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('没有可分析的已记录数据，或所选期间在未来。不会请求 API。'),
                      ),
                  ],
                  if (conversation != null && persistenceError != null)
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(persistenceError),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: disabled
                                    ? null
                                    : () async {
                                        try {
                                          await _service.retrySave(
                                            conversation,
                                          );
                                          if (mounted) {
                                            setState(() => _error = null);
                                          }
                                        } catch (error) {
                                          if (mounted) {
                                            setState(
                                              () => _error = _aiError(error),
                                            );
                                          }
                                        }
                                      },
                                child: const Text('仅重试本地保存'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: conversation.turns
                                          .map(
                                            (t) => '${t.question}\n${t.answer}',
                                          )
                                          .join('\n\n'),
                                    ),
                                  );
                                  if (context.mounted) {
                                    message(context, '回复已复制，请妥善保存。');
                                  }
                                },
                                child: const Text('复制回复'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (conversation != null)
                    ...conversation.turns.map(
                      (turn) => Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                turn.question,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const Divider(height: 24),
                              SelectableText(
                                turn.answer.isEmpty ? '正在等待回复…' : turn.answer,
                              ),
                              const SizedBox(height: 8),
                              Text(switch (turn.status) {
                                AiTurnStatus.running => '生成中…',
                                AiTurnStatus.complete => '已完成',
                                AiTurnStatus.failed => '未完成',
                                AiTurnStatus.stopped => '已停止',
                              }, style: Theme.of(context).textTheme.bodySmall),
                              if (turn.error != null) Text(turn.error!),
                              if (turn.tokens != null)
                                Text(
                                  '接口返回用量：${turn.tokens} tokens',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (conversation?.hasReport == true && compatible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _input,
                      enabled: !disabled,
                      minLines: 1,
                      maxLines: 2,
                      maxLength: aiInputLimit,
                      decoration: const InputDecoration(
                        labelText: '继续追问',
                        hintText: '聊天内容会发送，请勿输入敏感信息',
                        counterText: '',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: disabled || persistenceError != null
                            ? null
                            : () => _send(),
                        child: const Text('预览并发送'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AiHistoryScreen extends StatefulWidget {
  const AiHistoryScreen({super.key, required this.service});
  final AiService service;
  @override
  State<AiHistoryScreen> createState() => _AiHistoryScreenState();
}

class _AiHistoryScreenState extends State<AiHistoryScreen> {
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.service.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI 历史')),
    body: widget.service.history.isEmpty
        ? const EmptyView(title: '还没有 AI 记录', subtitle: '生成报告后，会加密保存在本机。')
        : ListView.builder(
            itemCount: widget.service.history.length,
            itemBuilder: (context, index) {
              final conversation = widget.service.history[index];
              return ListTile(
                title: Text(conversation.snapshot.title),
                subtitle: Text(
                  '${conversation.createdAt.toLocal().toString().split('.').first}\n${conversation.config.model} · ${conversation.hasReport ? '报告已完成' : '报告未完成'}',
                ),
                onTap: widget.service.busy
                    ? null
                    : () => Navigator.pop(context, conversation),
                trailing: IconButton(
                  tooltip: '删除对话',
                  icon: const Icon(LucideIcons.trash2),
                  onPressed: widget.service.busy
                      ? null
                      : () async {
                          if (!await confirm(
                                context,
                                title: '删除这段对话？',
                                body: '同时删除本地报告、聊天和关联汇总。不会删除账本或服务商副本。',
                                action: '删除',
                              ) ||
                              !context.mounted) {
                            return;
                          }
                          try {
                            await widget.service.delete(conversation.id);
                          } catch (error) {
                            if (context.mounted) {
                              message(context, _aiError(error));
                            }
                          }
                        },
                ),
              );
            },
          ),
  );
}
