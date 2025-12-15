import 'package:flutter/foundation.dart';
import '../models/track.dart';

class HistoryProvider extends ChangeNotifier {
  final List<Track> _history = [];
  static const int _maxHistoryItems = 100;

  List<Track> get history => List.unmodifiable(_history);
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
  }

  /// 从历史记录中移除指定索引的歌曲
  void removeTrack(int index) {
    if (index >= 0 && index < _history.length) {
      _history.removeAt(index);
      notifyListeners();
    }
  }

  /// 清空所有历史记录
  void clear() {
    _history.clear();
    notifyListeners();
  }

  /// 检查歌曲是否在历史记录中
  bool contains(String trackId) {
    return _history.any((track) => track.id == trackId);
  }
}
