import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'ai_catalog.dart';
import 'ai_models.dart';

abstract interface class AiModelCatalogClient {
  Future<AiCatalogResult> fetch(
    AiConfig config,
    String key,
    Uri address,
    CancelToken cancel,
  );
}

/// Only GET/authentication; deliberately has no ledger or chat dependency.
class DioAiModelCatalogClient implements AiModelCatalogClient {
  DioAiModelCatalogClient({
    Dio? dio,
    this.totalTimeout = const Duration(seconds: 60),
  }) : _dio = dio ?? Dio();
  final Dio _dio;
  final Duration totalTimeout;
  @override
  Future<AiCatalogResult> fetch(
    AiConfig config,
    String key,
    Uri address,
    CancelToken cancel,
  ) async {
    validateCatalogUri(config.endpoint, address.toString());
    _dio.options.connectTimeout = const Duration(seconds: 15);
    if (key.trim().isEmpty || key.contains('\n') || key.contains('\r')) {
      throw const FormatException('请先保存有效密钥。');
    }
    var timedOut = false;
    final timer = Timer(totalTimeout, () {
      timedOut = true;
      cancel.cancel();
    });
    try {
      return await _fetch(config, key, address, cancel).timeout(
        totalTimeout,
        onTimeout: () {
          cancel.cancel();
          throw const FormatException('模型刷新超时，原列表和刷新时间已保留。');
        },
      );
    } on DioException catch (e) {
      if (timedOut ||
          [
            DioExceptionType.connectionTimeout,
            DioExceptionType.receiveTimeout,
            DioExceptionType.sendTimeout,
          ].contains(e.type)) {
        throw const FormatException('模型刷新超时，原列表和刷新时间已保留。');
      }
      if (CancelToken.isCancel(e)) {
        throw const FormatException('已取消模型刷新，原列表已保留。');
      }
      if (e.type == DioExceptionType.badCertificate ||
          e.error is HandshakeException) {
        throw const FormatException('模型查询证书验证失败，未绕过证书校验。');
      }
      throw const FormatException('模型刷新网络失败，原列表已保留，请检查网络。');
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('模型列表格式错误，原列表已保留。');
    } finally {
      timer.cancel();
    }
  }

  Future<AiCatalogResult> _fetch(
    AiConfig config,
    String key,
    Uri address,
    CancelToken cancel,
  ) async {
    final qwen = providerForEndpoint(config.endpoint)?.id == 'qwen';
    final models = <String, AiCatalogModel>{};
    var bytes = 0, seen = 0;
    int? total;
    for (var page = 1; page <= 20; page++) {
      if (cancel.isCancelled) {
        throw cancel.cancelError!;
      }
      final uri = qwen
          ? address.replace(
              queryParameters: {
                'capabilities': 'TG',
                'page_no': '$page',
                'page_size': '100',
              },
            )
          : address;
      final response = await _dio.getUri<ResponseBody>(
        uri,
        cancelToken: cancel,
        options: Options(
          headers: {
            'Authorization': 'Bearer $key',
            'Accept': 'application/json',
          },
          responseType: ResponseType.stream,
          followRedirects: false,
          maxRedirects: 0,
          validateStatus: (_) => true,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      final status = response.statusCode ?? 0;
      if (status != 200) {
        await response.data?.stream.listen((_) {}).cancel();
        throw FormatException(switch (status) {
          401 || 403 => '模型查询鉴权失败，请核对密钥和账号权限。',
          404 || 405 => '接口不支持此模型列表地址，请使用手动输入或查看官方说明。',
          429 => '模型查询被限流或额度不足，不会自动重试。',
          >= 300 && < 400 => '模型查询拒绝重定向，不会转发密钥。',
          _ => '模型查询失败（HTTP $status），原列表已保留。',
        });
      }
      final body = response.data;
      if (body == null) throw const FormatException('模型列表为空，原列表已保留。');
      final raw = <int>[];
      await for (final chunk in body.stream) {
        if (cancel.isCancelled) {
          throw cancel.cancelError!;
        }
        bytes += chunk.length;
        if (bytes > 2 * 1024 * 1024) {
          cancel.cancel();
          throw const FormatException('模型列表超过 2 MB，列表不完整，未替换缓存。');
        }
        raw.addAll(chunk);
      }
      final decoded = jsonDecode(utf8.decode(raw));
      if (decoded is! Map) throw const FormatException('模型列表格式错误，原列表已保留。');
      Object? rows;
      if (qwen) {
        final output = decoded['output'];
        if (decoded['success'] == false ||
            output is! Map ||
            output['total'] is! int ||
            output['page_no'] != page) {
          throw const FormatException('千问模型分页格式错误，未替换缓存。');
        }
        final count = output['total'] as int;
        if (count < 0 || count > 2000 || (total != null && count != total)) {
          throw const FormatException('模型分页总数异常或超过 2,000 条，列表不完整，未替换缓存。');
        }
        total = count;
        rows = output['models'];
      } else {
        if (decoded['has_more'] == true ||
            decoded['next_page_token'] != null ||
            decoded['nextPageToken'] != null ||
            decoded['next'] != null) {
          throw const FormatException('模型列表分页未完成，未替换缓存。');
        }
        rows = decoded['data'];
      }
      if (rows is! List) throw const FormatException('模型列表格式错误，原列表已保留。');
      seen += rows.length;
      if (seen > 2000) throw const FormatException('模型列表超过 2,000 条，未替换缓存。');
      for (final row in rows) {
        if (row is! Map) throw const FormatException('模型目录项损坏，原列表已保留。');
        final id = row[qwen ? 'model' : 'id'];
        if (id is! String ||
            id.trim().isEmpty ||
            id.length > 200 ||
            RegExp(r'[\r\n]').hasMatch(id)) {
          throw const FormatException('模型 ID 无效，原列表已保留。');
        }
        final capability = _textChat(row, qwen);
        if (capability == false) continue;
        final provider = providerForEndpoint(config.endpoint);
        final known = provider?.models.where((m) => m.id == id).firstOrNull;
        models[id] = AiCatalogModel(
          id,
          name: known?.name,
          brand: known?.brand,
          textChat: capability,
          tokenField: known == null ? null : provider!.tokenField,
        );
      }
      if (!qwen || seen == total) {
        if (cancel.isCancelled) {
          throw cancel.cancelError!;
        }
        if (models.isEmpty) throw const FormatException('未返回可选择的文本模型，原列表已保留。');
        final recommendations =
            providerForEndpoint(config.endpoint)?.models
                .map((m) => m.id)
                .toList() ??
            <String>[];
        final list = models.values.toList()
          ..sort((a, b) {
            final ai = recommendations.indexOf(a.id),
                bi = recommendations.indexOf(b.id);
            if (ai >= 0 || bi >= 0) {
              return (ai < 0 ? 2001 : ai).compareTo(bi < 0 ? 2001 : bi);
            }
            return a.id.compareTo(b.id);
          });
        return AiCatalogResult(
          endpoint: config.endpoint,
          source: address.toString(),
          refreshedAt: DateTime.now(),
          models: list,
        );
      }
      if (rows.isEmpty || seen > total!) {
        throw const FormatException('模型分页未完成，未替换缓存。');
      }
    }
    throw const FormatException('模型列表超过 20 页，列表不完整，未替换缓存。');
  }

  bool? _textChat(Map row, bool qwen) {
    if (row['supports_text_chat'] is bool) {
      return row['supports_text_chat'] as bool;
    }
    final metadata = row['inference_metadata'];
    final input = qwen && metadata is Map
        ? metadata['request_modality']
        : row['input_modalities'];
    final output = qwen && metadata is Map
        ? metadata['response_modality']
        : row['output_modalities'];
    bool hasText(List values) =>
        values.any((v) => v is String && v.toLowerCase() == 'text');
    if (input is List && !hasText(input) ||
        output is List && !hasText(output)) {
      return false;
    }
    final capabilities = row[qwen ? 'capabilities' : 'api_capabilities'];
    if (qwen && capabilities is List) {
      return capabilities.contains('TG') || capabilities.contains('Reasoning');
    }
    if (capabilities is List &&
        capabilities.contains('chat_completions') &&
        input is List &&
        output is List) {
      return true;
    }
    return null;
  }
}
