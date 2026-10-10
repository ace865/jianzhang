import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jianzhang/core/controller.dart';
import 'package:jianzhang/core/database.dart';
import 'package:jianzhang/core/models.dart';
import 'package:jianzhang/ui/ledger.dart';
import 'package:jianzhang/ui/theme.dart';

import 'app_test.dart' show settle;
import 'support/test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LedgerDatabase db;
  late LedgerController controller;
  setUpAll(() async {
    sqfliteFfiInit();
    await loadTestFonts();
  });
  setUp(() async {
    db = await LedgerDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    controller = LedgerController(db);
    await controller.initialize();
  });
  tearDown(() async {
    controller.dispose();
    await db.close();
  });
  Future<void> launch(
    WidgetTester tester,
    EntryFilter filter,
    bool dark,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ledgerTheme(dark),
        home: Scaffold(
          body: LedgerScreen(controller: controller, initialFilter: filter),
        ),
      ),
    );
    await settle(tester);
  }

  for (final dark in [false, true]) {
    testWidgets('Calendar range regression dark=$dark', (tester) async {
      for (final day in [
        DateTime(2026, 3, 8),
        DateTime(2026, 11, 1),
        DateTime(2026, 2, 28),
        DateTime(2026, 12, 31),
      ]) {
        await launch(
          tester,
          EntryFilter(
            start: day,
            end: DateTime(day.year, day.month, day.day + 1),
          ),
          dark,
        );
        expect(
          find.text('${day.year}年${day.month}月${day.day}日'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('选择日期范围'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final picker = tester.widget<DateRangePickerDialog>(
          find.byType(DateRangePickerDialog),
        );
        expect(picker.initialDateRange?.start, day);
        expect(picker.initialDateRange?.end, day);
        await tester.pumpWidget(const SizedBox());
      }
      await launch(
        tester,
        EntryFilter(start: DateTime(2026, 12, 31), end: DateTime(2027, 1, 3)),
        dark,
      );
      expect(find.text('2026-12-31 — 2027-01-02'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('income day totals and actionable empty state dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(
        () => db.saveEntry(
          LedgerEntry(
            id: 'synthetic-income',
            kind: EntryKind.income,
            cents: 12345,
            categoryId: 'salary',
            date: DateTime(2026, 10, 1),
            payment: '现金',
            note: '',
            createdAt: 1,
          ),
        ),
      );
      await launch(tester, const EntryFilter(kind: EntryKind.income), dark);
      expect(find.text('收入 ¥123.45'), findsOneWidget);
      expect(find.text('支出 ¥0.00'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await launch(tester, const EntryFilter(kind: EntryKind.expense), dark);
      expect(find.text('试着调整筛选条件，或返回总览记一笔。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await launch(tester, const EntryFilter(), dark);
      expect(find.text('收入 ¥123.45 · 支出 ¥0.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
