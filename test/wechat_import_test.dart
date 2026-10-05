import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianzhang/core/controller.dart';
import 'package:jianzhang/core/database.dart';
import 'package:jianzhang/core/models.dart';
import 'package:jianzhang/core/wechat_import.dart';
import 'package:jianzhang/ui/theme.dart';
import 'package:jianzhang/ui/wechat_import.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

List<String> bill({
  String order = '420000000000000000000000000001',
  String amount = '12.30',
  String status = '支付成功',
  String type = '商户消费',
  String direction = '支出',
  String date = '2026-10-01 12:30:00',
}) => [
  date,
  type,
  '测试餐厅',
  '虚构午餐',
  direction,
  amount,
  '零钱',
  status,
  order,
  'TEST-ORDER',
  '/',
];

List<WechatRow> parsed(List<List<String>> rows) =>
    parseWechatTable([wechatHeaders, ...rows]);

// Minimal XLSX fixtures contain invented data only, no user-file dependency.
Uint8List xlsx(
  List<List<String>> rows, {
  bool date1904 = false,
  bool formula = false,
  bool numericOrder = false,
}) {
  String escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  final xml = StringBuffer(
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
  );
  for (var r = 0; r < rows.length; r++) {
    xml.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final address = '${String.fromCharCode(65 + c)}${r + 1}';
      final numeric = r > 0 && (c == 0 || c == 5 || (numericOrder && c == 8));
      xml.write(
        numeric
            ? '<c r="$address"><v>${rows[r][c]}</v></c>'
            : '<c r="$address" t="inlineStr"><is><t>${escape(rows[r][c])}</t></is>${formula && r > 0 && c == 3 ? '<f>HYPERLINK("https://invalid.test")</f>' : ''}</c>',
      );
    }
    xml.write('</row>');
  }
  xml.write('</sheetData></worksheet>');
  final zip = Archive();
  for (final item in {
    'xl/workbook.xml':
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><workbookPr date1904="${date1904 ? 1 : 0}"/></workbook>',
    'xl/worksheets/sheet1.xml': xml.toString(),
  }.entries) {
    final bytes = utf8.encode(item.value);
    zip.addFile(ArchiveFile(item.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late LedgerDatabase store;
  setUp(() async {
    store = await LedgerDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });
  tearDown(() async {
    await store.close();
  });

  test('header offsets, column order, BOM, quoted newline and text IDs', () {
    final row = bill();
    row[3] = '虚构商品,"两件"\n备注';
    final csv = const ListToCsvConverter(eol: '\n').convert([
      ['微信支付账单'],
      [],
      wechatHeaders.reversed.toList(),
      row.reversed.toList(),
      ['--------------------'],
    ]);
    final result = parseWechatCsv('\uFEFF$csv').single;
    expect(result.line, 4);
    expect(result.order, row[8]);
    expect(result.cents, 1230);
    expect(result.cells[3], row[3]);
    expect(result.disposition, ImportDisposition.ready);
  });
  test('ordinary income and all exceptional statuses', () {
    expect(
      parsed([bill(direction: '收入', status: '收款成功')]).single.kind,
      EntryKind.income,
    );
    for (final type in ['退款', '转账', '充值', '提现', '信用卡还款', '理财']) {
      expect(
        parsed([bill(type: type)]).single.disposition,
        ImportDisposition.review,
      );
    }
    for (final status in ['已全额退款', '未知状态', '已存入零钱']) {
      expect(
        parsed([bill(status: status)]).single.disposition,
        ImportDisposition.review,
      );
    }
    for (final status in ['支付失败', '交易关闭', '已撤销']) {
      expect(
        parsed([bill(status: status)]).single.disposition,
        ImportDisposition.excluded,
      );
    }
    expect(
      parsed([bill(order: '')]).single.disposition,
      ImportDisposition.review,
    );
    expect(
      parsed([bill(direction: '/')]).single.disposition,
      ImportDisposition.review,
    );
  });
  test('invalid cents and dates are never rounded or normalized', () {
    for (final amount in ['0', '-1', '1.001', '1e3', 'NaN', '9999999999', '']) {
      expect(
        parsed([bill(amount: amount)]).single.disposition,
        ImportDisposition.invalid,
      );
    }
    for (final date in ['2026-02-30', '2026-10-01 24:00:00', 'invalid']) {
      expect(
        parsed([bill(date: date)]).single.disposition,
        ImportDisposition.invalid,
      );
    }
    expect(parsed([bill(amount: '￥12.30')]).single.cents, 1230);
  });
  test('xlsx serial dates and 1904 dates preserve the same day', () async {
    final row = bill(date: '46296.5');
    final modern = await parseWechatFile(xlsx([wechatHeaders, row]), 'xlsx');
    final old = await parseWechatFile(
      xlsx([wechatHeaders, bill(date: '44834.5')], date1904: true),
      'xlsx',
    );
    expect(modern.single.date, old.single.date);
    expect(modern.single.date!.hour, 12);
    expect(modern.single.cents, 1230);
  });
  test('xlsx rejects formulas and numeric long identifiers', () async {
    final row = bill(date: '46296');
    expect(
      (await parseWechatFile(
        xlsx([wechatHeaders, row], formula: true),
        'xlsx',
      )).single.disposition,
      ImportDisposition.invalid,
    );
    expect(
      (await parseWechatFile(
        xlsx([wechatHeaders, row], numericOrder: true),
        'xlsx',
      )).single.disposition,
      ImportDisposition.invalid,
    );
  });
  test(
    'UTF8 and GB18030 decoding uses native converter without network',
    () async {
      final text = const ListToCsvConverter().convert([wechatHeaders, bill()]);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var calls = 0;
      messenger.setMockMethodCallHandler(
        const MethodChannel('charset_converter'),
        (call) async {
          expect(call.method, 'decode');
          expect(call.arguments['charset'], 'GB18030');
          calls++;
          return text;
        },
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('charset_converter'),
          null,
        ),
      );
      expect(
        (await parseWechatFile(
          Uint8List.fromList(utf8.encode(text)),
          'csv',
        )).single.cents,
        1230,
      );
      expect(calls, 0);
      expect(
        (await parseWechatFile(
          Uint8List.fromList([0xff, 0xfe]),
          'csv',
        )).single.cents,
        1230,
      );
      expect(calls, 1);
    },
  );
  test('limits and unsupported/corrupt files produce safe errors', () async {
    await expectLater(
      parseWechatFile(Uint8List(importMaxBytes + 1), 'csv'),
      throwsFormatException,
    );
    await expectLater(
      parseWechatFile(Uint8List(2), 'pdf'),
      throwsFormatException,
    );
    await expectLater(
      parseWechatFile(Uint8List(2), 'xlsx'),
      throwsFormatException,
    );
    expect(
      () => parseWechatTable([
        ['not wechat'],
      ]),
      throwsFormatException,
    );
    expect(
      () => parsed(List.generate(importMaxRows + 1, (i) => bill(order: '$i'))),
      throwsFormatException,
    );
  });
  test('overlapping imports, in-file duplicates, conflict and unchanged old entries', () async {
    final rows = parsed([bill(), bill(), bill(order: 'second')]);
    final first = await store.previewWechat(rows);
    expect(first.map((i) => i.disposition), [
      ImportDisposition.ready,
      ImportDisposition.duplicate,
      ImportDisposition.ready,
    ]);
    final result = await store.importWechat(first);
    expect(result.inserted, 2);
    expect(result.duplicates, 1);
    final repeat = await store.previewWechat(rows);
    expect(repeat.every((i) => i.blocked), isTrue);
    expect((await store.importWechat(repeat)).inserted, 0);
    expect(
      (await store.previewWechat(parsed([bill(amount: '13.00')])))
          .single
          .disposition,
      ImportDisposition.conflict,
    );
    expect((await store.totals(const EntryFilter())).expense, 2460);
    final conflict = await store.previewWechat(
      parsed([bill(order: 'new'), bill(order: 'new', amount: '14')]),
    );
    expect(
      conflict.every((i) => i.disposition == ImportDisposition.conflict),
      isTrue,
    );
  });
  test('suspected manual duplicates require explicit confirmation', () async {
    await store.saveEntry(
      LedgerEntry(
        id: 'manual',
        kind: EntryKind.expense,
        cents: 1230,
        categoryId: 'food',
        date: DateTime(2026, 10, 1),
        createdAt: 1,
      ),
    );
    final items = await store.previewWechat(parsed([bill()]));
    expect(items.single.disposition, ImportDisposition.review);
    expect(items.single.selected, isFalse);
    items.single.selected = true;
    await expectLater(store.importWechat(items), throwsFormatException);
    items.single.confirmed = true;
    expect((await store.importWechat(items)).inserted, 1);
  });
  test(
    'refund selection is explicit and does not modify original expenses',
    () async {
      final items = await store.previewWechat(parsed([bill(status: '已全额退款')]));
      expect((await store.importWechat(items)).inserted, 0);
      items.single
        ..confirmed = true
        ..selected = true
        ..kind = EntryKind.income
        ..categoryId = 'other-income';
      expect((await store.importWechat(items)).inserted, 1);
      expect((await store.totals(const EntryFilter())).income, 1230);
    },
  );
  test('transaction rechecks duplicates and category validity', () async {
    final first = await store.previewWechat(parsed([bill()]));
    final stale = await store.previewWechat(parsed([bill()]));
    await store.importWechat(first);
    expect((await store.importWechat(stale)).duplicates, 1);
    final item = await store.previewWechat(parsed([bill(order: 'third')]));
    item.single.categoryId = 'salary';
    item.single.selected = true;
    item.single.confirmed = true;
    await expectLater(store.importWechat(item), throwsFormatException);
    expect((await store.totals(const EntryFilter())).count, 1);
  });
  test(
    'entire import and source metadata roll back on database failure',
    () async {
      await store.db.execute(
        "CREATE TRIGGER reject_import BEFORE INSERT ON import_sources WHEN (SELECT count(*) FROM import_sources)>0 BEGIN SELECT RAISE(ABORT,'synthetic failure'); END",
      );
      final items = await store.previewWechat(
        parsed([bill(), bill(order: 'second')]),
      );
      await expectLater(
        store.importWechat(items),
        throwsA(isA<DatabaseException>()),
      );
      expect((await store.entries(const EntryFilter())).isEmpty, isTrue);
      expect((await store.db.query('import_sources')).isEmpty, isTrue);
    },
  );
  test(
    'v2 backup restore keeps duplicate metadata; delete cleans sources',
    () async {
      await store.importWechat(await store.previewWechat(parsed([bill()])));
      final backup = decodeBackup(jsonEncode(await store.exportBackup()));
      final id = (await store.entries(const EntryFilter())).single.id;
      await store.deleteEntry(id);
      expect((await store.db.query('import_sources')).isEmpty, isTrue);
      await store.restore(backup);
      expect(
        (await store.previewWechat(parsed([bill()]))).single.disposition,
        ImportDisposition.duplicate,
      );
      final corrupt = {
        ...backup,
        'import_sources': [
          {
            'entry_id': 'missing',
            'source': 'wechat',
            'source_key': null,
            'fingerprint': '0' * 64,
          },
        ],
      };
      await expectLater(store.restore(corrupt), throwsFormatException);
      expect((await store.totals(const EntryFilter())).count, 1);
    },
  );
  test('v1 backup restores and ignores unexpected metadata', () async {
    final backup = await store.exportBackup();
    backup['version'] = 1;
    backup['import_sources'] = [
      {'unvalidated': 'must not insert'},
    ];
    await store.restore(backup);
    expect((await store.db.query('import_sources')).isEmpty, isTrue);
  });
  test('v1 database upgrade preserves every legacy table', () async {
    final dir = await Directory.systemTemp.createTemp('jianzhang-migration-');
    final path = '${dir.path}/legacy.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1),
    );
    for (final table in [
      'entries',
      'categories',
      'budgets',
      'daily_notes',
      'settings',
    ]) {
      // Actual previous schema, supplied by the pre-migration table SQL.
      final sql =
          (await store.db.rawQuery(
                'SELECT sql FROM sqlite_master WHERE name=?',
                [table],
              )).single['sql']
              as String;
      await legacy.execute(sql);
    }
    final snapshot = await store.exportBackup();
    for (final category in snapshot['categories'] as List) {
      await legacy.insert(
        'categories',
        Map<String, Object?>.from(category as Map),
      );
    }
    await legacy.insert(
      'entries',
      LedgerEntry(
        id: 'legacy',
        kind: EntryKind.expense,
        cents: 123,
        categoryId: 'food',
        date: DateTime(2026, 10, 1),
        createdAt: 1,
      ).toMap(),
    );
    await legacy.insert('settings', {'key': 'theme', 'value': 'dark'});
    await legacy.insert('daily_notes', {'day': '2026-10-01', 'body': '虚构小记'});
    await legacy.insert('budgets', {
      'month': '2026-10',
      'category_id': '',
      'cents': 999,
    });
    await legacy.close();
    final upgraded = await LedgerDatabase.open(
      path: path,
      factory: databaseFactoryFfi,
    );
    try {
      expect((await upgraded.totals(const EntryFilter())).expense, 123);
      expect((await upgraded.settings())['theme'], 'dark');
      expect(await upgraded.note(DateTime(2026, 10, 1)), '虚构小记');
      expect((await upgraded.budgets(DateTime(2026, 10))).single.limit, 999);
      expect((await upgraded.db.query('import_sources')).isEmpty, isTrue);
    } finally {
      await upgraded.close();
    }
    // Temporary directory created above contains only test database artifacts.
    await dir.delete(recursive: true);
  });
  test(
    'large preview and import preserve exact totals and search/export',
    () async {
      final rows = parsed(
        List.generate(2000, (i) => bill(order: 'TEST-$i', amount: '1.01')),
      );
      final items = await store.previewWechat(rows);
      expect((await store.importWechat(items)).inserted, 2000);
      expect((await store.totals(const EntryFilter())).expense, 202000);
      expect(
        (await store.entries(
          const EntryFilter(search: '虚构'),
          limit: 50,
        )).length,
        50,
      );
      expect(
        (await store.dailyTotals(const EntryFilter())).values.single.expense,
        202000,
      );
      expect(
        entriesCsv(
          (await store.entries(
            const EntryFilter(),
            limit: 1,
          )).map((e) => e.toMap()).toList(),
        ),
        contains('1.01'),
      );
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'preview ${dark ? "dark" : "light"} allows cancellation and review without writes',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = LedgerController(store);
        await tester.runAsync(controller.initialize);
        final items = await tester.runAsync(
          () => store.previewWechat(
            parsed([bill(), bill(order: 'refund', status: '已全额退款')]),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ledgerTheme(dark),
            home: WechatImportScreen(
              controller: controller,
              initialItems: items,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('导入 1 笔'), findsOneWidget);
        await tester.tap(find.text('全部取消'));
        await tester.pumpAndSettle();
        expect(find.text('导入 0 笔'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final entries = await tester.runAsync(
          () => store.entries(const EntryFilter()),
        );
        expect(entries, isEmpty);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
