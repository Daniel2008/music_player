import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

enum PlayMode {
  sequential, // 顺序播放
  repeat, // 单曲循环
  shuffle, // 随机播放
}

class MusicPlayerState extends ChangeNotifier {
  List<String> _playlist = [];
  int? _currentIndex;
  double _volume = 1.0;
  PlayMode _playMode = PlayMode.sequential;

  List<String> get playlist => _playlist;
  String? get currentSong =>
      _currentIndex != null ? _playlist[_currentIndex!] : null;
  int? get currentIndex => _currentIndex;
  double get volume => _volume;
  PlayMode get playMode => _playMode;

  static const String _playlistKey = 'playlist';
  static const String _volumeKey = 'volume';
  static const String _playModeKey = 'playMode';

  MusicPlayerState() {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getStringList(_playlistKey);
    if (playlistJson != null) {
      _playlist =
          playlistJson.where((path) => File(path).existsSync()).toList();
    }
    _volume = prefs.getDouble(_volumeKey) ?? 1.0;
    _playMode = PlayMode.values[prefs.getInt(_playModeKey) ?? 0];
    notifyListeners();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_playlistKey, _playlist);
    await prefs.setDouble(_volumeKey, _volume);
    await prefs.setInt(_playModeKey, _playMode.index);
  }

  void addSongs(List<String> songs) {
    _playlist.addAll(songs);
    _saveState();
    notifyListeners();
  }

  Future<bool> removeSong(String song) async {
    final index = _playlist.indexOf(song);
    if (index == -1) return false;

    try {
      final file = File(song);
      if (await file.exists()) {
        await file.delete();
      }

      _playlist.removeAt(index);
      if (_currentIndex != null) {
        if (index < _currentIndex!) {
          _currentIndex = _currentIndex! - 1;
        } else if (index == _currentIndex!) {
          _currentIndex = _playlist.isEmpty ? null : _currentIndex;
        }
      }
      _saveState();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }

  void setCurrentSong(String song) {
    if (_playlist.contains(song)) {
      _currentIndex = _playlist.indexOf(song);
      _saveState();
      notifyListeners();
    }
  }

  void setVolume(double volume) {
    _volume = volume;
    _saveState();
    notifyListeners();
  }

  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    _saveState();
    notifyListeners();
  }

  void setPlaylist(List<String> songs) {
    _playlist = songs;
    _saveState();
    notifyListeners();
  }

  String? getNextSong() {
    if (_playlist.isEmpty || _currentIndex == null) return null;

    switch (_playMode) {
      case PlayMode.sequential:
        _currentIndex = (_currentIndex! + 1) % _playlist.length;
        break;
      case PlayMode.repeat:
        // 保持当前索引不变
        break;
      case PlayMode.shuffle:
        _currentIndex = (_currentIndex! +
                (DateTime.now().millisecondsSinceEpoch %
                        (_playlist.length - 1) +
                    1)) %
            _playlist.length;
        break;
    }
    notifyListeners();
    return currentSong;
  }

  String? getPreviousSong() {
    if (_playlist.isEmpty || _currentIndex == null) return null;

    switch (_playMode) {
      case PlayMode.sequential:
        _currentIndex =
            (_currentIndex! - 1 + _playlist.length) % _playlist.length;
        break;
      case PlayMode.repeat:
        // 保持当前索引不变
        break;
      case PlayMode.shuffle:
        _currentIndex = (_currentIndex! +
                (_playlist.length - 1) +
                (DateTime.now().millisecondsSinceEpoch %
                        (_playlist.length - 1) +
                    1)) %
            _playlist.length;
        break;
    }
    notifyListeners();
    return currentSong;
  }

  String? getRandomSong() {
    if (_playlist.isEmpty) return null;
    final random = Random();
    final randomIndex = random.nextInt(_playlist.length);
    _currentIndex = randomIndex;
    notifyListeners();
    return _playlist[randomIndex];
  }
}
