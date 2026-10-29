import '../l10n/system_messages.dart';
import '../l10n/localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/ai_models.dart';
import '../core/ai_service.dart';
import '../core/ai_snapshot.dart';
import '../core/controller.dart';
import '../core/models.dart';
import 'common.dart';
import 'theme.dart';
import 'ai_settings.dart';
export 'ai_settings.dart' show AiSettingsScreen;

String _aiError(BuildContext context, Object error) =>
    errorText(context, error);

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
  Object? _error;
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
      _conversation = _service.cached(
        _snapshot!,
        language: LanguageSettings.instance.tag,
      );
      _revision = widget.controller.revision;
    } catch (error) {
      if (mounted) _error = error;
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
      if (mounted) {
        setState(
          () => _error = const LocalizedFailure(
            'cannotCheckTheLatestLedgerPleaseRetry',
            '',
          ),
        );
      }
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

  Future<bool> _preview(
    AiConversation conversation,
    String question,
    String language,
  ) async {
    final selected = _service.config!;
    final body = aiRequest(
      selected,
      aiMessages(conversation, question, language: language),
    );
    final first = !await _service.storage.consented(selected);
    if (!mounted) return false;
    final result =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              first
                  ? tr(context).confirmRecipientAndDataScope
                  : tr(context).confirmThisRequest,
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context).recipientPModelPOnlyStatisticalSummaries(
                        (selected.endpoint).toString(),
                        (selected.model).toString(),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(tr(context).followUpsIncludeTheOriginalReportAnd),
                    ExpansionTile(
                      trailing: Icon(LucideIcons.chevronDown, size: 18),
                      tilePadding: EdgeInsets.zero,
                      title: Text(tr(context).viewExactRequestContent),
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
                child: Text(tr(context).cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr(context).confirmAndSend),
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
    final language = LanguageSettings.instance.tag;
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
        if (!mounted) return;
        if (!snapshot.available) {
          throw const FormatException('该期间没有已记录数据，或属于未来期间，未发送请求。');
        }
        if (!regenerate) {
          final cache = _service.cached(snapshot, language: language);
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
          language: language,
        );
        question = tr(context).analyzeThisIncomeAndExpenseSummaryMain;
      } else {
        conversation = _conversation!;
        question = _input.text.trim();
      }
      if (!await _preview(conversation, question, language) || !mounted) return;
      setState(() {
        _conversation = conversation;
        _snapshot = conversation.snapshot;
      });
      _input.clear();
      await _service.send(conversation, question, language: language);
      await _checkData();
    } catch (error) {
      if (mounted) setState(() => _error = error);
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
        title: Text(tr(context).aiAnalysis),
        actions: [
          IconButton(
            tooltip: tr(context).history,
            onPressed: disabled ? null : _history,
            icon: Icon(LucideIcons.history),
          ),
          IconButton(
            tooltip: tr(context).aiService,
            onPressed: disabled ? null : _settings,
            icon: Icon(LucideIcons.settings2),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: EdgeInsets.all(20),
                children: [
                  if (_loading) LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Text(errorText(context, _error!)),
                    ),
                  if (snapshot != null) ...[
                    Text(
                      (systemMessage(context, snapshot.title) ??
                          snapshot.title),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 12),
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionTitle(
                            tr(context).localFactsAiDoesNotCalculateTotals,
                          ),
                          SizedBox(height: 12),
                          Text(
                            tr(context).incomePExpensesPBalanceP(
                              (money(snapshot.data['income'])).toString(),
                              (money(snapshot.data['expense'])).toString(),
                              (money(
                                snapshot.data['income'] -
                                    snapshot.data['expense'],
                              )).toString(),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            tr(context).periodPToPEndExcludedComparison(
                              (snapshot.data['start']).toString(),
                              (snapshot.data['end_exclusive']).toString(),
                              (snapshot.data['comparison']['start']).toString(),
                              (snapshot.data['comparison']['end_exclusive'])
                                  .toString(),
                              (snapshot.capturedAt
                                      .toLocal()
                                      .toString()
                                      .split('.')
                                      .first)
                                  .toString(),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (snapshot
                                  .data['comparison']['change_basis_points'] ==
                              null)
                            Text(tr(context).thePreviousPeriodIsZeroNoGrowth),
                          if (snapshot
                                  .data['comparison']['change_basis_points'] !=
                              null)
                            Text(
                              tr(
                                context,
                              ).changeFromPreviousPeriodPCalculatedLocally(
                                ((snapshot.data['comparison']['change_basis_points'] /
                                            100)
                                        .toStringAsFixed(2))
                                    .toString(),
                              ),
                            ),
                          ExpansionTile(
                            trailing: Icon(LucideIcons.chevronDown, size: 18),
                            tilePadding: EdgeInsets.zero,
                            title: Text(tr(context).viewStatisticalSummary),
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
                    SizedBox(height: 12),
                    Text(
                      tr(context).onlyRecordedEntriesAreIncludedExcludingFuture,
                      style: TextStyle(color: ink.muted),
                    ),
                    if (_stale)
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          tr(context).yourLedgerHasChangedThisConversationStill,
                        ),
                      ),
                    if (!compatible)
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(tr(context).theServiceOrModelHasChangedOld),
                      ),
                    SizedBox(height: 14),
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
                            conversation == null
                                ? tr(context).generateAnalysis
                                : tr(context).analyzeAgainNewConversation,
                          ),
                        ),
                        if (_service.config == null)
                          TextButton(
                            onPressed: disabled ? null : _settings,
                            child: Text(tr(context).configureAiService),
                          ),
                        if (_service.busy)
                          TextButton(
                            onPressed: _service.stop,
                            child: Text(tr(context).stopGenerating),
                          ),
                      ],
                    ),
                    if (!snapshot.available)
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(tr(context).noRecordedDataToAnalyzeOrThe),
                      ),
                  ],
                  if (conversation != null && persistenceError != null)
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            systemMessage(context, persistenceError) ??
                                tr(context)
                                    .operationFailedPleaseRetryYourExistingData,
                          ),
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
                                            setState(() => _error = error);
                                          }
                                        }
                                      },
                                child: Text(tr(context).retryLocalSaveOnly),
                              ),
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text: conversation.turns
                                            .map(
                                              (t) =>
                                                  '${t.question}\n${t.answer}',
                                            )
                                            .join('\n\n'),
                                      ),
                                    );
                                    if (context.mounted) {
                                      message(
                                        context,
                                        tr(context)
                                            .replyCopiedKeepItSomewhereSafe,
                                      );
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      message(
                                        context,
                                        tr(context)
                                            .copyFailedLongPressTheReplyTo,
                                      );
                                    }
                                  }
                                },
                                child: Text(tr(context).copyReply),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (conversation != null)
                    ...conversation.turns.map(
                      (turn) => Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                turn.question,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Divider(height: 24),
                              SelectableText(
                                turn.answer.isEmpty
                                    ? tr(context).waitingForAReply
                                    : turn.answer,
                              ),
                              SizedBox(height: 8),
                              Text(switch (turn.status) {
                                AiTurnStatus.running => tr(context).generating,
                                AiTurnStatus.complete => tr(context).complete,
                                AiTurnStatus.failed => tr(context).incomplete,
                                AiTurnStatus.stopped => tr(context).stopped,
                              }, style: Theme.of(context).textTheme.bodySmall),
                              if (turn.error != null)
                                Text(
                                  systemMessage(context, turn.error!) ??
                                      tr(
                                        context,
                                      ).operationFailedPleaseRetryYourExistingData,
                                ),
                              if (turn.tokens != null)
                                Text(
                                  tr(context).reportedUsagePTokens(
                                    (turn.tokens).toString(),
                                  ),
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
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _input,
                      enabled: !disabled,
                      minLines: 1,
                      maxLines: 2,
                      maxLength: aiInputLimit,
                      decoration: InputDecoration(
                        labelText: tr(context).askAFollowUp,
                        hintText: tr(context).messagesWillBeSentDoNotEnter,
                        counterText: '',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: disabled || persistenceError != null
                            ? null
                            : () => _send(),
                        child: Text(tr(context).previewAndSend),
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
    appBar: AppBar(title: Text(tr(context).aiHistory)),
    body: widget.service.history.isEmpty
        ? EmptyView(
            title: tr(context).noAiRecordsYet,
            subtitle: tr(context).generatedReportsAreEncryptedAndSavedOn,
          )
        : ListView.builder(
            itemCount: widget.service.history.length,
            itemBuilder: (context, index) {
              final conversation = widget.service.history[index];
              return ListTile(
                title: Text(
                  systemMessage(context, conversation.snapshot.title) ??
                      conversation.snapshot.title,
                ),
                subtitle: Text(
                  '${conversation.createdAt.toLocal().toString().split('.').first}\n${conversation.config.model} · ${conversation.hasReport ? tr(context).reportComplete : tr(context).reportIncomplete}',
                ),
                onTap: widget.service.busy
                    ? null
                    : () => Navigator.pop(context, conversation),
                trailing: IconButton(
                  tooltip: tr(context).deleteConversation,
                  icon: Icon(LucideIcons.trash2),
                  onPressed: widget.service.busy
                      ? null
                      : () async {
                          if (!await confirm(
                                context,
                                title: tr(context).deleteThisConversation,
                                body: tr(context)
                                    .deletesTheLocalReportChatAndAssociated,
                                action: tr(context).delete,
                              ) ||
                              !context.mounted) {
                            return;
                          }
                          try {
                            await widget.service.delete(conversation.id);
                          } catch (error) {
                            if (context.mounted) {
                              message(context, _aiError(context, error));
                            }
                          }
                        },
                ),
              );
            },
          ),
  );
}
