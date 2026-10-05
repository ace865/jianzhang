import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jianzhang/core/ai_client.dart';
import 'package:jianzhang/core/ai_models.dart';
import 'package:jianzhang/core/ai_service.dart';
import 'package:jianzhang/core/ai_snapshot.dart';
import 'package:jianzhang/core/ai_storage.dart';
import 'package:jianzhang/core/database.dart';
import 'package:jianzhang/core/models.dart';

class MemorySecrets implements AiSecrets {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FakeClient implements AiChatClient {
  int calls = 0;
  bool hold = false, fail = false, truncate = false;
  String? lastBody;
  @override
  Stream<AiEvent> send(
    AiConfig config,
    String key,
    String body,
    CancelToken cancel,
  ) async* {
    calls++;
    lastBody = body;
    yield const AiEvent(text: '虚构样本报告');
    if (hold) {
      await cancel.whenCancel;
      throw const AiFailure(AiErrorKind.cancelled);
    }
    if (fail) throw const AiFailure(AiErrorKind.network);
    yield AiEvent(done: true, truncated: truncate, tokens: 25);
  }
}

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  int calls = 0;
  RequestOptions? options;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    this.options = options;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class FailingStorage extends AiStorage {
  FailingStorage({required super.secrets, required super.directory});
  @override
  Future<void> save(AiConversation conversation) async =>
      throw const FormatException('模拟磁盘写入失败');
}

class DelayedStorage extends AiStorage {
  DelayedStorage({required super.secrets, required super.directory});
  final started = Completer<void>(), proceed = Completer<void>();
  bool delayed = false;
  @override
  Future<void> save(AiConversation conversation) async {
    if (!delayed) {
      delayed = true;
      started.complete();
      await proceed.future;
    }
    await super.save(conversation);
  }
}

const config = AiConfig(
  endpoint: 'https://example.invalid/v1/chat/completions',
  model: 'test-model',
);
const completeConfig = AiConfig(
  endpoint: 'https://example.invalid/v1/chat/completions',
  model: 'test-model',
  streaming: false,
);
const fakeKey = 'test-only-not-a-real-key';
LedgerEntry entry(
  String id,
  String day,
  int cents, {
  EntryKind kind = EntryKind.expense,
}) => LedgerEntry(
  id: id,
  kind: kind,
  cents: cents,
  categoryId: kind == EntryKind.expense ? 'food' : 'salary',
  date: DateTime.parse(day),
  payment: '微信',
  note: 'PRIVATE-NOTE-MUST-NOT-LEAK',
  createdAt: 1000,
);
Map<String, dynamic> completion({String finish = 'stop'}) => {
  'choices': [
    {
      'message': {'role': 'assistant', 'content': '样本报告'},
      'finish_reason': finish,
    },
  ],
  'usage': {'total_tokens': 12},
};
String sse() =>
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'role': 'assistant', 'content': '中文回复'},
          'finish_reason': null,
        },
      ],
    })}\r\n\r\ndata: ${jsonEncode({
      'choices': [
        {'delta': {}, 'finish_reason': 'stop'},
      ],
    })}\n\ndata: ${jsonEncode({
      'choices': [],
      'usage': {'total_tokens': 12},
    })}\n\ndata: [DONE]\n\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LedgerDatabase db;
  late Directory directory;
  late MemorySecrets secrets;
  late AiStorage storage;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await LedgerDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    directory = await Directory.systemTemp.createTemp('jianzhang-ai-test-');
    secrets = MemorySecrets();
    storage = AiStorage(secrets: secrets, directory: () async => directory);
  });
  tearDown(() async {
    await db.close();
    // Test-created, exact temporary directory only.
    await directory.delete(recursive: true);
  });
  Future<AiSnapshot> snapshot({
    Period period = Period.month,
    String date = '2026-10-05',
    String now = '2026-10-05',
  }) => readAiSnapshot(
    db,
    PeriodWindow(period, DateTime.parse(date)),
    EntryKind.expense,
    now: DateTime.parse(now),
  );

  test(
    'snapshot amounts are exact, future entries and private fields excluded',
    () async {
      await db.saveEntry(entry('PRIVATE-ID', '2026-10-01', 10));
      await db.saveEntry(entry('b', '2026-10-05', 20));
      await db.saveEntry(entry('future', '2026-10-06', 999));
      await db.saveEntry(entry('old', '2026-09-03', 15));
      await db.setBudget(DateTime(2026, 10), '', 100);
      final s = await snapshot();
      expect(s.data['expense'], 30);
      expect(s.data['end_exclusive'], '2026-10-06');
      expect(s.data['comparison']['end_exclusive'], '2026-09-06');
      expect(s.data['comparison']['change_basis_points'], 10000);
      expect(s.data['budgets'].single['spent_cents'], 30);
      for (final forbidden in [
        'PRIVATE-ID',
        'PRIVATE-NOTE',
        'payment',
        'created_at',
        'category_id',
      ]) {
        expect(s.text, isNot(contains(forbidden)));
      }
      expect((await db.exportBackup())['version'], 1);
    },
  );
  test('historical month full range, budgets only monthly', () async {
    await db.saveEntry(entry('a', '2026-09-30', 101));
    final s = await snapshot(date: '2026-09-12');
    expect(s.data['expense'], 101);
    expect(s.data['partial'], false);
    expect(s.data['comparison']['end_exclusive'], '2026-09-01');
    expect((await snapshot(period: Period.year)).data['budgets'], isEmpty);
  });
  test(
    'March 31 comparison clamps February, zero base has no percentage',
    () async {
      final s = await snapshot(date: '2026-03-31', now: '2026-03-31');
      expect(s.data['comparison']['start'], '2026-02-01');
      expect(s.data['comparison']['end_exclusive'], '2026-03-01');
      expect(s.data['comparison']['change_basis_points'], isNull);
    },
  );
  test('day and leap-year comparison use explicit calendar ranges', () async {
    final day = await snapshot(period: Period.day);
    expect(day.data['comparison']['start'], '2026-10-04');
    final year = await snapshot(
      period: Period.year,
      date: '2024-02-29',
      now: '2024-02-29',
    );
    expect(year.data['comparison']['end_exclusive'], '2023-03-02');
  });
  test(
    'empty/future snapshots unavailable and digest survives restart',
    () async {
      final s = await snapshot();
      expect(s.available, false);
      expect(AiSnapshot.fromMap(s.toMap()).digest, s.digest);
      final future = await snapshot(date: '2026-11-01');
      expect(future.available, false);
      expect(future.data['future'], true);
    },
  );
  test(
    'budget/category/data changes invalidate snapshot, note edits do not leak',
    () async {
      await db.saveEntry(entry('a', '2026-10-01', 50));
      final before = await snapshot();
      await db.setBudget(DateTime(2026, 10), '', 80);
      expect((await snapshot()).digest, isNot(before.digest));
      final budget = await snapshot();
      await db.saveCategory(
        const Category(
          id: 'food',
          name: '自定义餐饮',
          icon: 'utensils',
          kind: EntryKind.expense,
        ),
      );
      expect((await snapshot()).digest, isNot(budget.digest));
      final name = await snapshot();
      await db.saveNote(DateTime(2026, 10, 1), 'PRIVATE-DAILY-NOTE');
      expect((await snapshot()).digest, name.digest);
    },
  );
  test('config rejects cleartext URLs and credentials/query/fragment', () {
    for (final endpoint in [
      'http://example.invalid/chat',
      'https://u:p@example.invalid/chat',
      'https://example.invalid/chat?k=secret',
      'https://example.invalid/chat#x',
      'https://example.invalid',
    ]) {
      expect(
        () => AiConfig(endpoint: endpoint, model: 'm').validate(),
        throwsFormatException,
      );
    }
    config.validate();
  });
  test(
    'context uses report + six completed rounds, excludes failed answers',
    () async {
      final c = AiConversation(snapshot: await snapshot(), config: config);
      c.turns.add(
        AiTurn(
          question: 'report',
          answer: 'REPORT',
          status: AiTurnStatus.complete,
        ),
      );
      for (var i = 0; i < 9; i++) {
        c.turns.add(
          AiTurn(question: 'q$i', answer: 'a$i', status: AiTurnStatus.complete),
        );
      }
      c.turns.add(
        AiTurn(
          question: 'failed',
          answer: 'BROKEN',
          status: AiTurnStatus.failed,
        ),
      );
      final messages = aiMessages(c, 'current');
      expect(messages.length, 16);
      final text = jsonEncode(messages);
      expect(text, contains('REPORT'));
      expect(text, contains('q3'));
      expect(text, isNot(contains('q2')));
      expect(text, isNot(contains('BROKEN')));
      expect(() => aiMessages(c, 'a' * 2001), throwsFormatException);
      expect(
        () => aiRequest(config, [
          {'role': 'user', 'content': 'x' * aiRequestLimit},
        ]),
        throwsFormatException,
      );
      final request = jsonDecode(aiRequest(config, messages));
      expect(request['store'], false);
      expect(request['max_tokens'], 1536);
    },
  );
  test(
    'storage encrypted, nonce changes, pending interrupted, delete isolated',
    () async {
      final c = AiConversation(snapshot: await snapshot(), config: config);
      c.turns.add(AiTurn(question: 'PRIVATE-CHAT', answer: 'PRIVATE-ANSWER'));
      await storage.saveConfig(config, fakeKey);
      await storage.save(c);
      final file = directory.listSync().whereType<File>().single;
      final first = await file.readAsString();
      expect(first, isNot(contains('PRIVATE')));
      expect(first, isNot(contains(fakeKey)));
      await storage.save(c);
      expect(await file.readAsString(), isNot(first));
      final loaded = await storage.conversations();
      expect(loaded.single.turns.single.question, 'PRIVATE-CHAT');
      expect(loaded.single.turns.single.status, AiTurnStatus.stopped);
      await storage.delete(c.id);
      expect(await storage.conversations(), isEmpty);
      expect(await storage.keyFor(config), fakeKey);
    },
  );
  test(
    'corrupt encrypted file/missing key preserves ciphertext, clear recovers',
    () async {
      final c = AiConversation(snapshot: await snapshot(), config: config);
      await storage.save(c);
      final file = directory.listSync().whereType<File>().single;
      await secrets.delete('encryption-key');
      await expectLater(storage.conversations(), throwsFormatException);
      expect(await file.exists(), true);
      await storage.clear();
      await storage.save(c);
      await file.writeAsString('{"corrupted":true}');
      await expectLater(storage.conversations(), throwsFormatException);
      expect(await file.exists(), true);
      await storage.clear();
      expect(await storage.conversations(), isEmpty);
    },
  );
  test(
    'config key bound to endpoint; consent resets; clear keeps key',
    () async {
      await storage.saveConfig(config, fakeKey);
      await storage.consent(config);
      const other = AiConfig(
        endpoint: 'https://other.invalid/chat',
        model: 'm',
      );
      expect(await storage.keyFor(other), isNull);
      await storage.saveConfig(other, 'other-test-key');
      expect(await storage.consented(other), false);
      expect(await storage.keyFor(config), isNull);
      await storage.clear();
      expect(await storage.keyFor(other), 'other-test-key');
      await storage.deleteApiKey();
      expect(await storage.keyFor(other), isNull);
    },
  );
  test(
    'stream handles single-byte UTF8 chunks, CRLF, usage and completion',
    () async {
      final events = await parseAiSse(
        Stream.fromIterable(utf8.encode(sse()).map((b) => [b])),
      ).toList();
      expect(events.map((e) => e.text).join(), '中文回复');
      expect(events.where((e) => e.tokens != null).single.tokens, 12);
      expect(events.last.done, true);
    },
  );
  test('malformed/incomplete/tool/refusal streams rejected', () async {
    for (final source in [
      'data: nope\n\n',
      'data: [DONE]\n\n',
      sse().replaceAll('data: [DONE]\n\n', ''),
      'data: {"choices":[{"delta":{"tool_calls":[]},"finish_reason":"tool_calls"}]}\n\n',
    ]) {
      await expectLater(
        parseAiSse(Stream.value(utf8.encode(source))).toList(),
        throwsA(isA<AiFailure>()),
      );
    }
    expect(parseAiCompletion(completion(finish: 'length')).truncated, true);
    expect(() => parseAiCompletion({'choices': []}), throwsA(isA<AiFailure>()));
  });
  test('HTTP uses bound bearer, stream false, no redirects/retries', () async {
    final adapter = FakeAdapter(
      (_) async => ResponseBody.fromString(
        jsonEncode(completion()),
        200,
        headers: {
          'content-type': ['application/json'],
        },
      ),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final client = DioAiChatClient(dio: dio);
    final events = await client
        .send(
          completeConfig,
          fakeKey,
          aiRequest(completeConfig, [
            {'role': 'user', 'content': 'test'},
          ]),
          CancelToken(),
        )
        .toList();
    expect(events.single.text, '样本报告');
    expect(adapter.options!.followRedirects, false);
    expect(adapter.options!.maxRedirects, 0);
    expect(adapter.options!.headers['Authorization'], 'Bearer $fakeKey');
    expect(adapter.calls, 1);
  });
  test(
    'HTTP errors sanitized, status classes and redirect refused once',
    () async {
      for (final status in [301, 400, 401, 403, 402, 429, 500]) {
        final adapter = FakeAdapter(
          (_) async => ResponseBody.fromString('SECRET-PROMPT', status),
        );
        final client = DioAiChatClient(dio: Dio()..httpClientAdapter = adapter);
        await expectLater(
          client.send(config, fakeKey, '{}', CancelToken()).toList(),
          throwsA(
            isA<AiFailure>().having(
              (e) => e.message,
              'sanitized',
              isNot(contains('SECRET')),
            ),
          ),
        );
        expect(adapter.calls, 1);
      }
    },
  );
  test('Dio certificate failure rejected, not bypassed', () async {
    final adapter = FakeAdapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.badCertificate,
      ),
    );
    final client = DioAiChatClient(dio: Dio()..httpClientAdapter = adapter);
    await expectLater(
      client.send(config, fakeKey, '{}', CancelToken()).toList(),
      throwsA(
        isA<AiFailure>().having((e) => e.kind, 'kind', AiErrorKind.certificate),
      ),
    );
  });
  test('network idle timeout never automatically retried', () async {
    final stream = StreamController<Uint8List>();
    final adapter = FakeAdapter(
      (_) async => ResponseBody(
        stream.stream,
        200,
        headers: {
          'content-type': ['text/event-stream'],
        },
      ),
    );
    final client = DioAiChatClient(
      dio: Dio()..httpClientAdapter = adapter,
      idleTimeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      client.send(config, fakeKey, '{}', CancelToken()).toList(),
      throwsA(
        isA<AiFailure>().having((e) => e.kind, 'kind', AiErrorKind.timeout),
      ),
    );
    expect(adapter.calls, 1);
    await stream.close();
  });
  test('total timeout overrides continuous keep-alives and cancellation is immediate', () async {
    for (final stop in [false, true]) {
      final stream = StreamController<Uint8List>();
      final adapter = FakeAdapter(
        (_) async => ResponseBody(
          stream.stream,
          200,
          headers: {
            'content-type': ['text/event-stream'],
          },
        ),
      );
      final client = DioAiChatClient(
        dio: Dio()..httpClientAdapter = adapter,
        totalTimeout: const Duration(milliseconds: 50),
        idleTimeout: const Duration(seconds: 1),
      );
      final keepAlive = Timer.periodic(const Duration(milliseconds: 5), (_) {
        if (!stream.isClosed) {
          stream.add(Uint8List.fromList(utf8.encode(': keepalive\n\n')));
        }
      });
      final cancel = CancelToken();
      final stopTimer = stop
          ? Timer(const Duration(milliseconds: 15), cancel.cancel)
          : null;
      await expectLater(
        client.send(config, fakeKey, '{}', cancel).toList(),
        throwsA(
          isA<AiFailure>().having(
            (e) => e.kind,
            'kind',
            stop ? AiErrorKind.cancelled : AiErrorKind.timeout,
          ),
        ),
      );
      keepAlive.cancel();
      stopTimer?.cancel();
      await stream.close();
      expect(adapter.calls, 1);
    }
  });
  test('HTML/oversized/non-text responses are protocol failures', () async {
    for (final raw in [
      '<html>not a chat endpoint</html>',
      'x' * (2 * 1024 * 1024 + 1),
    ]) {
      final adapter = FakeAdapter(
        (_) async => ResponseBody.fromString(raw, 200),
      );
      final client = DioAiChatClient(dio: Dio()..httpClientAdapter = adapter);
      await expectLater(
        client.send(completeConfig, fakeKey, '{}', CancelToken()).toList(),
        throwsA(
          isA<AiFailure>().having((e) => e.kind, 'kind', AiErrorKind.protocol),
        ),
      );
    }
  });
  test(
    'different snapshot focus/model/prompt does not reuse cached report',
    () async {
      await db.saveEntry(entry('a', '2026-10-01', 10));
      final s = await snapshot();
      final c = AiConversation(
        snapshot: s,
        config: config,
        turns: [
          AiTurn(question: 'q', answer: 'a', status: AiTurnStatus.complete),
        ],
      );
      expect(c.matches(s, config), true);
      final income = await readAiSnapshot(
        db,
        s.window,
        EntryKind.income,
        now: DateTime(2026, 10, 5),
      );
      expect(c.matches(income, config), false);
      expect(
        c.matches(
          s,
          AiConfig(endpoint: config.endpoint, model: 'another-model'),
        ),
        false,
      );
      final old = AiConversation(
        snapshot: s,
        config: config,
        promptVersion: 0,
        turns: c.turns,
      );
      expect(old.matches(s, config), false);
    },
  );
  test(
    'ledger backup restore preserves snapshot without including AI records',
    () async {
      await db.saveEntry(entry('a', '2026-10-01', 10));
      final s = await snapshot();
      await storage.save(AiConversation(snapshot: s, config: config));
      final backup = await db.exportBackup();
      expect(jsonEncode(backup), isNot(contains('test-model')));
      await db.deleteEntry('a');
      await db.restore(backup);
      expect((await snapshot()).digest, s.digest);
    },
  );
  test(
    'storage failure before HTTP sends nothing and preserves ledger',
    () async {
      await db.saveEntry(entry('a', '2026-10-01', 10));
      final broken = FailingStorage(
        secrets: secrets,
        directory: () async => directory,
      );
      final fake = FakeClient();
      final service = AiService(db, storage: broken, client: fake);
      addTearDown(service.dispose);
      await service.initialize();
      await service.configure(config, fakeKey);
      await broken.consent(config);
      await expectLater(
        service.send(
          AiConversation(snapshot: await snapshot(), config: config),
          'report',
        ),
        throwsFormatException,
      );
      expect(fake.calls, 0);
      expect(service.busy, false);
      expect((await db.totals(const EntryFilter())).expense, 10);
    },
  );
  test(
    'service complete cache/follow-up isolates history and preserves ledger',
    () async {
      await db.saveEntry(entry('a', '2026-10-01', 10));
      final before = await db.exportBackup()
        ..remove('createdAt');
      final fake = FakeClient();
      final service = AiService(db, storage: storage, client: fake);
      addTearDown(service.dispose);
      await service.initialize();
      await service.configure(config, fakeKey);
      await storage.consent(config);
      final c = AiConversation(snapshot: await snapshot(), config: config);
      await service.send(c, 'report');
      expect(c.hasReport, true);
      expect(service.cached(c.snapshot), same(c));
      await service.send(c, 'follow');
      expect(fake.calls, 2);
      expect(fake.lastBody, contains('虚构样本报告'));
      expect(
        await db.exportBackup()
          ..remove('createdAt'),
        before,
      );
      const other = AiConfig(
        endpoint: 'https://other.invalid/chat',
        model: 'm',
      );
      await service.configure(other, fakeKey);
      await expectLater(
        service.send(c, 'must not leak'),
        throwsFormatException,
      );
      expect(fake.calls, 2);
    },
  );
  test('service failure/truncation never becomes report or cache', () async {
    await db.saveEntry(entry('a', '2026-10-01', 10));
    for (final truncate in [false, true]) {
      final fake = FakeClient()
        ..fail = !truncate
        ..truncate = truncate;
      final service = AiService(db, storage: storage, client: fake);
      await service.initialize();
      await service.configure(config, fakeKey);
      await storage.consent(config);
      final c = AiConversation(snapshot: await snapshot(), config: config);
      await service.send(c, 'report');
      expect(c.hasReport, false);
      expect(service.cached(c.snapshot), isNull);
      service.dispose();
    }
  });
  test(
    'rapid duplicate request blocked, cancellation saved without retry',
    () async {
      await db.saveEntry(entry('a', '2026-10-01', 10));
      final fake = FakeClient()..hold = true;
      final service = AiService(db, storage: storage, client: fake);
      addTearDown(service.dispose);
      await service.initialize();
      await service.configure(config, fakeKey);
      await storage.consent(config);
      final c = AiConversation(snapshot: await snapshot(), config: config);
      final first = service.send(c, 'report');
      await expectLater(service.send(c, 'duplicate'), throwsFormatException);
      while (fake.calls == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      service.stop();
      await first;
      expect(c.turns.single.status, AiTurnStatus.stopped);
      expect(fake.calls, 1);
      expect((await storage.conversations()).single.hasReport, false);
    },
  );
  test('no consent/empty/future data never calls API', () async {
    final fake = FakeClient();
    final service = AiService(db, storage: storage, client: fake);
    addTearDown(service.dispose);
    await service.initialize();
    await service.configure(config, fakeKey);
    await expectLater(
      service.send(
        AiConversation(snapshot: await snapshot(), config: config),
        'report',
      ),
      throwsFormatException,
    );
    await db.saveEntry(entry('a', '2026-10-01', 10));
    await expectLater(
      service.send(
        AiConversation(snapshot: await snapshot(), config: config),
        'report',
      ),
      throwsFormatException,
    );
    expect(fake.calls, 0);
    expect(service.busy, false);
  });
  test('stop during initial encrypted save prevents HTTP entirely', () async {
    await db.saveEntry(entry('a', '2026-10-01', 10));
    final delayed = DelayedStorage(
      secrets: secrets,
      directory: () async => directory,
    );
    final fake = FakeClient();
    final service = AiService(db, storage: delayed, client: fake);
    addTearDown(service.dispose);
    await service.initialize();
    await service.configure(config, fakeKey);
    await delayed.consent(config);
    final conversation = AiConversation(
      snapshot: await snapshot(),
      config: config,
    );
    final sending = service.send(conversation, 'report');
    await delayed.started.future;
    service.stop();
    delayed.proceed.complete();
    await sending;
    expect(fake.calls, 0);
    expect(conversation.turns.single.status, AiTurnStatus.stopped);
  });
  test(
    'independent DB1 build refuses DB2 downgrade without deleting data',
    () async {
      final path = '${directory.path}/synthetic-v2.db';
      final original = await LedgerDatabase.open(
        path: path,
        factory: databaseFactoryFfi,
      );
      await original.saveEntry(entry('retain', '2026-10-01', 10));
      await original.close();
      final upgraded = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 2, onUpgrade: (_, _, _) async {}),
      );
      await upgraded.close();
      await expectLater(
        LedgerDatabase.open(path: path, factory: databaseFactoryFfi),
        throwsFormatException,
      );
      final retained = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 2),
      );
      expect((await retained.query('entries')).single['id'], 'retain');
      await retained.close();
    },
  );
}
