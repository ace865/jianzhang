import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jianzhang/core/database.dart';
import 'package:jianzhang/core/models.dart';

void main() {
  late LedgerDatabase store;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    store = await LedgerDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });
  tearDown(() async => store.close());
  LedgerEntry entry(
    String id,
    int cents, {
    String date = '2026-10-04',
    EntryKind kind = EntryKind.expense,
    String? category,
    String note = '',
  }) => LedgerEntry(
    id: id,
    kind: kind,
    cents: cents,
    categoryId: category ?? (kind == EntryKind.expense ? 'food' : 'salary'),
    date: DateTime.parse(date),
    payment: '微信',
    note: note,
    createdAt: 1000,
  );

  test('decimal currency parsing never rounds or uses floating point', () {
    expect(parseMoney('0.10'), 10);
    expect(parseMoney('0.2'), 20);
    expect(parseMoney('123456789.99'), 12345678999);
    for (final value in [
      '0',
      '-1',
      '1.001',
      '1e3',
      'NaN',
      '1..2',
      '1000000000',
      '',
    ]) {
      expect(parseMoney(value), isNull, reason: value);
    }
    expect(money(100000), '¥1,000.00');
    expect(money(-1), '−¥0.01');
  });
  test(
    'empty installation has categories but no demonstration transactions',
    () async {
      expect((await store.categories()).length, 11);
      expect((await store.totals(const EntryFilter())).count, 0);
    },
  );
  test('CRUD refreshes exact totals and moves entries across month and year boundaries', () async {
    await store.saveEntry(entry('a', 10, date: '2025-12-31'));
    await store.saveEntry(entry('b', 20, date: '2026-01-01'));
    await store.saveEntry(
      entry('salary', 30000, date: '2026-01-01', kind: EntryKind.income),
    );
    final january = EntryFilter(start: DateTime(2026), end: DateTime(2026, 2));
    expect((await store.totals(january)).balance, 29980);
    await store.saveEntry(entry('a', 40, date: '2026-01-01'));
    expect((await store.totals(january)).expense, 60);
    await store.deleteEntry('b');
    expect((await store.totals(january)).expense, 40);
    expect((await store.totals(EntryFilter(end: DateTime(2026)))).count, 0);
  });
  test(
    'leap dates and year aggregation have correct local date buckets',
    () async {
      expect(validDay('2024-02-29'), isTrue);
      expect(validDay('2026-02-29'), isFalse);
      expect(validDay('2026-02-30'), isFalse);
      await store.saveEntry(entry('leap', 150, date: '2024-02-29'));
      await store.saveEntry(entry('march', 250, date: '2024-03-01'));
      final trend = await store.trend(
        PeriodWindow(Period.year, DateTime(2024)),
      );
      expect(trend.length, 12);
      expect(trend[1].expense, 150);
      expect(trend[2].expense, 250);
      final month = await store.trend(
        PeriodWindow(Period.month, DateTime(2024, 2)),
      );
      expect(month.length, 29);
      expect(month.last.expense, 150);
    },
  );
  test('literal search, type, category and payment filters agree with daily totals', () async {
    await store.saveEntry(entry('a', 100, note: '折扣 10%_优惠'));
    await store.saveEntry(entry('b', 200, note: '折扣 100元'));
    await store.saveEntry(entry('c', 300, kind: EntryKind.income));
    const filter = EntryFilter(
      search: '%_',
      kind: EntryKind.expense,
      payment: '微信',
    );
    expect((await store.entries(filter)).single.id, 'a');
    expect((await store.totals(filter)).expense, 100);
    expect((await store.dailyTotals(filter))['2026-10-04']!.expense, 100);
    expect((await store.entries(const EntryFilter(search: '餐饮'))).length, 2);
  });
  test('archiving keeps historical links and rejects new entries in inactive categories', () async {
    await store.saveEntry(entry('old', 100));
    final category = (await store.categories()).firstWhere(
      (c) => c.id == 'food',
    );
    await store.saveCategory(category.copyWith(name: '日常餐饮', active: false));
    expect(
      (await store.entries(const EntryFilter())).single.categoryId,
      'food',
    );
    await store.saveEntry(entry('old', 120, note: '更正'));
    await expectLater(
      store.saveEntry(entry('new', 200)),
      throwsFormatException,
    );
    await expectLater(
      store.saveEntry(
        entry('bad', 200, kind: EntryKind.income, category: 'food'),
      ),
      throwsFormatException,
    );
  });
  test('budget thresholds and previous month copy do not overwrite existing budgets', () async {
    await store.setBudget(DateTime(2026, 9), '', 10000);
    await store.setBudget(DateTime(2026, 9), 'food', 4000);
    await store.setBudget(DateTime(2026, 10), '', 5000);
    await store.saveEntry(entry('food', 4000));
    expect(await store.copyPreviousBudgets(DateTime(2026, 10)), 1);
    final statuses = await store.budgets(DateTime(2026, 10));
    expect(statuses.firstWhere((b) => b.categoryId == '').limit, 5000);
    expect(statuses.firstWhere((b) => b.categoryId == '').ratio, 0.8);
    expect(statuses.firstWhere((b) => b.categoryId == 'food').remaining, 0);
    await store.saveEntry(entry('extra', 100));
    expect(
      (await store.budgets(DateTime(2026, 10)))
          .firstWhere((b) => b.categoryId == 'food')
          .remaining,
      -100,
    );
  });
  test('backup roundtrip includes entries, notes, budgets, categories and appearance', () async {
    await store.saveCategory(
      const Category(
        id: 'pets',
        name: '宠物',
        icon: 'more',
        kind: EntryKind.expense,
        order: 20,
      ),
    );
    await store.saveEntry(
      entry('pet-food', 7000, category: 'pets', note: '猫粮'),
    );
    await store.setBudget(DateTime(2026, 10), 'pets', 12000);
    await store.saveNote(DateTime(2026, 10, 4), '今天陪猫玩了一会儿。');
    await store.setSetting('theme', 'dark');
    await store.setSetting('reduced_motion', 'true');
    final backup = decodeBackup(jsonEncode(await store.exportBackup()));
    await store.deleteEntry('pet-food');
    await store.setSetting('theme', 'light');
    await store.restore(backup);
    expect((await store.entries(const EntryFilter())).single.cents, 7000);
    expect(await store.note(DateTime(2026, 10, 4)), '今天陪猫玩了一会儿。');
    expect((await store.settings())['theme'], 'dark');
    expect((await store.budgets(DateTime(2026, 10))).single.limit, 12000);
    final restored = await store.exportBackup();
    restored.remove('createdAt');
    backup.remove('createdAt');
    expect(restored, equals(backup));
  });
  test('invalid backups preserve the existing ledger', () async {
    await store.saveEntry(entry('original', 42));
    final backup = await store.exportBackup();
    for (final bad in <Map<String, Object?>>[
      {...backup, 'version': 99},
      {
        ...backup,
        'entries': [
          entry('bad', 1, date: '2026-01-01').toMap()..['day'] = '2026-02-30',
        ],
      },
      {
        ...backup,
        'entries': [entry('bad', 1, category: 'missing').toMap()],
      },
      {
        ...backup,
        'entries': [entry('bad', 1).toMap(), entry('bad', 2).toMap()],
      },
      {...backup, 'categories': <Object>[]},
    ]) {
      await expectLater(store.restore(bad), throwsFormatException);
      expect((await store.entries(const EntryFilter())).single.id, 'original');
    }
  });
  test(
    'database transaction rolls back all tables on insertion failure',
    () async {
      await store.saveEntry(entry('original', 500));
      await store.saveNote(DateTime(2026, 10, 4), '保留');
      final backup = await store.exportBackup();
      await store.db.execute(
        "CREATE TRIGGER fail_test BEFORE INSERT ON entries WHEN NEW.id='blocked' BEGIN SELECT RAISE(ABORT,'test rejection'); END",
      );
      await expectLater(
        store.restore({
          ...backup,
          'entries': [entry('blocked', 700).toMap()],
        }),
        throwsA(isA<DatabaseException>()),
      );
      expect((await store.entries(const EntryFilter())).single.id, 'original');
      expect(await store.note(DateTime(2026, 10, 4)), '保留');
    },
  );
  test('ten thousand records are paginated deterministically and aggregate correctly', () async {
    final batch = store.db.batch();
    for (var i = 0; i < 10000; i++) {
      batch.insert(
        'entries',
        entry('row-${i.toString().padLeft(5, '0')}', 101).toMap(),
      );
    }
    await batch.commit(noResult: true);
    final first = await store.entries(const EntryFilter());
    final next = await store.entries(const EntryFilter(), offset: 50);
    expect(first.length, 50);
    expect(next.length, 50);
    expect({...first.map((e) => e.id), ...next.map((e) => e.id)}.length, 100);
    expect((await store.totals(const EntryFilter())).expense, 1010000);
  });
  test('CSV escapes quotes, multiline notes and spreadsheet formulas', () {
    final csv = entriesCsv([
      {
        'day': '2026-10-04',
        'kind': 'expense',
        'cents': 123,
        'category': '餐饮',
        'payment': '微信',
        'note': '=HYPERLINK("x")\n备注',
      },
    ]);
    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv, contains('"1.23"'));
    expect(csv, contains('"\'=HYPERLINK(""x"")\n备注"'));
  });
  test(
    'future entries in the current month remain visible in the trend',
    () async {
      final now = DateTime.now();
      final last = DateTime(now.year, now.month + 1, 0);
      await store.saveEntry(entry('future', 700, date: dayKey(last)));
      final points = await store.trend(PeriodWindow(Period.month, now));
      expect(points.length, last.day);
      expect(points.last.expense, 700);
    },
  );
  test('records persist when a database file is closed and reopened', () async {
    final directory = await Directory.systemTemp.createTemp(
      'jianzhang-persistence-test-',
    );
    final path = '${directory.path}/ledger.db';
    var persistent = await LedgerDatabase.open(
      path: path,
      factory: databaseFactoryFfi,
    );
    await persistent.saveEntry(entry('persist', 123));
    await persistent.close();
    persistent = await LedgerDatabase.open(
      path: path,
      factory: databaseFactoryFfi,
    );
    expect((await persistent.entries(const EntryFilter())).single.cents, 123);
    await persistent.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await directory.delete();
  });
}
