import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier, compute;

import 'database.dart';
import 'ai_service.dart';
import 'models.dart';

class LedgerController extends ChangeNotifier {
  LedgerController(this.store, {this._ai});
  final LedgerDatabase store;
  AiService? _ai;
  AiService get ai => _ai ??= AiService(store);
  @override
  void dispose() {
    _ai?.dispose();
    super.dispose();
  }

  List<Category> categories = [];
  bool dark = false;
  bool reducedMotion = false;
  int revision = 0;
  bool _busy = false;
  bool _themeSaving = false;
  bool get busy => _busy;

  Future<void> initialize() async {
    categories = await store.categories();
    final settings = await store.settings();
    dark = settings['theme'] == 'dark';
    reducedMotion = settings['reduced_motion'] == 'true';
  }

  Category category(String id) => categories.firstWhere(
    (c) => c.id == id,
    orElse: () =>
        Category(id: id, name: '其他', icon: 'more', kind: EntryKind.expense),
  );
  List<Category> forKind(EntryKind kind, {String? include}) => categories
      .where((c) => c.kind == kind && (c.active || c.id == include))
      .toList();
  Future<void> toggleTheme() async {
    if (_themeSaving || _busy) return;
    _themeSaving = true;
    try {
      final next = !dark;
      await store.setSetting('theme', next ? 'dark' : 'light');
      dark = next;
      notifyListeners();
    } finally {
      _themeSaving = false;
    }
  }

  Future<void> setReducedMotion(bool value) async {
    await store.setSetting('reduced_motion', value.toString());
    reducedMotion = value;
    notifyListeners();
  }

  Future<void> refresh() async {
    categories = await store.categories();
    revision++;
    notifyListeners();
  }

  Future<void> save(LedgerEntry entry) async {
    await store.saveEntry(entry);
    await refresh();
  }

  Future<void> delete(String id) async {
    await store.deleteEntry(id);
    await refresh();
  }

  Future<void> saveCategory(Category value) async {
    await store.saveCategory(value);
    await refresh();
  }

  Future<void> saveNote(DateTime date, String body) async {
    await store.saveNote(date, body);
    await refresh();
  }

  Future<void> setBudget(DateTime month, String category, int? cents) async {
    await store.setBudget(month, category, cents);
    await refresh();
  }

  Future<int> copyBudgets(DateTime month) async {
    final count = await store.copyPreviousBudgets(month);
    await refresh();
    return count;
  }

  Future<bool> backup() async {
    if (_busy) return false;
    _busy = true;
    notifyListeners();
    try {
      final data = await store.exportBackup();
      final encoded = await compute(_encode, data);
      final path = await FilePicker.saveFile(
        dialogTitle: '保存完整备份',
        fileName: '简账备份-${dayKey(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: encoded,
        mimeType: 'application/json',
      );
      return path != null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<Map<String, Object?>?> pickBackup() async {
    if (_busy) return null;
    _busy = true;
    notifyListeners();
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return null;
      const maxBytes = 50 * 1024 * 1024;
      if ((await file.length() ?? 0) > maxBytes) {
        throw const FormatException('备份文件超过 50 MB，暂不支持恢复');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('备份文件超过 50 MB，暂不支持恢复');
        }
        bytes.add(chunk);
      }
      return await compute(_decode, bytes.takeBytes());
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> restore(Map<String, Object?> data) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await store.restore(data);
      await initialize();
      revision++;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> exportCsv(EntryFilter filter) async {
    if (_busy) return false;
    _busy = true;
    notifyListeners();
    try {
      final entries = await store.entries(filter, limit: null);
      final rows = entries
          .map(
            (entry) => {
              ...entry.toMap(),
              'category': category(entry.categoryId).name,
            },
          )
          .toList();
      final text = await compute(entriesCsv, rows);
      return await FilePicker.saveFile(
            dialogTitle: '导出账单',
            fileName: '简账账单-${dayKey(DateTime.now())}.csv',
            type: FileType.custom,
            allowedExtensions: ['csv'],
            bytes: Uint8List.fromList(utf8.encode(text)),
            mimeType: 'text/csv',
          ) !=
          null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

Uint8List _encode(Map<String, Object?> data) =>
    Uint8List.fromList(utf8.encode(jsonEncode(data)));

Map<String, Object?> _decode(Uint8List bytes) =>
    decodeBackup(utf8.decode(bytes));
