import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jianzhang/core/controller.dart';
import 'package:jianzhang/core/database.dart';
import 'package:jianzhang/core/models.dart';
import 'package:jianzhang/main.dart';
import 'package:jianzhang/ui/entry_editor.dart';
import 'package:jianzhang/core/wechat_import.dart';
import 'package:jianzhang/ui/wechat_import.dart';

Future<void> settle(WidgetTester tester) async {
  // SQLite runs on a real isolate, not Flutter's virtual test clock.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LedgerDatabase store;
  late LedgerController controller;
  final capture = GlobalKey();
  setUpAll(() async {
    sqfliteFfiInit();
    final serif = FontLoader('LedgerSerif')
      ..addFont(rootBundle.load('assets/fonts/NotoSerifSC.ttf'));
    await serif.load();
    // Only test rendering uses this local font; release uses Android's own sans.
    final localSans = File('C:/Windows/Fonts/msyh.ttc');
    if (await localSans.exists()) {
      final bytes = ByteData.sublistView(await localSans.readAsBytes());
      await (FontLoader('Roboto')..addFont(Future.value(bytes))).load();
    } else {
      await (FontLoader(
        'Roboto',
      )..addFont(rootBundle.load('assets/fonts/NotoSerifSC.ttf'))).load();
    }
    await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
          rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
        ))
        .load();
  });
  setUp(() async {
    store = await LedgerDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    controller = LedgerController(store);
    await controller.initialize();
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
  });

  Future<void> launch(
    WidgetTester tester, {
    Size size = const Size(400, 880),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: LedgerApp(controller: controller),
      ),
    );
    await settle(tester);
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('output/test-artifacts').create(recursive: true);
      await File('output/test-artifacts/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('empty launch, theme persistence and four tabs work', (
    tester,
  ) async {
    await launch(tester);
    expect(find.byKey(const ValueKey('overview-expense')), findsOneWidget);
    expect(find.text('¥0.00'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await settle(tester);
    expect(controller.dark, isTrue);
    final restored = LedgerController(store);
    await tester.runAsync(restored.initialize);
    expect(restored.dark, isTrue);
    restored.dispose();
    for (final i in [1, 2, 3, 0]) {
      await tester.tap(find.byKey(ValueKey('nav-$i')));
      await settle(tester);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('custom keypad saves exact amount and rejects empty amount', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('add-entry')));
    await settle(tester);
    await tester.tap(find.text('保存账单'));
    await settle(tester);
    expect(find.byType(EntryEditor), findsOneWidget);
    for (final digit in ['3', '2', '.', '5', '0']) {
      await tester.ensureVisible(find.text(digit).last);
      await tester.tap(find.text(digit).last);
      await tester.pump();
    }
    await tester.tap(find.text('保存账单'));
    await settle(tester);
    expect(find.byType(EntryEditor), findsNothing);
    final records = await tester.runAsync(
      () => store.entries(const EntryFilter()),
    );
    expect(records!.single.cents, 3250);
    expect(find.text('¥32.50'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await settle(tester);
    await tester.tap(find.text('−¥32.50'));
    await settle(tester);
    await tester.ensureVisible(find.text('8').last);
    await tester.tap(
      find.text('8').last,
    ); // Two decimal places: ignore extra input.
    await tester.tap(find.text('保存修改'));
    await settle(tester);
    final edited = await tester.runAsync(
      () => store.entries(const EntryFilter()),
    );
    expect(edited!.single.cents, 3250);
    await tester.tap(find.text('−¥32.50'));
    await settle(tester);
    await tester.tap(find.byTooltip('删除账单'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await settle(tester);
    final remaining = await tester.runAsync(
      () => store.totals(const EntryFilter()),
    );
    expect(remaining!.count, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'small phone and enlarged text do not overflow across pages and editor',
    (tester) async {
      await launch(tester, size: const Size(320, 640), scale: 1.3);
      for (final i in [1, 2, 3, 0]) {
        await tester.tap(find.byKey(ValueKey('nav-$i')));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'tab $i');
      }
      await tester.tap(find.byKey(const ValueKey('add-entry')));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'entry sheet');
      await tester.ensureVisible(find.byType(TextField));
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '小屏幕备注');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'keyboard');
      tester.view.resetViewInsets();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('budget and category management save through their dialogs', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.text('月度预算'));
    await settle(tester);
    await tester.tap(find.text('总支出预算'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '1000');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await settle(tester);
    final budgets = await tester.runAsync(() => store.budgets(DateTime.now()));
    expect(budgets!.single.limit, 100000);
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await settle(tester);
    await tester.tap(find.text('分类管理'));
    await settle(tester);
    await tester.tap(find.text('添加支出分类'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '宠物');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await settle(tester);
    expect(controller.categories.any((c) => c.name == '宠物'), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'calendar notes persist and editor navigation preserves unsaved draft',
    (tester) async {
      await launch(tester);
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await settle(tester);
      await tester.tap(find.text('日历'));
      await settle(tester);
      final day = find.text('${DateTime.now().day}').last;
      await tester.ensureVisible(day);
      await tester.tap(day);
      await settle(tester);
      final note = find.byType(TextField).last;
      await tester.enterText(note, '保留未保存的小记');
      await tester.tap(find.byTooltip('为这一天记账'));
      await settle(tester);
      await tester.tap(find.byTooltip('关闭'));
      await settle(tester);
      expect(find.text('保留未保存的小记'), findsOneWidget);
      await tester.ensureVisible(find.text('保存小记'));
      await tester.tap(find.text('保存小记'));
      await settle(tester);
      expect(
        await tester.runAsync(() => store.note(DateTime.now())),
        '保留未保存的小记',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'wechat preview, refund confirmation, import and small-font layout',
    (tester) async {
      final rows = parseWechatTable([
        wechatHeaders,
        [
          '2026-10-01 12:30:00',
          '商户消费',
          '测试餐厅',
          '虚构午餐',
          '支出',
          '12.30',
          '零钱',
          '支付成功',
          'TEST-ONE',
          'TEST-SHOP',
          '/',
        ],
        [
          '2026-10-02 13:00:00',
          '退款',
          '测试商店',
          '虚构退款',
          '收入',
          '8.50',
          '零钱',
          '退款成功',
          'TEST-TWO',
          'TEST-SHOP-2',
          '/',
        ],
      ]);
      final items = await tester.runAsync(() => store.previewWechat(rows));
      await launch(tester);
      Navigator.of(tester.element(find.byType(Scaffold).first)).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              WechatImportScreen(controller: controller, initialItems: items),
        ),
      );
      await settle(tester);
      await screenshot(tester, 'light-wechat-import');
      await tester.runAsync(controller.toggleTheme);
      await settle(tester);
      await screenshot(tester, 'dark-wechat-import');
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      await settle(tester);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(400, 880);
      tester.platformDispatcher.textScaleFactorTestValue = 1;
      await settle(tester);
      await tester.ensureVisible(find.textContaining('调整').last);
      await tester.tap(find.textContaining('调整').last);
      await settle(tester);
      expect(find.text('确认这笔交易的含义'), findsOneWidget);
      await tester.tap(find.text('确认并选入'));
      await settle(tester);
      expect(find.text('导入 2 笔'), findsOneWidget);
      await tester.tap(find.text('导入 2 笔'));
      await settle(tester);
      await tester.tap(find.text('确认导入'));
      await settle(tester);
      expect(find.textContaining('导入完成：成功 2 笔'), findsOneWidget);
      final totals = await tester.runAsync(
        () => store.totals(const EntryFilter()),
      );
      expect(totals!.expense, 1230);
      expect(totals.income, 850);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'render light and dark app previews using isolated sample ledger',
    (tester) async {
      final now = DateTime.now();
      await tester.runAsync(() async {
        final rows = [
          ('sample-salary', 850000, 'salary', EntryKind.income, '工资'),
          ('sample-food', 104650, 'food', EntryKind.expense, '日常餐饮'),
          ('sample-shop', 80000, 'shopping', EntryKind.expense, '超市购物'),
          ('sample-travel', 40000, 'transport', EntryKind.expense, '交通出行'),
          ('sample-other', 60000, 'other-expense', EntryKind.expense, '生活日用'),
        ];
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i];
          await controller.save(
            LedgerEntry(
              id: row.$1,
              cents: row.$2,
              categoryId: row.$3,
              kind: row.$4,
              date: DateTime(now.year, now.month, i + 1),
              payment: '微信',
              note: row.$5,
              createdAt: i,
            ),
          );
        }
        await controller.setBudget(now, '', 400000);
      });
      await launch(tester);
      for (final theme in ['light', 'dark']) {
        await screenshot(tester, '$theme-overview');
        for (final item in [(1, 'ledger'), (2, 'analysis'), (3, 'settings')]) {
          await tester.tap(find.byKey(ValueKey('nav-${item.$1}')));
          await settle(tester);
          await screenshot(tester, '$theme-${item.$2}');
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byKey(const ValueKey('nav-0')));
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('add-entry')));
        await settle(tester);
        await screenshot(tester, '$theme-entry');
        await tester.tap(find.byTooltip('关闭'));
        await settle(tester);
        if (theme == 'light') {
          await tester.tap(find.byKey(const ValueKey('theme-toggle')));
          await settle(tester);
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
