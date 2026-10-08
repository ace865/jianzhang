import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jianzhang/core/controller.dart';
import 'package:jianzhang/core/database.dart';
import 'package:jianzhang/core/models.dart';

void main() {
  late LedgerDatabase store;
  late LedgerController controller;
  setUpAll(sqfliteFfiInit);
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

  test('busy operations keep guards and import notification order', () async {
    final entered = Completer<void>(), release = Completer<void>();
    final holding = store.db.transaction((_) async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final states = <(bool, int)>[];
    controller.addListener(() {
      states.add((controller.busy, controller.revision));
    });
    final importing = controller.importWechat([]);
    try {
      expect(controller.busy, isTrue);
      await expectLater(controller.importWechat([]), throwsFormatException);
      expect(await controller.backup(), isFalse);
      expect(await controller.pickBackup(), isNull);
      expect(await controller.exportCsv(const EntryFilter()), isFalse);
      await controller.restore({});
      expect(states, [(true, 0)]);
    } finally {
      release.complete();
      await holding;
      await importing;
    }
    expect(states, [(true, 0), (true, 1), (false, 1)]);
  });

  test('failed restore clears busy without incrementing revision', () async {
    final states = <bool>[];
    controller.addListener(() => states.add(controller.busy));
    await expectLater(controller.restore({}), throwsFormatException);
    expect(states, [true, false]);
    expect(controller.revision, 0);
    expect((await controller.importWechat([])).inserted, 0);
    expect(controller.busy, isFalse);
  });
}
