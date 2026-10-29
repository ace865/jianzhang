import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jianzhang/core/language.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  // Existing visual/regression fixtures were authored in Simplified Chinese.
  // Language tests explicitly set system/manual choices for every scenario.
  LanguageSettings.instance.choice = 'zh-Hans';
  await testMain();
}
