import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jianzhang/core/ai_service.dart';
import 'package:jianzhang/core/ai_models.dart';
import 'package:jianzhang/core/ai_snapshot.dart';
import 'package:jianzhang/core/ai_storage.dart';
import 'package:jianzhang/core/controller.dart';
import 'package:jianzhang/core/database.dart';
import 'package:jianzhang/core/models.dart';
import 'package:jianzhang/ui/ai.dart';
import 'package:jianzhang/ui/theme.dart';

import 'ai_test.dart' show MemorySecrets, FakeClient, config, fakeKey, entry;
import 'app_test.dart' show settle;

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
    await (FontLoader(
      'LedgerSerif',
    )..addFont(rootBundle.load('assets/fonts/NotoSerifSC.ttf'))).load();
    final sans = File('C:/Windows/Fonts/msyh.ttc');
    await (FontLoader('Roboto')..addFont(
          await sans.exists()
              ? Future.value(ByteData.sublistView(await sans.readAsBytes()))
              : rootBundle.load('assets/fonts/NotoSerifSC.ttf'),
        ))
        .load();
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
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
              ? AiSettingsScreen(service: service)
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
        await tester.runAsync(
          () => ledger.save(entry('updated', dayKey(DateTime.now()), 1000)),
        );
        await settle(tester);
        expect(find.text('账本已更新，本对话仍基于旧数据；可重新分析。'), findsOneWidget);
        expect(service.history.single.snapshot.data['expense'], 12345);
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
