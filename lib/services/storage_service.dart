import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 统一存储服务
///
/// - SharedPreferences：用于轻量配置（key-value 形式）
/// - 文件：用于结构化 JSON 数据（带原子写 + 备份）
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  SharedPreferences? _prefs;
  Future<SharedPreferences>? _prefsInit;
  Directory? _testDirectory;
  final Map<String, Future<void>> _writeChains = {};

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefsInit ??= SharedPreferences.getInstance();
    _prefs = await _prefsInit;
    return _prefs!;
  }

  /// 读取 String 配置项
  Future<String?> getString(String key) async => (await prefs).getString(key);

  /// 写入 String 配置项
  Future<bool> setString(String key, String value) async =>
      (await prefs).setString(key, value);

  /// 读取 int 配置项
  Future<int?> getInt(String key) async => (await prefs).getInt(key);

  /// 写入 int 配置项
  Future<bool> setInt(String key, int value) async =>
      (await prefs).setInt(key, value);

  /// 读取 bool 配置项
  Future<bool?> getBool(String key) async => (await prefs).getBool(key);

  /// 写入 bool 配置项
  Future<bool> setBool(String key, bool value) async =>
      (await prefs).setBool(key, value);

  /// 读取带 schema 版本号的 JSON 数据
  ///
  /// [decode] 应返回 T?（null 表示无法解析 / 版本不匹配）
  Future<T?> readJsonFile<T>({
    required String fileName,
    required int currentSchemaVersion,
    required T? Function(dynamic raw, int schemaVersion) decode,
  }) async {
    try {
      final file = await _file(fileName);
      final backup = File('${file.path}.bak');
      final source = await file.exists()
          ? file
          : await backup.exists()
          ? backup
          : null;
      if (source == null) return null;
      String content;
      try {
        content = await source.readAsString();
      } catch (_) {
        if (source.path == backup.path || !await backup.exists()) rethrow;
        content = await backup.readAsString();
      }
      if (content.isEmpty) return null;
      dynamic data;
      try {
        data = jsonDecode(content);
      } catch (_) {
        if (source.path == backup.path || !await backup.exists()) rethrow;
        data = jsonDecode(await backup.readAsString());
      }
      if (data is! Map<String, dynamic>) return null;
      final v = (data['_v'] as int?) ?? 0;
      if (v > currentSchemaVersion) return null; // 未来版本
      final raw = data['data'];
      return decode(raw, v);
    } catch (e) {
      debugPrint('StorageService.readJsonFile($fileName) 失败: $e');
      return null;
    }
  }

  /// 原子写 JSON 文件（写到临时文件再 rename，避免半写状态）
  Future<void> writeJsonFile({
    required String fileName,
    required int currentSchemaVersion,
    required dynamic Function() encode,
  }) async {
    final previous = _writeChains[fileName] ?? Future<void>.value();
    late final Future<void> next;
    next = previous.then(
      (_) => _writeJsonFileOnce(
        fileName: fileName,
        currentSchemaVersion: currentSchemaVersion,
        encode: encode,
      ),
    );
    late final Future<void> tracked;
    tracked = next.whenComplete(() {
      if (identical(_writeChains[fileName], tracked)) {
        _writeChains.remove(fileName);
      }
    });
    _writeChains[fileName] = tracked;
    await next;
  }

  Future<void> _writeJsonFileOnce({
    required String fileName,
    required int currentSchemaVersion,
    required dynamic Function() encode,
  }) async {
    try {
      final file = await _file(fileName);
      final tmp = File('${file.path}.tmp');
      final backup = File('${file.path}.bak');
      final payload = jsonEncode({
        '_v': currentSchemaVersion,
        'data': encode(),
      });
      await tmp.writeAsString(payload, flush: true);
      if (await backup.exists()) await backup.delete();
      if (await file.exists()) await file.rename(backup.path);
      try {
        await tmp.rename(file.path);
      } catch (_) {
        if (!await file.exists() && await backup.exists()) {
          await backup.rename(file.path);
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('StorageService.writeJsonFile($fileName) 失败: $e');
    }
  }

  @visibleForTesting
  void setTestDirectory(Directory? directory) {
    _testDirectory = directory;
  }

  Future<File> _file(String fileName) async {
    final dir = _testDirectory ?? await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}/$fileName');
  }
}
