import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:jianzhang/core/ai_catalog.dart';
import 'package:jianzhang/core/ai_catalog_client.dart';
import 'package:jianzhang/ui/ai_catalog_widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jianzhang/core/ai_service.dart';
import 'package:jianzhang/core/ai_models.dart';
import 'package:jianzhang/core/ai_snapshot.dart';
import 'package:jianzhang/core/ai_storage.dart';
import 'package:jianzhang/core/controller.dart';
import 'package:jianzhang/core/database.dart';
import 'package:jianzhang/core/models.dart';
import 'package:jianzhang/core/wechat_import.dart';
import 'package:jianzhang/ui/ai.dart';
import 'package:jianzhang/ui/theme.dart';

import 'ai_test.dart' show MemorySecrets, FakeClient, config, fakeKey, entry;
import 'app_test.dart' show settle;

import 'support/test_fonts.dart';

class FakeCatalogClient implements AiModelCatalogClient {
  int calls = 0;
  Completer<void>? hold;
  bool fail = false;
  @override
  Future<AiCatalogResult> fetch(
    AiConfig config,
    String key,
    Uri address,
    CancelToken cancel,
  ) async {
    calls++;
    if (hold != null) await hold!.future;
    if (fail) throw const FormatException('样例查询失败，原列表已保留。');
    return AiCatalogResult(
      endpoint: config.endpoint,
      source: address.toString(),
      refreshedAt: DateTime(2026, 10, 9),
      models: const [AiCatalogModel('synthetic-new-model')],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LedgerDatabase db;
  late Directory directory;
  late AiService service;
  late LedgerController ledger;
  late FakeClient client;
  final capture = GlobalKey();
  setUpAll(() async {
    sqfliteFfiInit();
    await loadTestFonts();
  });
  setUp(() async {
    db = await LedgerDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    directory = await Directory.systemTemp.createTemp('jianzhang-ai-ui-');
    client = FakeClient();
    service = AiService(
      db,
      storage: AiStorage(
        secrets: MemorySecrets(),
        directory: () async => directory,
      ),
      client: client,
    );
    ledger = LedgerController(db, ai: service);
    await ledger.initialize();
    await db.saveEntry(entry('synthetic', dayKey(DateTime.now()), 12345));
  });
  tearDown(() async {
    ledger.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });
  Future<void> launch(
    WidgetTester tester, {
    bool dark = false,
    Size size = const Size(400, 880),
    double scale = 1,
    bool settings = false,
    AiModelCatalogClient? catalogClient,
    AiLinkOpener? linkOpener,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ledgerTheme(dark),
          home: settings
              ? AiSettingsScreen(
                  service: service,
                  catalogClient: catalogClient,
                  linkOpener: linkOpener ?? openAiOfficialLink,
                )
              : AiAnalysisScreen(
                  controller: ledger,
                  window: PeriodWindow(Period.month, DateTime.now()),
                  focus: EntryKind.expense,
                ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> configured() async {
    await service.initialize();
    await service.configure(config, fakeKey);
  }

  Future<void> idle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await settle(tester);
      if (!service.busy) {
        await settle(tester);
        return;
      }
    }
    fail('request did not finish');
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final image =
          await (capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('output/test-artifacts').create(recursive: true);
      await File('output/test-artifacts/$name')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('unconfigured analysis navigates to settings without network', (
    tester,
  ) async {
    await launch(tester);
    await tap(tester, '生成分析');
    expect(find.text('完整 HTTPS 聊天端点'), findsOneWidget);
    expect(client.calls, 0);
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'provider presets $dark, model search and official link fallback offline',
      (tester) async {
        await tester.runAsync(
          () => service.configure(
            AiConfig(
              endpoint: aiProviders[0].endpoint,
              model: 'deepseek-flash',
            ),
            fakeKey,
          ),
        );
        final catalog = FakeCatalogClient();
        await launch(
          tester,
          settings: true,
          dark: dark,
          catalogClient: catalog,
          linkOpener: (_) async => false,
        );
        await screenshot(
          tester,
          dark ? 'dark-ai-providers.png' : 'light-ai-providers.png',
        );
        await tap(tester, '选择模型');
        await tester.enterText(
          find.widgetWithText(TextField, '搜索模型名称或 ID'),
          'v4',
        );
        await settle(tester);
        expect(find.text('DeepSeek V4 Pro'), findsOneWidget);
        await tap(tester, 'DeepSeek V4 Pro');
        expect(service.config!.model, 'deepseek-flash'); // Draft only.
        await tap(tester, '刷新模型列表');
        expect(find.text('表单有未保存修改，请先保存配置后刷新。'), findsOneWidget);
        expect(catalog.calls, 0);
        expect(client.calls, 0);
        await tap(tester, '获取 API 密钥');
        expect(find.text('无法打开系统浏览器'), findsOneWidget);
        expect(
          find.textContaining('https://platform.deepseek.com/api_keys'),
          findsOneWidget,
        );
        await tap(tester, '复制链接');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'manual refresh preserves current model, failure cache and blocks stale response',
    (tester) async {
      final selected = AiConfig(
        endpoint: aiProviders[0].endpoint,
        model: 'deepseek-flash',
      );
      await tester.runAsync(() => service.configure(selected, fakeKey));
      final catalog = FakeCatalogClient();
      await launch(tester, settings: true, catalogClient: catalog);
      await tap(tester, '刷新模型列表');
      expect(find.text('查询模型列表？'), findsOneWidget);
      expect(catalog.calls, 0);
      await tap(tester, '确认查询');
      expect(catalog.calls, 1);
      expect(service.config!.model, selected.model);
      expect(find.text('当前列表未包含此模型，请核对权限或选择其他模型'), findsOneWidget);
      final first = await tester.runAsync(
        () => service.storage.catalog(selected.endpoint),
      );
      catalog.fail = true;
      await tap(tester, '刷新模型列表');
      expect(catalog.calls, 2);
      expect(find.text('样例查询失败，原列表已保留。'), findsOneWidget);
      expect(
        (await tester.runAsync(
          () => service.storage.catalog(selected.endpoint),
        ))!.refreshedAt,
        first!.refreshedAt,
      );
      catalog.fail = false;
      catalog.hold = Completer<void>();
      await tap(tester, '刷新模型列表');
      expect(catalog.calls, 3);
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await settle(tester);
      await tester.ensureVisible(
        find.widgetWithText(TextField, '完整 HTTPS 聊天端点'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, '完整 HTTPS 聊天端点'),
        'https://custom.invalid/chat',
      );
      catalog.hold!.complete();
      await settle(tester);
      expect(find.textContaining('上次成功刷新'), findsNothing);
      expect(client.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('model picker long names, keyboard and large font at 320 width', (
    tester,
  ) async {
    await tester.runAsync(
      () => service.configure(
        AiConfig(endpoint: aiProviders[0].endpoint, model: 'deepseek-flash'),
        fakeKey,
      ),
    );
    await launch(
      tester,
      settings: true,
      size: const Size(320, 640),
      scale: 1.8,
      dark: true,
    );
    await tap(tester, '选择模型');
    await screenshot(tester, 'small-ai-model-picker.png');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(find.widgetWithText(TextField, '搜索模型名称或 ID'), '不存在');
    await settle(tester);
    expect(find.text('没有匹配模型，仍可在设置页手动填写。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'theme $dark preview cancel, report, follow-up and history deletion',
      (tester) async {
        await tester.runAsync(configured);
        await launch(tester, dark: dark);
        await tap(tester, '生成分析');
        expect(find.text('查看实际发送内容'), findsOneWidget);
        await tap(tester, '取消');
        expect(client.calls, 0);
        expect(service.history, isEmpty);
        await tap(tester, '生成分析');
        await tap(tester, '确认并发送');
        await idle(tester);
        expect(client.calls, 1);
        expect(service.history.single.hasReport, true);
        await screenshot(
          tester,
          dark ? 'dark-ai-analysis.png' : 'light-ai-analysis.png',
        );
        await tester.runAsync(() async {
          final rows = parseWechatTable([
            wechatHeaders,
            [
              '${dayKey(DateTime.now())} 12:00:00',
              '商户消费',
              'PRIVATE-MERCHANT',
              'PRIVATE-PRODUCT',
              '支出',
              '10.00',
              '零钱',
              '支付成功',
              'PRIVATE-ORDER',
              '/',
              'PRIVATE-IMPORT-NOTE',
            ],
          ]);
          await ledger.importWechat(await db.previewWechat(rows));
        });
        await settle(tester);
        expect(find.text('账本已更新，本对话仍基于旧数据；可重新分析。'), findsOneWidget);
        expect(service.history.single.snapshot.data['expense'], 12345);
        expect(client.lastBody, isNot(contains('PRIVATE-MERCHANT')));
        expect(client.lastBody, isNot(contains('PRIVATE-ORDER')));
        await tester.enterText(find.byType(TextField), '怎样调整预算？');
        await tap(tester, '预览并发送');
        await tap(tester, '确认并发送');
        await idle(tester);
        expect(client.calls, 2);
        expect(service.history.single.turns.length, 2);
        await tester.tap(find.byTooltip('历史'));
        await settle(tester);
        await tester.tap(find.byTooltip('删除对话'));
        await settle(tester);
        await tap(tester, '删除');
        expect(service.history, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('small screen and enlarged font fit analysis and settings', (
    tester,
  ) async {
    await tester.runAsync(configured);
    await tester.runAsync(() async {
      await service.storage.consent(config);
      final snapshot = await readAiSnapshot(
        db,
        PeriodWindow(Period.month, DateTime.now()),
        EntryKind.expense,
      );
      await service.send(
        AiConversation(snapshot: snapshot, config: config),
        '样本报告',
      );
    });
    await launch(tester, size: const Size(320, 640), scale: 1.8);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), '测试键盘布局');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await settle(tester);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await launch(
      tester,
      settings: true,
      size: const Size(320, 640),
      scale: 1.8,
      dark: true,
    );
    expect(tester.takeException(), isNull);
    await screenshot(tester, 'small-ai-settings.png');
  });
  testWidgets('stream stop leaves partial reply out of context', (
    tester,
  ) async {
    await tester.runAsync(configured);
    client.hold = true;
    await launch(tester);
    await tap(tester, '生成分析');
    await tap(tester, '确认并发送');
    expect(client.calls, 1);
    await tap(tester, '停止生成');
    await idle(tester);
    expect(service.history.single.hasReport, false);
    expect(service.busy, false);
    expect(find.text('继续追问'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'settings shows saved token field, preserves endpoint key and refuses cross-host reuse',
    (tester) async {
      await tester.runAsync(() async {
        await service.initialize();
        await service.configure(
          AiConfig(
            endpoint: config.endpoint,
            model: config.model,
            tokenField: 'max_completion_tokens',
          ),
          fakeKey,
        );
      });
      await launch(tester, settings: true);
      expect(find.text('max_completion_tokens'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'changed-model');
      await tap(tester, '保存配置');
      expect(service.config!.model, 'changed-model');
      expect(
        await tester.runAsync(() => service.storage.keyFor(service.config!)),
        fakeKey,
      );
      await tester.enterText(
        find.byType(TextField).at(0),
        'https://another.invalid/chat',
      );
      await tap(tester, '保存配置');
      expect(find.text('新服务地址需要重新填写密钥，不会沿用其他地址的密钥。'), findsOneWidget);
      expect(service.config!.endpoint, config.endpoint);
      expect(client.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
