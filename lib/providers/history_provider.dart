import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';

class HistoryProvider extends ChangeNotifier {
  final List<Track> _history = [];
  static const int _maxHistoryItems = 100;
  static const String _fileName = 'play_history.json';
  Timer? _saveDebounce;

  List<Track> get history => List.unmodifiable(_history);
  bool get isEmpty => _history.isEmpty;

  HistoryProvider() {
    _loadHistory();
  }

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

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// 防抖保存，避免频繁写盘
  void _saveHistory() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _doSave);
  }

  Future<void> _doSave() async {
    try {
      final file = await _getFile();
      final jsonData = _history.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      debugPrint('保存播放历史失败: $e');
    }
  }

  Future<void> _loadHistory() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonData = jsonDecode(contents);
        _history.clear();
        for (final item in jsonData) {
          final track = Track.fromJson(item as Map<String, dynamic>);
          if (track != null) {
            _history.add(track);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('加载播放历史失败: $e');
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _doSave(); // 确保最后一次保存
    super.dispose();
  }
}
