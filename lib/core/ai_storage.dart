import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ai_models.dart';

abstract interface class AiSecrets {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformAiSecrets implements AiSecrets {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: 'jianzhang.ai.$key');
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: 'jianzhang.ai.$key', value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: 'jianzhang.ai.$key');
}

/// Independent from the ledger DB and JSON backups. Ciphertexts only on disk.
class AiStorage {
  AiStorage({AiSecrets? secrets, Future<Directory> Function()? directory})
    : secrets = secrets ?? PlatformAiSecrets(),
      _directory =
          directory ??
          (() async => Directory(
            p.join((await getApplicationSupportDirectory()).path, 'ai-records'),
          ));
  final AiSecrets secrets;
  final Future<Directory> Function() _directory;
  final _cipher = AesGcm.with256bits();
  Future<void> _queue = Future.value();

  Future<T> _locked<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<AiConfig?> config() async {
    final value = await secrets.read('config');
    if (value == null) return null;
    try {
      final config = AiConfig.fromMap(jsonDecode(value));
      config.validate();
      return config;
    } catch (_) {
      throw const FormatException('AI 配置无法读取，请重新设置；账本不受影响。');
    }
  }

  Future<String?> keyFor(AiConfig config) async {
    final raw = await secrets.read('api-key');
    if (raw == null) return null;
    final bundle = jsonDecode(raw) as Map;
    return bundle['endpoint'] == config.endpoint
        ? bundle['key'] as String
        : null;
  }

  Future<void> saveConfig(AiConfig config, String key) => _locked(() async {
    config.validate();
    if (key.trim().isEmpty ||
        RegExp(r'[\r\n]').hasMatch(key) ||
        key.length > 4096) {
      throw const FormatException('请填写有效密钥。');
    }
    // Bind key to exact endpoint. Never silently reuse a key for another host/path.
    await secrets.write(
      'api-key',
      jsonEncode({'endpoint': config.endpoint, 'key': key.trim()}),
    );
    await secrets.write('config', jsonEncode(config.toMap()));
    final consent = await secrets.read('consent');
    if (consent != config.endpoint) await secrets.delete('consent');
  });
  Future<void> deleteApiKey() => _locked(() => secrets.delete('api-key'));
  Future<bool> consented(AiConfig config) async =>
      await secrets.read('consent') == config.endpoint;
  Future<void> consent(AiConfig config) =>
      secrets.write('consent', config.endpoint);

  Future<SecretKey> _encryptionKey(Directory directory) async {
    final existing = await secrets.read('encryption-key');
    if (existing != null) return SecretKey(base64Decode(existing));
    if (directory.existsSync() &&
        directory.listSync().whereType<File>().any(
          (f) => f.path.endsWith('.aic'),
        )) {
      throw const FormatException('AI 记录加密密钥不可用。记录未删除，可清空 AI 记录后重新开始。');
    }
    final key = await _cipher.newSecretKey();
    await secrets.write(
      'encryption-key',
      base64Encode(await key.extractBytes()),
    );
    return key;
  }

  Future<List<AiConversation>> conversations() => _locked(() async {
    final directory = await _directory();
    if (!await directory.exists()) return [];
    final files = (await directory.list().toList())
        .whereType<File>()
        .where((f) => f.path.endsWith('.aic'))
        .toList();
    if (files.isEmpty) return [];
    final key = await _encryptionKey(directory);
    final result = <AiConversation>[];
    try {
      for (final file in files) {
        final encoded = jsonDecode(await file.readAsString()) as Map;
        final plaintext = await _cipher.decrypt(
          SecretBox(
            base64Decode(encoded['ciphertext']),
            nonce: base64Decode(encoded['nonce']),
            mac: Mac(base64Decode(encoded['mac'])),
          ),
          secretKey: key,
        );
        final conversation = AiConversation.fromMap(
          jsonDecode(utf8.decode(plaintext)),
        );
        for (final turn in conversation.turns) {
          if (turn.status == AiTurnStatus.running) {
            turn.status = AiTurnStatus.stopped;
            turn.error = '上次请求被中断，未自动重发。';
          }
        }
        result.add(conversation);
      }
    } catch (_) {
      throw const FormatException('AI 记录损坏或无法解密，原文件保留。可清空 AI 记录；账本不受影响。');
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  });

  Future<void> save(AiConversation conversation) => _locked(() async {
    _validateId(conversation.id);
    final directory = await _directory();
    await directory.create(recursive: true);
    final key = await _encryptionKey(directory);
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(conversation.toMap())),
      secretKey: key,
    );
    final target = File(p.join(directory.path, '${conversation.id}.aic'));
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'version': 1,
        'nonce': base64Encode(box.nonce),
        'ciphertext': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      }),
      flush: true,
    );
    await temporary.rename(target.path);
  });

  Future<void> delete(String id) => _locked(() async {
    _validateId(id);
    final directory = await _directory();
    for (final suffix in ['.aic', '.aic.tmp']) {
      final file = File(p.join(directory.path, '$id$suffix'));
      if (await file.exists()) await file.delete();
    }
  });

  Future<void> clear() => _locked(() async {
    final directory = await _directory();
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File &&
            (entity.path.endsWith('.aic') ||
                entity.path.endsWith('.aic.tmp'))) {
          await entity.delete();
        }
      }
    }
    await secrets.delete('encryption-key');
  });

  void _validateId(String id) {
    if (!RegExp(r'^[a-zA-Z0-9]{1,100}$').hasMatch(id)) {
      throw const FormatException('无效 AI 记录编号。');
    }
  }
}
