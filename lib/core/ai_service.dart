import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'ai_client.dart';
import 'ai_models.dart';
import 'ai_snapshot.dart';
import 'ai_storage.dart';
import 'database.dart';

class AiService extends ChangeNotifier {
  AiService(this.ledger, {AiStorage? storage, AiChatClient? client})
    : storage = storage ?? AiStorage(),
      client = client ?? DioAiChatClient();
  final LedgerDatabase ledger;
  final AiStorage storage;
  final AiChatClient client;
  AiConfig? config;
  List<AiConversation> history = [];
  Future<void>? _loading;
  bool busy = false, _disposed = false, _stopRequested = false;
  CancelToken? _cancel;
  Timer? _updates;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _loading ??= _load();
  Future<void> _load() async {
    try {
      config = await storage.config();
      history = await storage.conversations();
      _notify();
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  Future<void> configure(AiConfig selected, String key) async {
    if (busy) throw const FormatException('请先停止当前请求。');
    await storage.saveConfig(selected, key);
    config = selected;
    _notify();
  }

  AiConversation? cached(AiSnapshot snapshot) {
    final selected = config;
    if (selected == null) return null;
    for (final conversation in history) {
      if (conversation.matches(snapshot, selected)) return conversation;
    }
    return null;
  }

  bool compatible(AiConversation conversation) =>
      config?.endpoint == conversation.config.endpoint &&
      config?.model == conversation.config.model;

  Future<void> send(AiConversation conversation, String question) async {
    if (busy) throw const FormatException('当前请求尚未结束。');
    final selected = config;
    if (selected == null || !compatible(conversation)) {
      throw const FormatException('服务或模型已改变，请生成新报告，不会转发旧对话。');
    }
    if (!conversation.snapshot.available) {
      throw const FormatException('所选期间没有已记录数据，或属于未来期间。');
    }
    final body = aiRequest(selected, aiMessages(conversation, question));
    // Lock before any await to prevent duplicate requests from rapid taps.
    busy = true;
    _stopRequested = false;
    _cancel = CancelToken();
    _notify();
    AiTurn? turn;
    try {
      final key = await storage.keyFor(selected);
      if (key == null) throw const FormatException('请先配置此服务地址的 API 密钥。');
      if (!await storage.consented(selected)) {
        throw const FormatException('请先确认数据发送范围和服务地址。');
      }
      if (_stopRequested || _disposed) {
        throw const AiFailure(AiErrorKind.cancelled);
      }
      turn = AiTurn(question: question.trim());
      conversation.turns.add(turn);
      if (!history.contains(conversation)) history.insert(0, conversation);
      // Persist the pending request before sending; restart never repeats it.
      await storage.save(conversation);
      if (_stopRequested || _disposed) {
        throw const AiFailure(AiErrorKind.cancelled);
      }
      var done = false, truncated = false;
      await for (final event in client.send(selected, key, body, _cancel!)) {
        if (_stopRequested) throw const AiFailure(AiErrorKind.cancelled);
        turn.answer += event.text;
        if (turn.answer.length > 40000) {
          throw const AiFailure(AiErrorKind.protocol);
        }
        turn.tokens = event.tokens ?? turn.tokens;
        done = done || event.done;
        truncated = truncated || event.truncated;
        _updates ??= Timer(const Duration(milliseconds: 100), () {
          _updates = null;
          _notify();
        });
      }
      if (!done) throw const AiFailure(AiErrorKind.protocol);
      turn.status = truncated ? AiTurnStatus.failed : AiTurnStatus.complete;
      if (truncated) turn.error = '回复达到输出限制，内容未完整；不会作为追问上下文。';
    } catch (error) {
      if (turn == null) rethrow;
      turn.status =
          _stopRequested ||
              error is AiFailure && error.kind == AiErrorKind.cancelled
          ? AiTurnStatus.stopped
          : AiTurnStatus.failed;
      turn.error = error is AiFailure ? error.message : '操作未完成，未自动重发。账本不受影响。';
    } finally {
      _updates?.cancel();
      _updates = null;
      _cancel?.cancel();
      _cancel = null;
      try {
        if (turn != null) await storage.save(conversation);
      } finally {
        busy = false;
        _notify();
      }
    }
  }

  Future<String> testConnection() async {
    if (busy) throw const FormatException('请等待当前请求结束。');
    final selected = config;
    if (selected == null) throw const FormatException('请先保存接口配置。');
    final body = aiRequest(selected, [
      {'role': 'user', 'content': '这是接口连接测试，不含账本。请只回复：连接成功。'},
    ]);
    busy = true;
    _stopRequested = false;
    _cancel = CancelToken();
    _notify();
    try {
      final key = await storage.keyFor(selected);
      if (key == null) throw const FormatException('请先保存 API 密钥。');
      if (_stopRequested) throw const AiFailure(AiErrorKind.cancelled);
      var done = false;
      int? tokens;
      await for (final event in client.send(selected, key, body, _cancel!)) {
        if (_stopRequested) throw const AiFailure(AiErrorKind.cancelled);
        done |= event.done;
        tokens = event.tokens ?? tokens;
      }
      if (!done) throw const AiFailure(AiErrorKind.protocol);
      return '连接成功${tokens == null ? '，接口未返回用量' : '，用量 $tokens tokens'}。';
    } finally {
      _cancel?.cancel();
      _cancel = null;
      busy = false;
      _notify();
    }
  }

  void stop() {
    _stopRequested = true;
    _cancel?.cancel();
  }

  Future<void> delete(String id) async {
    if (busy) throw const FormatException('请先停止请求。');
    await storage.delete(id);
    history.removeWhere((c) => c.id == id);
    _notify();
  }

  Future<void> clear() async {
    if (busy) throw const FormatException('请先停止请求。');
    await storage.clear();
    history.clear();
    _loading = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _updates?.cancel();
    super.dispose();
  }
}
