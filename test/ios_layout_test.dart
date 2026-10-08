import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jianzhang/core/controller.dart';
import 'package:jianzhang/core/database.dart';
import 'package:jianzhang/main.dart';

import 'app_test.dart' show settle;
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    sqfliteFfiInit();
    await loadTestFonts();
  });

  testWidgets('iOS themes fit safe areas, enlarged text and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 34);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = await tester.runAsync(
      () => LedgerDatabase.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      ),
    );
    final controller = LedgerController(store!);
    await tester.runAsync(controller.initialize);
    try {
      await tester.pumpWidget(LedgerApp(controller: controller));
      await settle(tester);
      for (final dark in [false, true]) {
        if (dark) await tester.runAsync(controller.toggleTheme);
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.byKey(ValueKey('nav-$i')));
          await settle(tester);
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byKey(const ValueKey('add-entry')));
        await settle(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await settle(tester);
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.tap(find.byTooltip('关闭'));
        await settle(tester);
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.runAsync(store.close);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
