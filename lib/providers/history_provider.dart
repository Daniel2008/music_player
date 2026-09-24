import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../services/storage_service.dart';

class HistoryProvider extends ChangeNotifier {
  HistoryProvider() {
    ready = _loadHistory();
  }
  final List<Track> _history = [];
  static const int _maxHistoryItems = 100;
  static const String _fileName = 'play_history.json';
  static const int _schemaVersion = 1;
  Timer? _saveDebounce;
  late final Future<void> ready;

  List<Track> get history => _history;
  bool get isEmpty => _history.isEmpty;

  /// 添加一首歌曲到历史记录
  /// 如果歌曲已存在，会将其移到最前面
  void addTrack(Track track) {
    // 移除已存在的相同歌曲
    _history.removeWhere((item) => item.id == track.id);

    // 添加到历史记录开头
    _history.insert(0, track);

    // 如果超过最大限制，删除最旧的记录
    if (_history.length > _maxHistoryItems) {
      _history.removeLast();
    }

    notifyListeners();
    _saveHistory();
  }

  /// 从历史记录中移除指定索引的歌曲
  void removeTrack(int index) {
    if (index >= 0 && index < _history.length) {
      _history.removeAt(index);
      notifyListeners();
      _saveHistory();
    }
  }

  /// 清空所有历史记录
  void clear() {
    _history.clear();
    notifyListeners();
    _saveHistory();
  }

  /// 检查歌曲是否在历史记录中
  bool contains(String trackId) {
    return _history.any((track) => track.id == trackId);
  }

  // ── 持久化 ──

  /// 防抖保存，避免频繁写盘
  void _saveHistory() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _doSave);
  }

  Future<void> _doSave() async {
    await StorageService.instance.writeJsonFile(
      fileName: _fileName,
      currentSchemaVersion: _schemaVersion,
      encode: () => _history.map((t) => t.toJson()).toList(),
    );
  }

  Future<void> _loadHistory() async {
    final result = await StorageService.instance.readJsonFile<List<Track>>(
      fileName: _fileName,
      currentSchemaVersion: _schemaVersion,
      decode: (raw, _) {
        if (raw is! List) return null;
        return raw
            .whereType<Map>()
            .map((e) => Track.fromJson(e.cast<String, dynamic>()))
            .whereType<Track>()
            .toList();
      },
    );
    if (result != null) {
      _history.clear();
      _history.addAll(result);
      notifyListeners();
    }
  }

  Future<void> flush() async {
    _saveDebounce?.cancel();
    await _doSave();
  }

  @override
  void dispose() {
    unawaited(flush());
    super.dispose();
  }
}
