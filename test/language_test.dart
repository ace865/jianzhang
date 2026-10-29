import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jianzhang/core/controller.dart';
import 'package:jianzhang/core/database.dart';
import 'package:jianzhang/core/models.dart';
import 'package:jianzhang/core/ai_models.dart';
import 'package:jianzhang/core/ai_snapshot.dart';
import 'package:jianzhang/core/ai_service.dart';
import 'package:jianzhang/core/ai_storage.dart';
import 'package:jianzhang/main.dart';
import 'package:jianzhang/l10n/localization.dart';
import 'package:jianzhang/l10n/system_messages.dart';
import 'package:jianzhang/ui/common.dart';
import 'package:jianzhang/ui/entry_editor.dart';

import 'support/test_fonts.dart';
import 'ai_test.dart' show FakeClient, MemorySecrets;

Future<void> settleLanguage(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
}

void main() {
  late LedgerDatabase testStore;
  late LedgerController testController;
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting();
    await loadTestFonts();
  });
  setUp(() async {
    testStore = await LedgerDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    testController = LedgerController(testStore);
    await testController.initialize();
    FlutterSecureStorage.setMockInitialValues({});
    LanguageSettings.instance.choice = 'zh-Hans';
  });
  tearDown(() async {
    LanguageSettings.instance.choice = 'zh-Hans';
    testController.dispose();
    await testStore.close();
  });

  test('system language resolves scripts, regions, priority and fallback', () {
    for (final region in ['TW', 'HK', 'MO']) {
      expect(
        LanguageSettings.resolve([Locale('zh', region)]).scriptCode,
        'Hant',
      );
    }
    expect(
      LanguageSettings.resolve([const Locale('zh', 'CN')]).scriptCode,
      'Hans',
    );
    expect(
      LanguageSettings.resolve([
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'TW',
        ),
      ]).scriptCode,
      'Hans',
    );
    expect(
      LanguageSettings.resolve([
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ]).scriptCode,
      'Hant',
    );
    expect(
      LanguageSettings.resolve([const Locale('fr'), const Locale('ja', 'JP')])
          .languageCode,
      'ja',
    );
    expect(
      LanguageSettings.resolve([const Locale('en', 'GB')]).languageCode,
      'en',
    );
    expect(LanguageSettings.resolve([const Locale('de')]).scriptCode, 'Hans');
  });

  test(
    'preference persists independently and read/write failures retain safety',
    () async {
      String? value;
      final first = LanguageSettings(
        read: () async => value,
        write: (v) async {
          value = v;
        },
      );
      await first.initialize();
      await first.select('ja');
      expect(value, 'ja');
      final restarted = LanguageSettings(
        read: () async => value,
        write: (v) async {
          value = v;
        },
      );
      await restarted.initialize();
      expect(restarted.choice, 'ja');
      final broken = LanguageSettings(
        read: () async => throw StateError('read'),
        write: (_) async => throw StateError('write'),
      );
      await broken.initialize();
      expect(broken.choice, 'system');
      await expectLater(broken.select('en'), throwsStateError);
      expect(broken.choice, 'system');
      await expectLater(broken.select('en'), throwsStateError);
      final invalid = LanguageSettings(
        read: () async => 'invalid',
        write: (_) async {},
      );
      await invalid.initialize();
      expect(invalid.choice, 'system');
      first.dispose();
      restarted.dispose();
      broken.dispose();
      invalid.dispose();
    },
  );

  test('four ARB catalogs have identical messages and placeholders', () {
    final maps = ['zh_Hans', 'zh_Hant', 'en', 'ja']
        .map(
          (l) =>
              jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync()) as Map,
        )
        .toList();
    final keys = maps.first.keys
        .where((k) => !(k as String).startsWith('@'))
        .toSet();
    for (final map in maps) {
      expect(
        map.keys.where((k) => !(k as String).startsWith('@')).toSet(),
        keys,
      );
      for (final key in keys) {
        final placeholders = RegExp(r'\{(p\d+)\}')
            .allMatches(map[key] as String)
            .map((m) => m[1])
            .toSet();
        final expected = RegExp(r'\{(p\d+)\}')
            .allMatches(maps.first[key] as String)
            .map((m) => m[1])
            .toSet();
        expect(placeholders, expected, reason: '$key placeholders');
      }
    }
  });

  for (final locale in ['en', 'zh-Hans', 'zh-Hant', 'ja']) {
    for (final dark in [false, true]) {
      testWidgets(
        '$locale dark=$dark settings and editor preserve data on small screen',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          LanguageSettings.instance.choice = locale;
          final store = testStore;
          final controller = testController;
          if (dark) await tester.runAsync(controller.toggleTheme);
          final entry = LedgerEntry(
            id: 'language-entry',
            kind: EntryKind.expense,
            cents: 12345,
            categoryId: 'food',
            date: DateTime(2026, 10, 28),
            payment: '微信',
            note: '私人的メモ / 原文',
            createdAt: 1,
          );
          await tester.runAsync(() => controller.save(entry));
          final before = jsonEncode(
            await tester.runAsync(
              () async => (await store.exportBackup())..remove('createdAt'),
            ),
          );
          final capture = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: LedgerApp(controller: controller),
            ),
          );
          await settleLanguage(tester);
          final l = lookupAppLocalizations(LanguageSettings.instance.locale);
          expect(find.text(l.overview), findsOneWidget);
          await tester.tap(find.text(l.settings).last);
          await settleLanguage(tester);
          expect(
            find.byKey(const ValueKey('language-selector')),
            findsOneWidget,
          );
          expect(find.text(l.language), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('output/test-artifacts/languages')
                .create(recursive: true);
            await File('output/test-artifacts/languages/$locale-$dark.png')
                .writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
          await tester.pumpWidget(
            MaterialApp(
              locale: LanguageSettings.instance.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    expect(
                      categoryLabel(context, initialCategories.first),
                      l.food,
                    );
                    expect(
                      categoryLabel(
                        context,
                        initialCategories.first.copyWith(name: '自定义食費'),
                      ),
                      '自定义食費',
                    );
                    expect(paymentLabel(context, '微信'), l.wechat);
                    expect(
                      errorText(context, StateError('SECRET')),
                      l.operationFailedPleaseRetryYourExistingData,
                    );
                    expect(
                      systemMessage(context, '模型查询失败（HTTP 429），原列表已保留。'),
                      contains('429'),
                    );
                    return EntryEditor(controller: controller, entry: entry);
                  },
                ),
              ),
            ),
          );
          await settleLanguage(tester);
          expect(find.text('私人的メモ / 原文'), findsOneWidget);
          expect(money(12345), '¥123.45');
          expect(tester.takeException(), isNull);
          expect(
            jsonEncode(
              await tester.runAsync(
                () async => (await store.exportBackup())..remove('createdAt'),
              ),
            ),
            before,
          );
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  test(
    'translated category search preserves filters, totals and renamed values',
    () async {
      final entry = LedgerEntry(
        id: 'search-food',
        kind: EntryKind.expense,
        cents: 12345,
        categoryId: 'food',
        date: DateTime(2026, 10, 28),
        payment: '微信',
        note: 'original',
        createdAt: 1,
      );
      await testController.save(entry);
      final l = lookupAppLocalizations(const Locale('en'));
      final filter = localizedSearchFilter(
        EntryFilter(search: l.food),
        testController.categories,
        l,
      );
      expect((await testStore.entries(filter)).single.id, entry.id);
      expect((await testStore.totals(filter)).expense, 12345);
      expect(
        (await testStore.dailyTotals(filter)).values.single.expense,
        12345,
      );
      final excluded = localizedSearchFilter(
        EntryFilter(search: l.food, categoryId: 'salary'),
        testController.categories,
        l,
      );
      expect(await testStore.entries(excluded), isEmpty);
      await testController.saveCategory(
        initialCategories.first.copyWith(name: 'Personal category'),
      );
      final renamed = localizedSearchFilter(
        EntryFilter(search: l.food),
        testController.categories,
        l,
      );
      expect(renamed.searchCategoryIds, isEmpty);
      expect(await testStore.entries(renamed), isEmpty);
      expect(
        (await testStore.entries(EntryFilter(search: 'Personal category')))
            .single
            .id,
        entry.id,
      );
    },
  );

  testWidgets(
    'system follows changes; manual choice preserves an open editor draft',
    (tester) async {
      LanguageSettings.instance.choice = 'system';
      tester.platformDispatcher.localesTestValue = [const Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final controller = testController;
      await tester.pumpWidget(LedgerApp(controller: controller));
      await settleLanguage(tester);
      expect(find.text('Overview'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('add-entry')));
      await settleLanguage(tester);
      // A route remains mounted when the locale changes; controller text survives.
      final fields = find.byType(TextField);
      if (fields.evaluate().isNotEmpty) {
        await tester.enterText(fields.last, 'draft stays');
      }
      await LanguageSettings.instance.select('ja');
      await settleLanguage(tester);
      expect(find.text('draft stays'), findsOneWidget);
      expect(find.text('保存する'), findsNothing);
      expect(find.text('明細を保存'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final locale in ['en', 'zh-Hans', 'zh-Hant', 'ja']) {
    testWidgets('$locale saves canonical payment and category values', (
      tester,
    ) async {
      LanguageSettings.instance.choice = locale;
      final entry = LedgerEntry(
        id: 'canonical',
        kind: EntryKind.expense,
        cents: 12345,
        categoryId: 'food',
        date: DateTime(2026, 10, 28),
        payment: '微信',
        note: 'user original',
        createdAt: 1,
      );
      await tester.runAsync(() => testController.save(entry));
      await tester.pumpWidget(
        MaterialApp(
          locale: LanguageSettings.instance.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showEntryEditor(context, testController, entry: entry),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settleLanguage(tester);
      final l = lookupAppLocalizations(LanguageSettings.instance.locale);
      await tester.ensureVisible(find.text(l.saveChanges));
      await tester.tap(find.text(l.saveChanges));
      await settleLanguage(tester);
      final stored = await tester.runAsync(
        () async => (await testStore.entries(EntryFilter())).single,
      );
      expect(stored!.payment, '微信');
      expect(stored.categoryId, 'food');
      expect(stored.note, 'user original');
      expect(stored.cents, 12345);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test(
    'restoring an old ledger backup leaves device language unchanged',
    () async {
      await LanguageSettings.instance.select('ja');
      final backup = decodeBackup(
        File('test/fixtures/android-backup-v2.json').readAsStringSync(),
      );
      await testController.restore(backup);
      expect(LanguageSettings.instance.choice, 'ja');
      final exported = await testStore.exportBackup();
      expect(
        (exported['settings'] as List).every(
          (row) => ['theme', 'reduced_motion'].contains(row['key']),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'system changes update UI while a manual choice overrides system',
    (tester) async {
      await LanguageSettings.instance.initialize();
      LanguageSettings.instance.choice = 'system';
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(LedgerApp(controller: testController));
      await settleLanguage(tester);
      expect(find.text('Overview'), findsOneWidget);
      tester.platformDispatcher.localesTestValue = [const Locale('ja')];
      await settleLanguage(tester);
      expect(find.text('ホーム'), findsOneWidget);
      await LanguageSettings.instance.select('en');
      await settleLanguage(tester);
      tester.platformDispatcher.localesTestValue = [const Locale('zh', 'TW')];
      await settleLanguage(tester);
      expect(find.text('Overview'), findsOneWidget);
      await tester.tap(find.text('Settings').last);
      await settleLanguage(tester);
      await tester.tap(find.byKey(const ValueKey('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('繁體中文').last);
      await tester.pumpAndSettle();
      expect(find.text('設定'), findsWidgets);
      final restarted = LanguageSettings();
      await restarted.initialize();
      expect(restarted.choice, 'zh-Hant');
      restarted.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'AI request language and cache are isolated without automatic network work',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'jianzhang-language-',
      );
      final client = FakeClient();
      final storage = AiStorage(
        secrets: MemorySecrets(),
        directory: () async => directory,
      );
      final service = AiService(testStore, storage: storage, client: client);
      const config = AiConfig(
        endpoint: 'https://example.com/v1/chat/completions',
        model: 'test',
      );
      await service.configure(config, 'test-only');
      await storage.consent(config);
      await testController.save(
        LedgerEntry(
          id: 'ai-lang',
          kind: EntryKind.expense,
          cents: 100,
          categoryId: 'food',
          date: DateTime(2026, 10, 1),
          payment: '微信',
          note: '',
          createdAt: 1,
        ),
      );
      final snapshot = await readAiSnapshot(
        testStore,
        PeriodWindow(Period.month, DateTime(2026, 10)),
        EntryKind.expense,
      );
      final conversation = AiConversation(
        snapshot: snapshot,
        config: config,
        language: 'en',
      );
      await service.send(conversation, 'Analyze', language: 'en');
      expect(client.calls, 1);
      expect(client.lastBody, contains('English'));
      expect(service.cached(snapshot, language: 'en'), same(conversation));
      expect(service.cached(snapshot, language: 'ja'), isNull);
      final oldAnswer = conversation.turns.first.answer;
      await LanguageSettings.instance.select('ja');
      expect(client.calls, 1);
      await service.send(conversation, 'More', language: 'ja');
      expect(client.calls, 2);
      expect(client.lastBody, contains('日本語'));
      expect(conversation.turns.first.answer, oldAnswer);
      client.hold = true;
      final running = service.send(conversation, 'Hold', language: 'en');
      for (var i = 0; i < 100 && client.calls < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final requestBody = client.lastBody;
      await LanguageSettings.instance.select('zh-Hant');
      expect(client.lastBody, requestBody);
      expect(client.calls, 3);
      service.stop();
      await running;
      final restarted = AiService(testStore, storage: storage, client: client);
      await restarted.initialize();
      expect(restarted.history.first.language, 'en');
      expect(client.calls, 3);
      service.dispose();
      restarted.dispose();
      await directory.delete(recursive: true);
    },
  );

  test('AI report language persists, isolates cache matching, and leaves old history unchanged', () {
    const config = AiConfig(
      endpoint: 'https://example.com/v1/chat/completions',
      model: 'test',
    );
    final snapshot = AiSnapshot({
      'future': false,
      'count': 1,
      'period': 'month',
      'start': '2026-10-01',
      'focus': 'expense',
    }, DateTime(2026, 10, 28));
    final conversation = AiConversation(
      snapshot: snapshot,
      config: config,
      language: 'en',
      turns: [
        AiTurn(
          question: 'report',
          answer: 'Original answer',
          status: AiTurnStatus.complete,
        ),
      ],
    );
    final oldMap = conversation.toMap()..remove('language');
    final restoredOld = AiConversation.fromMap(oldMap);
    expect(restoredOld.language, 'zh-Hans');
    expect(AiConversation.fromMap(conversation.toMap()).language, 'en');
    expect(conversation.matches(snapshot, config, language: 'en'), isTrue);
    expect(conversation.matches(snapshot, config, language: 'ja'), isFalse);
    final before = jsonEncode(conversation.toMap());
    for (final language in ['en', 'ja', 'zh-Hant', 'zh-Hans']) {
      final messages = aiMessages(
        conversation,
        'Follow up',
        language: language,
      );
      expect(
        messages[0]['content'],
        contains(switch (language) {
          'en' => 'English',
          'ja' => '日本語',
          'zh-Hant' => '繁體中文',
          _ => '简洁中文',
        }),
      );
      expect(messages.any((m) => m['content'] == 'Original answer'), isTrue);
    }
    expect(jsonEncode(conversation.toMap()), before);
  });
}
