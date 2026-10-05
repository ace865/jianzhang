import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'ai_models.dart';

enum AiErrorKind {
  authentication,
  quota,
  network,
  timeout,
  certificate,
  protocol,
  cancelled,
}

class AiFailure implements Exception {
  const AiFailure(this.kind);
  final AiErrorKind kind;
  String get message => switch (kind) {
    AiErrorKind.authentication => '密钥无效或没有模型权限，请检查配置。',
    AiErrorKind.quota => '额度不足或请求被限流，请到服务商检查后手动重试。',
    AiErrorKind.network => '网络连接失败，请检查网络后手动重试。',
    AiErrorKind.timeout => '请求超时，未自动重发；服务商可能已处理并计费。',
    AiErrorKind.certificate => '安全证书验证失败，不会跳过验证。',
    AiErrorKind.protocol => '接口或回复格式不兼容，请检查端点、模型、输出限制参数或切换完整回复模式。',
    AiErrorKind.cancelled => '请求已停止；不能保证服务商停止处理或免收费用。',
  };
  @override
  String toString() => message;
}

class AiEvent {
  const AiEvent({
    this.text = '',
    this.tokens,
    this.done = false,
    this.truncated = false,
  });
  final String text;
  final int? tokens;
  final bool done, truncated;
}

abstract interface class AiChatClient {
  Stream<AiEvent> send(
    AiConfig config,
    String key,
    String body,
    CancelToken cancel,
  );
}

class DioAiChatClient implements AiChatClient {
  DioAiChatClient({
    Dio? dio,
    this.totalTimeout = const Duration(seconds: 180),
    this.idleTimeout = const Duration(seconds: 60),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 60),
               receiveTimeout: const Duration(seconds: 60),
             ),
           );
  final Dio _dio;
  final Duration totalTimeout, idleTimeout;

  @override
  Stream<AiEvent> send(
    AiConfig config,
    String key,
    String body,
    CancelToken cancel,
  ) async* {
    config.validate();
    if (utf8.encode(body).length > aiRequestLimit) {
      throw const FormatException('上下文超过 96 KiB。');
    }
    if (key.isEmpty || RegExp(r'[\r\n]').hasMatch(key)) {
      throw const AiFailure(AiErrorKind.authentication);
    }
    var timedOut = false;
    final timer = Timer(totalTimeout, () {
      timedOut = true;
      cancel.cancel();
    });
    try {
      final response = await _dio.post<ResponseBody>(
        config.endpoint,
        data: body,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          maxRedirects: 0,
          validateStatus: (_) => true,
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
            'Accept': config.streaming
                ? 'text/event-stream'
                : 'application/json',
          },
        ),
      );
      final status = response.statusCode ?? 0;
      if (status != 200) {
        // Never surface raw provider errors: they may echo prompts or secrets.
        response.data?.stream.listen((_) {}).cancel();
        throw AiFailure(
          status == 401 || status == 403
              ? AiErrorKind.authentication
              : status == 402 || status == 429
              ? AiErrorKind.quota
              : status >= 500
              ? AiErrorKind.network
              : AiErrorKind.protocol,
        );
      }
      if (response.data == null) throw const AiFailure(AiErrorKind.protocol);
      var received = 0;
      final bytes = _cancelable(response.data!.stream, cancel, () => timedOut)
          .timeout(idleTimeout)
          .map<List<int>>((chunk) {
            received += chunk.length;
            if (received > 2 * 1024 * 1024) {
              throw const AiFailure(AiErrorKind.protocol);
            }
            if (cancel.isCancelled) {
              throw const AiFailure(AiErrorKind.cancelled);
            }
            return chunk;
          });
      if (config.streaming) {
        if (!(response.headers.value('content-type') ?? '')
            .toLowerCase()
            .contains('text/event-stream')) {
          throw const AiFailure(AiErrorKind.protocol);
        }
        await for (final event in parseAiSse(bytes)) {
          yield event;
        }
      } else {
        final buffer = BytesBuilder(copy: false);
        await for (final chunk in bytes) {
          buffer.add(chunk);
        }
        final json = jsonDecode(utf8.decode(buffer.takeBytes()));
        yield parseAiCompletion(json);
      }
    } on AiFailure {
      if (timedOut) throw const AiFailure(AiErrorKind.timeout);
      rethrow;
    } on TimeoutException {
      throw const AiFailure(AiErrorKind.timeout);
    } on DioException catch (error) {
      if (error.error is HandshakeException) {
        throw const AiFailure(AiErrorKind.certificate);
      }
      throw AiFailure(
        timedOut
            ? AiErrorKind.timeout
            : switch (error.type) {
                DioExceptionType.cancel => AiErrorKind.cancelled,
                DioExceptionType.connectionTimeout ||
                DioExceptionType.sendTimeout ||
                DioExceptionType.receiveTimeout => AiErrorKind.timeout,
                DioExceptionType.badCertificate => AiErrorKind.certificate,
                _ => AiErrorKind.network,
              },
      );
    } catch (_) {
      if (timedOut) throw const AiFailure(AiErrorKind.timeout);
      if (cancel.isCancelled) throw const AiFailure(AiErrorKind.cancelled);
      throw const AiFailure(AiErrorKind.protocol);
    } finally {
      timer.cancel();
      cancel.cancel();
    }
  }
}

Stream<Uint8List> _cancelable(
  Stream<Uint8List> source,
  CancelToken cancel,
  bool Function() timedOut,
) {
  late StreamController<Uint8List> controller;
  StreamSubscription<Uint8List>? subscription;
  var ended = false;
  controller = StreamController<Uint8List>(
    onListen: () {
      subscription = source.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          ended = true;
          controller.close();
        },
      );
      cancel.whenCancel.then((_) {
        if (!ended) {
          ended = true;
          controller.addError(
            AiFailure(timedOut() ? AiErrorKind.timeout : AiErrorKind.cancelled),
          );
          controller.close();
          subscription?.cancel();
        }
      });
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () {
      ended = true;
      return subscription?.cancel();
    },
  );
  return controller.stream;
}

AiEvent parseAiCompletion(dynamic raw) {
  try {
    final choice = (raw['choices'] as List).single as Map;
    final message = choice['message'] as Map;
    if (message['tool_calls'] != null ||
        message['function_call'] != null ||
        message['role'] != 'assistant') {
      throw const FormatException();
    }
    final text = message['content'];
    final finish = choice['finish_reason'];
    if (text is! String ||
        text.trim().isEmpty ||
        !['stop', 'length'].contains(finish)) {
      throw const FormatException();
    }
    return AiEvent(
      text: text,
      done: true,
      truncated: finish == 'length',
      tokens: _tokens(raw),
    );
  } catch (_) {
    throw const AiFailure(AiErrorKind.protocol);
  }
}

int? _tokens(dynamic raw) {
  final value = raw['usage']?['total_tokens'];
  return value is int && value >= 0 ? value : null;
}

/// UTF-8 is decoded across byte chunks, SSE across lines/events (not chunks).
Stream<AiEvent> parseAiSse(Stream<List<int>> bytes) async* {
  final eventLines = <String>[];
  var finished = false, hasText = false;
  try {
    await for (final line
        in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (eventLines.isEmpty) continue;
        final payload = eventLines.join('\n');
        eventLines.clear();
        if (payload == '[DONE]') {
          if (!finished || !hasText) {
            throw const AiFailure(AiErrorKind.protocol);
          }
          yield const AiEvent(done: true);
          return;
        }
        final raw = jsonDecode(payload);
        if (raw is! Map || raw['error'] != null) {
          throw const AiFailure(AiErrorKind.protocol);
        }
        final choices = raw['choices'] as List;
        final tokens = _tokens(raw);
        if (tokens != null) yield AiEvent(tokens: tokens);
        if (choices.isEmpty) continue;
        final choice = choices.single as Map;
        final delta = choice['delta'] as Map;
        if (finished ||
            delta['tool_calls'] != null ||
            delta['function_call'] != null) {
          throw const AiFailure(AiErrorKind.protocol);
        }
        final text = delta['content'];
        if (text != null && text is! String) {
          throw const AiFailure(AiErrorKind.protocol);
        }
        if (text is String && text.isNotEmpty) {
          hasText = true;
          yield AiEvent(text: text);
        }
        final finish = choice['finish_reason'];
        if (finish != null) {
          if (!['stop', 'length'].contains(finish)) {
            throw const AiFailure(AiErrorKind.protocol);
          }
          finished = true;
          if (finish == 'length') yield const AiEvent(truncated: true);
        }
      } else if (line.startsWith('data:')) {
        eventLines.add(line.substring(5).replaceFirst(RegExp(r'^ '), ''));
        if (eventLines.join().length > 128 * 1024) {
          throw const AiFailure(AiErrorKind.protocol);
        }
      }
    }
    // EOF without terminal marker is incomplete, even when some text arrived.
    throw const AiFailure(AiErrorKind.protocol);
  } on AiFailure {
    rethrow;
  } on TimeoutException {
    rethrow;
  } on DioException {
    rethrow;
  } catch (_) {
    throw const AiFailure(AiErrorKind.protocol);
  }
}
