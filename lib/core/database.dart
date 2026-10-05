import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'wechat_import.dart';

class LedgerDatabase {
  LedgerDatabase._(this.db);
  final Database db;

  static Future<LedgerDatabase> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    final selected = factory ?? databaseFactory;
    final location =
        path ?? p.join(await selected.getDatabasesPath(), 'jianzhang.db');
    final database = await selected.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createImportSources(db);
        },
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL, icon TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN (\'expense\',\'income\')), active INTEGER NOT NULL DEFAULT 1, sort_order INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE entries (id TEXT PRIMARY KEY, kind TEXT NOT NULL CHECK(kind IN (\'expense\',\'income\')), cents INTEGER NOT NULL CHECK(cents > 0), category_id TEXT NOT NULL REFERENCES categories(id), day TEXT NOT NULL, payment TEXT NOT NULL, note TEXT NOT NULL, created_at INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE INDEX entries_day ON entries(day DESC, created_at DESC)',
          );
          await db.execute(
            'CREATE INDEX entries_category_day ON entries(category_id, day)',
          );
          await db.execute(
            'CREATE TABLE budgets (month TEXT NOT NULL, category_id TEXT NOT NULL, cents INTEGER NOT NULL CHECK(cents > 0), PRIMARY KEY(month,category_id))',
          );
          await db.execute(
            'CREATE TABLE daily_notes (day TEXT PRIMARY KEY, body TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          final batch = db.batch();
          for (final category in initialCategories) {
            batch.insert('categories', category.toMap());
          }
          await batch.commit(noResult: true);
          await _createImportSources(db);
        },
      ),
    );
    return LedgerDatabase._(database);
  }

  Future<void> close() => db.close();

  static Future<void> _createImportSources(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE import_sources (entry_id TEXT PRIMARY KEY REFERENCES entries(id) ON DELETE CASCADE, source TEXT NOT NULL CHECK(source=\'wechat\'), source_key TEXT UNIQUE, fingerprint TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE INDEX import_fingerprint ON import_sources(fingerprint)',
    );
  }

  Future<List<ImportItem>> previewWechat(List<WechatRow> rows) =>
      db.transaction((txn) => _previewWechat(txn, rows));

  Future<List<ImportItem>> _previewWechat(
    DatabaseExecutor txn,
    List<WechatRow> rows,
  ) async {
    final cats = (await txn.query('categories')).map(Category.fromMap).toList();
    final sources = await txn.query('import_sources');
    final byKey = {
      for (final s in sources)
        if (s['source_key'] != null) s['source_key']: s['fingerprint'],
    };
    final fingerprints = sources.map((s) => s['fingerprint']).toSet();
    final manual = (await txn.rawQuery(
      'SELECT DISTINCT day,cents,kind FROM entries WHERE id NOT IN (SELECT entry_id FROM import_sources)',
    )).map((e) => '${e['day']}/${e['cents']}/${e['kind']}').toSet();
    final groups = <String, Set<String>>{};
    for (final row in rows) {
      if (row.sourceKey.isNotEmpty &&
          row.disposition != ImportDisposition.invalid) {
        groups.putIfAbsent(row.sourceKey, () => {}).add(row.fingerprint);
      }
    }
    final seen = <String>{};
    return rows.map((row) {
      var state = row.disposition, reason = row.reason;
      if (![
        ImportDisposition.invalid,
        ImportDisposition.excluded,
      ].contains(state)) {
        if (row.sourceKey.isNotEmpty &&
            ((groups[row.sourceKey]?.length ?? 0) > 1 ||
                (byKey.containsKey(row.sourceKey) &&
                    byKey[row.sourceKey] != row.fingerprint))) {
          state = ImportDisposition.conflict;
          reason = '同一单号内容冲突，请核对原账单；不会覆盖旧账';
        } else if (row.sourceKey.isNotEmpty &&
            (byKey.containsKey(row.sourceKey) || !seen.add(row.sourceKey))) {
          state = ImportDisposition.duplicate;
          reason = '交易单号重复，跳过';
        } else if (fingerprints.contains(row.fingerprint) ||
            manual.contains(
              '${dayKey(row.date!)}/${row.cents}/${row.kind?.name}',
            )) {
          state = ImportDisposition.review;
          reason = '与已有账单疑似重复，请确认是否仍要导入';
        }
      }
      final kind = row.kind ?? EntryKind.expense;
      return ImportItem(
        row,
        state,
        reason,
        suggestImportCategory(row, kind, cats),
      );
    }).toList();
  }

  Future<ImportResult> importWechat(List<ImportItem> items) async {
    if (items.length > importMaxRows) throw const FormatException('导入条数超限');
    return db.transaction((txn) async {
      // Recompute against the transaction snapshot, including concurrent changes.
      final current = await _previewWechat(
        txn,
        items.map((i) => i.row).toList(),
      );
      final cats = {
        for (final c in (await txn.query('categories')).map(Category.fromMap))
          c.id: c,
      };
      var inserted = 0, duplicates = 0, unselected = 0;
      final batch = txn.batch();
      for (var n = 0; n < items.length; n++) {
        final item = items[n], fresh = current[n], row = item.row;
        if (fresh.disposition == ImportDisposition.duplicate) {
          duplicates++;
          continue;
        }
        if (!item.selected) {
          unselected++;
          continue;
        }
        final category = cats[item.categoryId];
        if (fresh.blocked ||
            item.kind == null ||
            (fresh.needsConfirmation && !item.confirmed) ||
            row.date == null ||
            row.cents == null ||
            category == null ||
            !category.active ||
            category.kind != item.kind) {
          throw const FormatException('预览已变化或存在未确认账单，请重新预览；原账本未更改');
        }
        final id = newId();
        final note = row.description;
        batch.insert(
          'entries',
          LedgerEntry(
            id: id,
            kind: item.kind!,
            cents: row.cents!,
            categoryId: item.categoryId,
            date: row.date!,
            payment: '微信',
            note: note.length > 500 ? note.substring(0, 500) : note,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ).toMap(),
        );
        batch.insert('import_sources', {
          'entry_id': id,
          'source': 'wechat',
          'source_key': row.sourceKey.isEmpty ? null : row.sourceKey,
          'fingerprint': row.fingerprint,
        });
        inserted++;
      }
      await batch.commit(noResult: true);
      return ImportResult(inserted, duplicates, unselected);
    });
  }

  Future<List<Category>> categories() async => (await db.query(
    'categories',
    orderBy: 'kind,sort_order,name',
  )).map(Category.fromMap).toList();
  Future<void> saveCategory(Category category) async {
    if (category.name.trim().isEmpty ||
        category.name.length > 20 ||
        !iconKeys.contains(category.icon)) {
      throw const FormatException('请填写有效的分类名称和图标');
    }
    final old = await db.query(
      'categories',
      where: 'id=?',
      whereArgs: [category.id],
    );
    if (old.isNotEmpty && old.first['kind'] != category.kind.name) {
      throw const FormatException('已有分类不能更改收支类型');
    }
    if (old.isEmpty) {
      await db.insert('categories', category.toMap());
    } else {
      await db.update(
        'categories',
        category.toMap(),
        where: 'id=?',
        whereArgs: [category.id],
      );
    }
  }

  Future<void> saveEntry(LedgerEntry entry) async {
    if (entry.cents <= 0 ||
        entry.cents > maxCents ||
        !validDay(dayKey(entry.date)) ||
        !paymentMethods.contains(entry.payment) ||
        entry.note.length > 500) {
      throw const FormatException('请检查金额、日期或备注');
    }
    await db.transaction((txn) async {
      final categories = await txn.query(
        'categories',
        where: 'id=? AND kind=?',
        whereArgs: [entry.categoryId, entry.kind.name],
      );
      if (categories.isEmpty) throw const FormatException('分类与收支类型不匹配');
      final old = await txn.query(
        'entries',
        columns: ['id', 'category_id'],
        where: 'id=?',
        whereArgs: [entry.id],
      );
      if (categories.first['active'] != 1 &&
          (old.isEmpty || old.first['category_id'] != entry.categoryId)) {
        throw const FormatException('此分类已停用，请选择其他分类');
      }
      if (old.isEmpty) {
        await txn.insert('entries', entry.toMap());
      } else {
        await txn.update(
          'entries',
          entry.toMap(),
          where: 'id=?',
          whereArgs: [entry.id],
        );
      }
    });
  }

  Future<void> deleteEntry(String id) async =>
      db.delete('entries', where: 'id=?', whereArgs: [id]);

  (String, List<Object?>) _where(EntryFilter filter) {
    final clauses = <String>[];
    final args = <Object?>[];
    void add(String clause, Object? value) {
      clauses.add(clause);
      args.add(value);
    }

    if (filter.start != null) add('day>=?', dayKey(filter.start!));
    if (filter.end != null) add('day<?', dayKey(filter.end!));
    if (filter.kind != null) add('kind=?', filter.kind!.name);
    if (filter.categoryId != null) add('category_id=?', filter.categoryId);
    if (filter.payment != null) add('payment=?', filter.payment);
    if (filter.search.trim().isNotEmpty) {
      final escaped = filter.search
          .trim()
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      add(
        "(note LIKE ? ESCAPE '\\' OR category_id IN (SELECT id FROM categories WHERE name LIKE ? ESCAPE '\\'))",
        '%$escaped%',
      );
      args.add('%$escaped%');
    }
    return (clauses.isEmpty ? '1=1' : clauses.join(' AND '), args);
  }

  Future<List<LedgerEntry>> entries(
    EntryFilter filter, {
    int? limit = 50,
    int offset = 0,
  }) async {
    final (where, args) = _where(filter);
    return (await db.query(
      'entries',
      where: where,
      whereArgs: args,
      orderBy: 'day DESC,created_at DESC,id DESC',
      limit: limit,
      offset: offset,
    )).map(LedgerEntry.fromMap).toList();
  }

  Future<Totals> totals(EntryFilter filter) async {
    final (where, args) = _where(filter);
    final row = (await db.rawQuery(
      "SELECT COALESCE(SUM(CASE WHEN kind='income' THEN cents ELSE 0 END),0) income, COALESCE(SUM(CASE WHEN kind='expense' THEN cents ELSE 0 END),0) expense, COUNT(*) count FROM entries WHERE $where",
      args,
    )).single;
    return Totals(
      income: row['income'] as int,
      expense: row['expense'] as int,
      count: row['count'] as int,
    );
  }

  Future<List<CategoryTotal>> categoryTotals(
    PeriodWindow window,
    EntryKind kind,
  ) async {
    final rows = await db.rawQuery(
      'SELECT category_id,SUM(cents) cents,COUNT(*) count FROM entries WHERE day>=? AND day<? AND kind=? GROUP BY category_id ORDER BY cents DESC,category_id',
      [dayKey(window.start), dayKey(window.end), kind.name],
    );
    return rows
        .map(
          (r) => CategoryTotal(
            r['category_id'] as String,
            r['cents'] as int,
            r['count'] as int,
          ),
        )
        .toList();
  }

  Future<List<TrendPoint>> trend(PeriodWindow window) async {
    final byMonth = window.period == Period.year;
    final rows = await db.rawQuery(
      "SELECT substr(day,1,${byMonth ? 7 : 10}) bucket, SUM(CASE WHEN kind='income' THEN cents ELSE 0 END) income, SUM(CASE WHEN kind='expense' THEN cents ELSE 0 END) expense FROM entries WHERE day>=? AND day<? GROUP BY bucket",
      [dayKey(window.start), dayKey(window.end)],
    );
    final mapped = {for (final row in rows) row['bucket'] as String: row};
    final length = byMonth
        ? 12
        : window.period == Period.day
        ? 1
        : DateTime(window.date.year, window.date.month + 1, 0).day;
    final today = onlyDay(DateTime.now());
    // A manually entered future transaction must not disappear from its chart.
    final latestRecorded = mapped.keys.fold<DateTime>(today, (latest, key) {
      final recorded = DateTime.parse(byMonth ? '$key-01' : key);
      return recorded.isAfter(latest) ? recorded : latest;
    });
    return List.generate(length, (i) {
          final date = byMonth
              ? DateTime(window.date.year, i + 1)
              : window.period == Period.day
              ? window.start
              : DateTime(window.date.year, window.date.month, i + 1);
          return (date, mapped[byMonth ? monthKey(date) : dayKey(date)]);
        })
        .where(
          (pair) => !window.containsToday || !pair.$1.isAfter(latestRecorded),
        )
        .map(
          (pair) => TrendPoint(
            byMonth ? '${pair.$1.month}月' : '${pair.$1.day}日',
            (pair.$2?['income'] as int?) ?? 0,
            (pair.$2?['expense'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  Future<Map<String, Totals>> dailyTotals(EntryFilter filter) async {
    final (where, args) = _where(filter);
    final rows = await db.rawQuery(
      "SELECT day,SUM(CASE WHEN kind='income' THEN cents ELSE 0 END) income,SUM(CASE WHEN kind='expense' THEN cents ELSE 0 END) expense,COUNT(*) count FROM entries WHERE $where GROUP BY day",
      args,
    );
    return {
      for (final row in rows)
        row['day'] as String: Totals(
          income: row['income'] as int,
          expense: row['expense'] as int,
          count: row['count'] as int,
        ),
    };
  }

  Future<List<BudgetStatus>> budgets(DateTime month) async {
    final rows = await db.query(
      'budgets',
      where: 'month=?',
      whereArgs: [monthKey(month)],
      orderBy: 'category_id',
    );
    final window = PeriodWindow(Period.month, month);
    final totalsByCategory = await categoryTotals(window, EntryKind.expense);
    final spent = {
      for (final item in totalsByCategory) item.categoryId: item.cents,
    };
    final total = totalsByCategory.fold<int>(
      0,
      (sum, item) => sum + item.cents,
    );
    return rows.map((r) {
      final id = r['category_id'] as String;
      return BudgetStatus(
        id,
        r['cents'] as int,
        id.isEmpty ? total : spent[id] ?? 0,
      );
    }).toList();
  }

  Future<void> setBudget(DateTime date, String categoryId, int? cents) async {
    if (cents == null) {
      await db.delete(
        'budgets',
        where: 'month=? AND category_id=?',
        whereArgs: [monthKey(date), categoryId],
      );
      return;
    }
    if (cents <= 0 || cents > maxCents) throw const FormatException('预算金额无效');
    if (categoryId.isNotEmpty) {
      final rows = await db.query(
        'categories',
        where: "id=? AND kind='expense'",
        whereArgs: [categoryId],
      );
      if (rows.isEmpty) throw const FormatException('预算仅支持支出分类');
    }
    await db.insert('budgets', {
      'month': monthKey(date),
      'category_id': categoryId,
      'cents': cents,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> copyPreviousBudgets(DateTime month) =>
      db.transaction((txn) async {
        final previous = await txn.query(
          'budgets',
          where: 'month=?',
          whereArgs: [monthKey(DateTime(month.year, month.month - 1))],
        );
        int copied = 0;
        for (final budget in previous) {
          final exists = await txn.query(
            'budgets',
            where: 'month=? AND category_id=?',
            whereArgs: [monthKey(month), budget['category_id']],
          );
          if (exists.isEmpty) {
            await txn.insert('budgets', {...budget, 'month': monthKey(month)});
            copied++;
          }
        }
        return copied;
      });
  Future<String> note(DateTime date) async =>
      (await db.query(
            'daily_notes',
            where: 'day=?',
            whereArgs: [dayKey(date)],
          )).firstOrNull?['body']
          as String? ??
      '';
  Future<void> saveNote(DateTime date, String body) async {
    if (!validDay(dayKey(date)) || body.length > 2000) {
      throw const FormatException('小记内容无效');
    }
    if (body.trim().isEmpty) {
      await db.delete('daily_notes', where: 'day=?', whereArgs: [dayKey(date)]);
    } else {
      await db.insert('daily_notes', {
        'day': dayKey(date),
        'body': body.trim(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Map<String, String>> settings() async => {
    for (final row in await db.query('settings'))
      row['key'] as String: row['value'] as String,
  };
  Future<void> setSetting(String key, String value) async => db.insert(
    'settings',
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<Map<String, Object?>> exportBackup() => db.transaction(
    (txn) async => {
      'format': 'jianzhang',
      'version': 2,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'categories': await txn.query('categories'),
      'entries': await txn.query('entries'),
      'budgets': await txn.query('budgets'),
      'daily_notes': await txn.query('daily_notes'),
      'settings': await txn.query('settings'),
      'import_sources': await txn.query('import_sources'),
    },
  );
  Future<void> restore(Map<String, Object?> data) async {
    validateBackup(data);
    await db.transaction((txn) async {
      for (final table in [
        'import_sources',
        'entries',
        'budgets',
        'daily_notes',
        'settings',
        'categories',
      ]) {
        await txn.delete(table);
      }
      final batch = txn.batch();
      for (final table in [
        'categories',
        'entries',
        'budgets',
        'daily_notes',
        'settings',
      ]) {
        for (final row in (data[table] as List)) {
          batch.insert(table, Map<String, Object?>.from(row as Map));
        }
      }
      for (final row
          in (data['version'] == 2
              ? data['import_sources'] as List
              : <Object>[])) {
        batch.insert('import_sources', Map<String, Object?>.from(row as Map));
      }
      await batch.commit(noResult: true);
    });
  }
}

Map<String, Object?> decodeBackup(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) throw const FormatException('这不是有效的简账备份文件');
  final data = Map<String, Object?>.from(decoded);
  validateBackup(data);
  return data;
}

void validateBackup(Map<String, Object?> data) {
  Never fail() => throw const FormatException('备份内容不完整或格式错误，原账本未更改');
  if (data['format'] != 'jianzhang' || ![1, 2].contains(data['version'])) {
    throw const FormatException('不支持此备份格式或版本');
  }
  final fields = <String, Set<String>>{
    'categories': {'id', 'name', 'icon', 'kind', 'active', 'sort_order'},
    'entries': {
      'id',
      'kind',
      'cents',
      'category_id',
      'day',
      'payment',
      'note',
      'created_at',
    },
    'budgets': {'month', 'category_id', 'cents'},
    'daily_notes': {'day', 'body'},
    'settings': {'key', 'value'},
    if (data['version'] == 2)
      'import_sources': {'entry_id', 'source', 'source_key', 'fingerprint'},
  };
  for (final table in fields.keys) {
    if (data[table] is! List) fail();
    for (final row in data[table] as List) {
      if (row is! Map ||
          row.keys.toSet().difference(fields[table]!).isNotEmpty ||
          fields[table]!.difference(row.keys.toSet()).isNotEmpty) {
        fail();
      }
    }
  }
  final categoryKinds = <String, String>{};
  for (final raw in data['categories'] as List) {
    final row = raw as Map;
    if (row['id'] is! String ||
        (row['id'] as String).isEmpty ||
        categoryKinds.containsKey(row['id']) ||
        row['name'] is! String ||
        (row['name'] as String).trim().isEmpty ||
        (row['name'] as String).length > 20 ||
        !iconKeys.contains(row['icon']) ||
        !['expense', 'income'].contains(row['kind']) ||
        ![0, 1].contains(row['active']) ||
        row['sort_order'] is! int) {
      fail();
    }
    categoryKinds[row['id'] as String] = row['kind'] as String;
  }
  if (categoryKinds.isEmpty) fail();
  final ids = <String>{};
  bool validAmount(dynamic value) =>
      value is int && value > 0 && value <= maxCents;
  for (final raw in data['entries'] as List) {
    final row = raw as Map;
    if (row['id'] is! String ||
        (row['id'] as String).isEmpty ||
        !ids.add(row['id'] as String) ||
        !validAmount(row['cents']) ||
        !['expense', 'income'].contains(row['kind']) ||
        categoryKinds[row['category_id']] != row['kind'] ||
        row['day'] is! String ||
        !validDay(row['day'] as String) ||
        !paymentMethods.contains(row['payment']) ||
        row['note'] is! String ||
        (row['note'] as String).length > 500 ||
        row['created_at'] is! int ||
        (row['created_at'] as int) < 0) {
      fail();
    }
  }
  final budgetIds = <String>{};
  if (data['version'] == 2) {
    final sourceIds = <String>{}, keys = <String>{};
    final digest = RegExp(r'^[a-f0-9]{64}$');
    for (final raw in data['import_sources'] as List) {
      final row = raw as Map;
      if (row['entry_id'] is! String ||
          !ids.contains(row['entry_id']) ||
          !sourceIds.add(row['entry_id'] as String) ||
          row['source'] != 'wechat' ||
          row['fingerprint'] is! String ||
          !digest.hasMatch(row['fingerprint'] as String) ||
          (row['source_key'] != null &&
              (row['source_key'] is! String ||
                  !digest.hasMatch(row['source_key'] as String) ||
                  !keys.add(row['source_key'] as String)))) {
        fail();
      }
    }
  }
  for (final raw in data['budgets'] as List) {
    final row = raw as Map;
    if (row['month'] is! String ||
        !validDay('${row['month']}-01') ||
        row['category_id'] is! String ||
        (row['category_id'] != '' &&
            categoryKinds[row['category_id']] != 'expense') ||
        !validAmount(row['cents']) ||
        !budgetIds.add('${row['month']}/${row['category_id']}')) {
      fail();
    }
  }
  final noteIds = <String>{};
  for (final raw in data['daily_notes'] as List) {
    final row = raw as Map;
    if (row['day'] is! String ||
        !validDay(row['day'] as String) ||
        !noteIds.add(row['day'] as String) ||
        row['body'] is! String ||
        (row['body'] as String).length > 2000) {
      fail();
    }
  }
  final settingIds = <String>{};
  for (final raw in data['settings'] as List) {
    final row = raw as Map;
    if (row['key'] is! String ||
        !settingIds.add(row['key'] as String) ||
        row['value'] is! String) {
      fail();
    }
    if (row['key'] == 'theme' && !['light', 'dark'].contains(row['value'])) {
      fail();
    }
    if (row['key'] == 'reduced_motion' &&
        !['true', 'false'].contains(row['value'])) {
      fail();
    }
    if (!['theme', 'reduced_motion'].contains(row['key'])) fail();
  }
}

String entriesCsv(List<Map<String, Object?>> rows) {
  // Escape spreadsheet formula prefixes in user-controlled text cells.
  String cell(Object? value) {
    var text = (value ?? '').toString();
    if (RegExp(r'^\s*[=+\-@\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final lines = <String>['日期,类型,金额（元）,分类,支付方式,备注'];
  for (final row in rows) {
    lines.add(
      [
        row['day'],
        row['kind'] == 'income' ? '收入' : '支出',
        moneyInput(row['cents'] as int),
        row['category'],
        row['payment'],
        row['note'],
      ].map(cell).join(','),
    );
  }
  return '\uFEFF${lines.join('\r\n')}\r\n';
}
