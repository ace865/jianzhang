import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianzhang/core/ai_catalog.dart';
import 'package:jianzhang/core/ai_catalog_client.dart';
import 'package:jianzhang/core/ai_models.dart';
import 'package:jianzhang/core/ai_storage.dart';

import 'ai_test.dart' show MemorySecrets, fakeKey;

class CatalogAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object? payload = {
    'data': [
      {'id': 'test-model'},
    ],
  };
  int status = 200;
  DioExceptionType? failure;
  Object? error;
  Completer<void>? wait;
  bool slowBody = false;
  Object? Function(RequestOptions)? respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (wait != null) {
      await Future.any([
        wait!.future,
        cancelFuture ?? Completer<void>().future,
      ]);
    }
    if (options.cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    }
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!, error: error);
    }
    final value = respond?.call(options) ?? payload;
    if (slowBody) {
      return ResponseBody(
        Stream<Uint8List>.periodic(
          const Duration(seconds: 1),
          (_) => Uint8List.fromList([32]),
        ),
        status,
      );
    }
    return ResponseBody.fromString(
      value is String ? value : jsonEncode(value),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late CatalogAdapter adapter;
  late DioAiModelCatalogClient client;
  final config = AiConfig(
    endpoint: aiProviders[0].endpoint,
    model: 'deepseek-flash',
  );
  Future<AiCatalogResult> fetch({AiConfig? selected, CancelToken? cancel}) =>
      client.fetch(
        selected ?? config,
        fakeKey,
        catalogUri(selected ?? config),
        cancel ?? CancelToken(),
      );
  setUp(() {
    adapter = CatalogAdapter();
    client = DioAiModelCatalogClient(dio: Dio()..httpClientAdapter = adapter);
  });
  test(
    'all presets validate; endpoints are distinct and manual input survives',
    () {
      expect(aiProviders.length, 7);
      expect(aiProviders.map((p) => p.endpoint).toSet().length, 7);
      for (final p in aiProviders) {
        AiConfig(
          endpoint: p.endpoint,
          model: p.models.first.id,
          tokenField: p.tokenField,
        ).validate();
        expect(providerForEndpoint(p.endpoint), same(p));
        expect(Uri.parse(p.keyUrl).scheme, 'https');
        expect(Uri.parse(p.docsUrl).scheme, 'https');
      }
      expect(
        providerForEndpoint('https://custom.example/chat/completions'),
        isNull,
      );
      expect(() => catalogUri(config), returnsNormally);
      expect(
        catalogUri(
          config,
          customUrl: 'https://api.deepseek.com/account/models',
        ).path,
        '/account/models',
      );
      expect(
        () =>
            catalogUri(AiConfig(endpoint: aiProviders[3].endpoint, model: 'x')),
        throwsFormatException,
      );
      expect(
        () =>
            catalogUri(AiConfig(endpoint: aiProviders[1].endpoint, model: 'x')),
        throwsFormatException,
      );
      expect(
        () =>
            validateCatalogUri(config.endpoint, 'https://evil.example/models'),
        throwsFormatException,
      );
      expect(
        () => validateCatalogUri(
          config.endpoint,
          'http://api.deepseek.com/models',
        ),
        throwsFormatException,
      );
      expect(
        () => validateCatalogUri(
          config.endpoint,
          'https://user@api.deepseek.com/models',
        ),
        throwsFormatException,
      );
      expect(
        () => validateCatalogUri(
          config.endpoint,
          'https://api.deepseek.com:444/models',
        ),
        throwsFormatException,
      );
    },
  );
  test('GET contains authentication only; de-duplicate, recommend, filter explicit nontext', () async {
    adapter.payload = {
      'data': [
        {'id': 'z-other'},
        {'id': 'deepseek-flash'},
        {'id': 'z-other'},
        {'id': 'a-chat', 'supports_text_chat': true},
        {
          'id': 'image',
          'input_modalities': ['text'],
          'output_modalities': ['image'],
        },
        {'id': 'embed', 'supports_text_chat': false},
      ],
    };
    final result = await fetch();
    expect(result.models.map((m) => m.id), [
      'deepseek-flash',
      'a-chat',
      'z-other',
    ]);
    expect(
      result.models.first.textChat,
      isNull,
    ); // A name is not capability proof.
    expect(result.models[1].textChat, true);
    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.data, isNull);
    expect(request.queryParameters, isEmpty);
    expect(request.headers['Authorization'], 'Bearer $fakeKey');
    expect(request.followRedirects, false);
    expect(request.maxRedirects, 0);
    expect(request.connectTimeout, const Duration(seconds: 15));
    expect(request.receiveTimeout, const Duration(seconds: 30));
    expect(result.endpoint, config.endpoint);
  });
  test(
    'qwen workspace uses independent adapter and completes all pages',
    () async {
      final qwen = AiConfig(
        endpoint: 'https://workspace.cn-beijing.maas.aliyuncs.com/compatible-mode/v1/chat/completions',
        model: 'qwen3.8-flash',
      );
      adapter.respond = (options) => {
        'output': {
          'total': 3,
          'page_no': int.parse(options.uri.queryParameters['page_no']!),
          'models': options.uri.queryParameters['page_no'] == '1'
              ? [
                  {
                    'model': 'qwen3.8-flash',
                    'capabilities': ['TG'],
                  },
                  {
                    'model': 'image',
                    'inference_metadata': {
                      'response_modality': ['Image'],
                    },
                  },
                ]
              : [
                  {
                    'model': 'other',
                    'inference_metadata': {
                      'response_modality': ['Text'],
                      'request_modality': ['Text'],
                    },
                  },
                ],
        },
      };
      final result = await fetch(selected: qwen);
      expect(result.models.map((m) => m.id), ['qwen3.8-flash', 'other']);
      expect(adapter.requests.length, 2);
      expect(
        adapter.requests.first.uri.host,
        'workspace.cn-beijing.maas.aliyuncs.com',
      );
      expect(adapter.requests.first.uri.path, '/api/v1/models');
      expect(adapter.requests.first.uri.queryParameters['capabilities'], 'TG');
    },
  );
  test(
    'qwen partial, inconsistent and more than twenty pages never succeed',
    () async {
      final qwen = AiConfig(
        endpoint: 'https://workspace.cn-beijing.maas.aliyuncs.com/compatible-mode/v1/chat/completions',
        model: 'x',
      );
      adapter.respond = (o) => {
        'output': {
          'total': 21,
          'page_no': int.parse(o.uri.queryParameters['page_no']!),
          'models': [
            {'model': 'm${o.uri.queryParameters['page_no']}'},
          ],
        },
      };
      await expectLater(fetch(selected: qwen), throwsFormatException);
      expect(adapter.requests.length, 20);
      adapter.respond = (o) => {
        'output': {
          'total': 2,
          'page_no': int.parse(o.uri.queryParameters['page_no']!),
          'models': [],
        },
      };
      await expectLater(fetch(selected: qwen), throwsFormatException);
    },
  );
  for (final code in [401, 403, 404, 405, 429, 302, 500]) {
    test('HTTP $code is one request, no redirects or retries', () async {
      adapter.status = code;
      await expectLater(fetch(), throwsFormatException);
      expect(adapter.requests.length, 1);
    });
  }
  for (final payload in <Object>[
    {'data': []},
    {
      'data': [
        {'id': ''},
      ],
    },
    {
      'data': [
        {'id': 123},
      ],
    },
    {
      'data': [
        {'id': 'x'},
      ],
      'has_more': true,
    },
    {
      'data': [
        {'id': 'x'},
      ],
      'nextPageToken': 'next',
    },
    {'output': []},
    '{bad-json',
    {
      'data': List.generate(2001, (i) => {'id': 'm$i'}),
    },
  ]) {
    test(
      'invalid, empty, partial or oversized item count rejected ${payload.hashCode}',
      () async {
        adapter.payload = payload;
        await expectLater(fetch(), throwsFormatException);
      },
    );
  }
  test('response byte limit before JSON decoding', () async {
    adapter.payload = ' ' * (2 * 1024 * 1024 + 1);
    await expectLater(fetch(), throwsFormatException);
  });
  for (final type in [
    DioExceptionType.badCertificate,
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('network $type classified safely', () async {
      adapter.failure = type;
      await expectLater(fetch(), throwsFormatException);
      expect(adapter.requests.length, 1);
    });
  }
  test('total timeout cancels even a stalled body', () async {
    adapter.slowBody = true;
    client = DioAiModelCatalogClient(
      dio: Dio()..httpClientAdapter = adapter,
      totalTimeout: const Duration(milliseconds: 15),
    );
    final cancel = CancelToken();
    await expectLater(fetch(cancel: cancel), throwsFormatException);
    expect(cancel.isCancelled, true);
  });
  test('cancel in flight', () async {
    adapter.wait = Completer<void>();
    final cancel = CancelToken();
    final pending = fetch(cancel: cancel);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    cancel.cancel();
    await expectLater(pending, throwsFormatException);
  });

  test(
    'custom same-origin query uses explicit address and unknown capabilities',
    () async {
      final custom = AiConfig(
        endpoint: 'https://custom.example/text/chat',
        model: 'anything',
      );
      final address = catalogUri(
        custom,
        customUrl: 'https://custom.example/catalog',
      );
      final result = await client.fetch(
        custom,
        fakeKey,
        address,
        CancelToken(),
      );
      expect(adapter.requests.single.uri.toString(), address.toString());
      expect(result.models.single.brand, isNull);
      expect(result.models.single.textChat, isNull);
      expect(() => catalogUri(custom), throwsFormatException);
    },
  );

  group('independent encrypted cache', () {
    late Directory directory;
    late MemorySecrets secrets;
    late AiStorage storage;
    late AiCatalogResult result;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'jianzhang-model-cache-test-',
      );
      secrets = MemorySecrets();
      storage = AiStorage(secrets: secrets, directory: () async => directory);
      await storage.saveConfig(config, fakeKey);
      result = AiCatalogResult(
        endpoint: config.endpoint,
        source: catalogUri(config).toString(),
        refreshedAt: DateTime(2026, 10, 9),
        models: [const AiCatalogModel('synthetic-private-model')],
      );
    });
    tearDown(() async {
      await directory.delete(recursive: true);
    });
    test(
      'encrypted restart, same key keeps cache; other endpoint isolated',
      () async {
        expect(
          await storage.saveCatalog(result, fakeKey, storage.catalogRevision),
          true,
        );
        final file = directory.listSync().whereType<File>().single;
        final cipher = await file.readAsString();
        expect(cipher, isNot(contains('synthetic-private-model')));
        expect(cipher, isNot(contains(fakeKey)));
        await storage.saveCatalog(result, fakeKey, storage.catalogRevision);
        expect(await file.readAsString(), isNot(cipher));
        final restarted = AiStorage(
          secrets: secrets,
          directory: () async => directory,
        );
        expect(
          (await restarted.catalog(config.endpoint))!.models.single.id,
          'synthetic-private-model',
        );
        expect(await restarted.conversations(), isEmpty);
        expect(await restarted.catalog(aiProviders[5].endpoint), isNull);
        await storage.saveConfig(config, fakeKey);
        expect(await storage.catalog(config.endpoint), isNotNull);
      },
    );
    test(
      'key replacement / deletion clears cache and rejects stale response',
      () async {
        final revision = storage.catalogRevision;
        await storage.saveCatalog(result, fakeKey, revision);
        await storage.saveConfig(config, 'new-synthetic-key');
        expect(await storage.catalog(config.endpoint), isNull);
        expect(await storage.saveCatalog(result, fakeKey, revision), false);
        await storage.saveCatalog(
          result,
          'new-synthetic-key',
          storage.catalogRevision,
        );
        await storage.deleteApiKey();
        expect(await storage.catalog(config.endpoint), isNull);
        expect(
          await storage.saveCatalog(
            result,
            'new-synthetic-key',
            storage.catalogRevision,
          ),
          false,
        );
      },
    );
    test('query changes invalidate cache; consent independent; clear leaves API key', () async {
      await storage.saveCatalog(result, fakeKey, storage.catalogRevision);
      await storage.saveCatalogAddress(
        config.endpoint,
        'https://api.deepseek.com/custom-models',
      );
      expect(await storage.catalog(config.endpoint), isNull);
      expect(
        await storage.catalogAddress(config.endpoint),
        endsWith('/custom-models'),
      );
      expect(await storage.catalogAddress(aiProviders[5].endpoint), isNull);
      await storage.consentCatalog(catalogUri(config));
      expect(await storage.catalogConsented(catalogUri(config)), true);
      expect(await storage.consented(config), false);
      await storage.clear();
      expect(await storage.keyFor(config), fakeKey);
      expect(await storage.catalogConsented(catalogUri(config)), false);
    });
    test('obsolete request guard cannot replace a successful cache', () async {
      await storage.saveCatalog(result, fakeKey, storage.catalogRevision);
      final replacement = AiCatalogResult(
        endpoint: config.endpoint,
        source: result.source,
        refreshedAt: DateTime(2030),
        models: const [AiCatalogModel('obsolete')],
      );
      expect(
        await storage.saveCatalog(
          replacement,
          fakeKey,
          storage.catalogRevision,
          isCurrent: () => false,
        ),
        false,
      );
      expect(
        (await storage.catalog(config.endpoint))!.models.single.id,
        'synthetic-private-model',
      );
    });
    test(
      'corrupt cache never affects history or loses original file',
      () async {
        await storage.saveCatalog(result, fakeKey, storage.catalogRevision);
        final file = directory.listSync().whereType<File>().single;
        await file.writeAsString('corrupt synthetic file');
        await expectLater(
          storage.catalog(config.endpoint),
          throwsFormatException,
        );
        expect(await file.exists(), true);
        expect(await storage.conversations(), isEmpty);
      },
    );
  });
}
