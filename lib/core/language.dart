import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef LanguageReader = Future<String?> Function();
typedef LanguageWriter = Future<void> Function(String value);

/// Device preference, deliberately separate from ledger settings and backups.
class LanguageSettings extends ChangeNotifier with WidgetsBindingObserver {
  LanguageSettings({LanguageReader? read, LanguageWriter? write})
    : _read =
          read ?? (() => const FlutterSecureStorage().read(key: storageKey)),
      _write =
          write ??
          ((value) => const FlutterSecureStorage().write(
            key: storageKey,
            value: value,
          ));

  static const storageKey = 'jianzhang.ui.language';
  static final instance = LanguageSettings();
  static const choices = ['system', 'en', 'zh-Hans', 'zh-Hant', 'ja'];
  final LanguageReader _read;
  final LanguageWriter _write;
  String choice = 'system';
  bool _saving = false;
  Future<void>? _initialization;

  Future<void> initialize() => _initialization ??= _load();
  Future<void> _load() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      final stored = await _read();
      choice = choices.contains(stored) ? stored! : 'system';
    } catch (_) {
      choice = 'system';
    }
    notifyListeners();
  }

  static Locale resolve(List<Locale> preferred) {
    for (final locale in preferred) {
      if (locale.languageCode == 'en') return const Locale('en');
      if (locale.languageCode == 'ja') return const Locale('ja');
      if (locale.languageCode == 'zh') {
        final traditional =
            locale.scriptCode == 'Hant' ||
            (locale.scriptCode != 'Hans' &&
                ['TW', 'HK', 'MO'].contains(locale.countryCode));
        return Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: traditional ? 'Hant' : 'Hans',
        );
      }
    }
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
  }

  Locale get locale => switch (choice) {
    'en' => const Locale('en'),
    'ja' => const Locale('ja'),
    'zh-Hans' => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    ),
    'zh-Hant' => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    ),
    _ => resolve(WidgetsBinding.instance.platformDispatcher.locales),
  };
  String get tag => locale.toLanguageTag();

  Future<void> select(String value) async {
    if (!choices.contains(value)) throw ArgumentError.value(value);
    if (_saving || value == choice) return;
    _saving = true;
    try {
      await _write(value);
      choice = value;
      notifyListeners();
    } finally {
      _saving = false;
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (choice == 'system') notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
