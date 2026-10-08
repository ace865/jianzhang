import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jianzhang/core/database.dart';
import 'package:jianzhang/core/models.dart';
import 'package:jianzhang/core/wechat_import.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'Android-format v2 fixture survives two independent ledger restores',
    () async {
      final backup = decodeBackup(
        await File('test/fixtures/android-backup-v2.json').readAsString(),
      );
      final first = await LedgerDatabase.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      try {
        await first.restore(backup);
        final totals = await first.totals(const EntryFilter());
        expect(totals.expense, 1230);
        expect(totals.income, 999999);
        expect(totals.balance, 998769);
        expect(totals.count, 2);
        final exported = await first.exportBackup();
        for (final table in [
          'categories',
          'entries',
          'budgets',
          'daily_notes',
          'settings',
          'import_sources',
        ]) {
          expect(exported[table], unorderedEquals(backup[table] as List));
        }
        final directory = await Directory.systemTemp.createTemp(
          'jianzhang-ios-backup-',
        );
        final second = await LedgerDatabase.open(
          path: '${directory.path}/restored.db',
          factory: databaseFactoryFfi,
        );
        try {
          await second.restore(decodeBackup(jsonEncode(exported)));
          expect(await second.note(DateTime(2026, 10, 2)), '仅用于跨平台测试的虚构小记。');
          expect((await second.settings())['theme'], 'dark');
          final rows = parseWechatTable([
            wechatHeaders,
            [
              '2026-10-02 12:30:00',
              '商户消费',
              '虚构餐厅',
              '虚构午餐',
              '支出',
              '12.30',
              '零钱',
              '支付成功',
              'SYNTHETIC-IOS-ORDER',
              '/',
              '测试导入',
            ],
          ]);
          expect(
            (await second.previewWechat(rows)).single.disposition,
            ImportDisposition.duplicate,
          );
          final roundtrip = await second.exportBackup();
          for (final table in [
            'categories',
            'entries',
            'budgets',
            'daily_notes',
            'settings',
            'import_sources',
          ]) {
            expect(roundtrip[table], unorderedEquals(backup[table] as List));
          }
        } finally {
          await second.close();
          await directory.delete(recursive: true);
        }
      } finally {
        await first.close();
      }
    },
  );
}
