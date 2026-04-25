import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/track.dart';

/// 播放模式枚举
enum PlayMode {
  sequence, // 顺序播放（播完最后一首停止）
  loop,     // 列表循环
  single,   // 单曲循环
  shuffle,  // 随机播放
}

class PlaylistProvider extends ChangeNotifier {
  final Playlist playlist;
  static const String _storageKey = 'saved_playlist';
  static const int _maxTracks = 500;
  final Random _random = Random();
  Timer? _saveDebounce;

  PlayMode _playMode = PlayMode.loop;
  PlayMode get playMode => _playMode;

  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    notifyListeners();
  }

  /// 循环切换播放模式
  void cyclePlayMode() {
    final modes = PlayMode.values;
    final nextIndex = (modes.indexOf(_playMode) + 1) % modes.length;
    setPlayMode(modes[nextIndex]);
  }

  PlaylistProvider({Playlist? initialPlaylist})
    : playlist = initialPlaylist ?? Playlist(name: '默认播放列表');

  Track? get current => playlist.current;
  bool get isEmpty => playlist.isEmpty;
  int get currentIndex => playlist.currentIndex;
  List<Track> get tracks => playlist.tracks;

  /// 初始化并加载保存的播放列表
  Future<void> init() async {
    await loadPlaylist();
  }

  void addTrack(Track track) {
    if (playlist.tracks.length >= _maxTracks) return;
    playlist.tracks.add(track);
    notifyListeners();
    _savePlaylist();
  }

  void addAll(List<Track> tracks) {
    final remaining = _maxTracks - playlist.tracks.length;
    if (remaining <= 0) return;
    playlist.tracks.addAll(tracks.take(remaining));
    notifyListeners();
    _savePlaylist();
  }

  void removeTrack(int index) {
    if (index < 0 || index >= playlist.tracks.length) return;
    playlist.tracks.removeAt(index);
    if (playlist.currentIndex >= playlist.tracks.length) {
      playlist.currentIndex = playlist.tracks.length - 1;
    }
    notifyListeners();
    _savePlaylist();
  }

  void clear() {
    playlist.tracks.clear();
    playlist.currentIndex = -1;
    notifyListeners();
    _savePlaylist();
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < playlist.tracks.length) {
      playlist.currentIndex = index;
      notifyListeners();
      _savePlaylist();
    }
  }

  void next() {
    if (playlist.tracks.isEmpty) return;
    switch (_playMode) {
      case PlayMode.sequence:
        // 顺序播放：下一首，播到最后停止
        if (playlist.currentIndex < playlist.tracks.length - 1) {
          playlist.currentIndex++;
        }
        break;
      case PlayMode.loop:
        // 列表循环：下一首，超出则回到开头
        playlist.currentIndex =
            (playlist.currentIndex + 1) % playlist.tracks.length;
        break;
      case PlayMode.single:
        // 单曲循环：索引不变
        break;
      case PlayMode.shuffle:
        // 随机播放：随机选择一首（排除当前）
        if (playlist.tracks.length > 1) {
          int newIndex;
          do {
            newIndex = _random.nextInt(playlist.tracks.length);
          } while (newIndex == playlist.currentIndex);
          playlist.currentIndex = newIndex;
        }
        break;
    }
    notifyListeners();
    _savePlaylist();
  }

  void previous() {
    if (playlist.tracks.isEmpty) return;
    switch (_playMode) {
      case PlayMode.sequence:
      case PlayMode.loop:
        if (playlist.currentIndex > 0) {
          playlist.currentIndex--;
        } else if (_playMode == PlayMode.loop) {
          playlist.currentIndex = playlist.tracks.length - 1;
        }
        break;
      case PlayMode.single:
        // 单曲循环：索引不变
        break;
      case PlayMode.shuffle:
        if (playlist.tracks.length > 1) {
          int newIndex;
          do {
            newIndex = _random.nextInt(playlist.tracks.length);
          } while (newIndex == playlist.currentIndex);
          playlist.currentIndex = newIndex;
        }
        break;
    }
    notifyListeners();
    _savePlaylist();
  }

  /// 拖拽排序
  void reorderTrack(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final track = playlist.tracks.removeAt(oldIndex);
    playlist.tracks.insert(newIndex, track);
    // 如果当前播放的曲目被移动了，更新索引
    if (playlist.currentIndex == oldIndex) {
      playlist.currentIndex = newIndex;
    } else if (oldIndex < playlist.currentIndex &&
        newIndex >= playlist.currentIndex) {
      playlist.currentIndex--;
    } else if (oldIndex > playlist.currentIndex &&
        newIndex <= playlist.currentIndex) {
      playlist.currentIndex++;
    }
    notifyListeners();
    _savePlaylist();
  }

  /// 更新当前曲目的路径（用于在线曲目解析后更新 URL）
  void updateCurrentTrackPath(String path) {
    final current = playlist.current;
    if (current != null) {
      final index = playlist.currentIndex;
      if (index >= 0 && index < playlist.tracks.length) {
        playlist.tracks[index] = current.copyWith(path: path);
        notifyListeners();
        _savePlaylist();
      }
    }
  }

  /// 更新当前曲目的封面
  void updateCurrentTrackArtUri(String? artUri) {
    final current = playlist.current;
    if (current != null) {
      final index = playlist.currentIndex;
      if (index >= 0 && index < playlist.tracks.length) {
        playlist.tracks[index] = current.copyWith(artUri: artUri);
        notifyListeners();
        _savePlaylist();
      }
    }
  }

  /// 更新指定索引的曲目
  void updateTrackAt(int index, Track track) {
    if (index >= 0 && index < playlist.tracks.length) {
      playlist.tracks[index] = track;
      notifyListeners();
      _savePlaylist();
    }
  }

  Future<void> addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null) {
      final tracks = result.files.map((file) {
        final fileName = file.name;
        final dotIndex = fileName.lastIndexOf('.');
        final title = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
        return Track(title: title, path: file.path ?? '');
      }).toList();

      addAll(tracks);
    }
  }

  Future<void> addFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      final directory = Directory(result);
      final entities = await directory.list().toList();
      final files = entities
          .where((entity) => entity is File && _isAudioFile(entity.path))
          .cast<File>()
          .toList();

      final tracks = files.map((file) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        final dotIndex = fileName.lastIndexOf('.');
        final title = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
        return Track(title: title, path: file.path);
      }).toList();

      addAll(tracks);
    }
  }

  /// 添加或选中已有曲目（统一搜索/收藏播放逻辑）
  ///
  /// 返回曲目在播放列表中的索引
  int addOrSelectTrack(Track track) {
    final existingIndex = playlist.tracks.indexWhere((t) => t.id == track.id);
    if (existingIndex >= 0) {
      playlist.currentIndex = existingIndex;
      notifyListeners();
      _savePlaylist();
      return existingIndex;
    }
    playlist.tracks.add(track);
    playlist.currentIndex = playlist.tracks.length - 1;
    notifyListeners();
    _savePlaylist();
    return playlist.currentIndex;
  }

  bool _isAudioFile(String path) {
    final audioExtensions = [
      '.mp3', '.wav', '.aac', '.flac', '.ogg', '.wma', '.m4a', '.opus',
    ];
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex <= 0) return false;
    final extension = path.toLowerCase().substring(dotIndex);
    return audioExtensions.contains(extension);
  }

  /// 保存播放列表到本地存储（防抖动，避免过于频繁的磁盘写入）
  void _savePlaylist() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _doSavePlaylist);
  }

  Future<void> _doSavePlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tracksJson = playlist.tracks.map((t) => t.toJson()).toList();
      final data = {
        'name': playlist.name,
        'currentIndex': playlist.currentIndex,
        'tracks': tracksJson,
      };
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('保存播放列表失败: $e');
    }
  }

  /// 从本地存储加载播放列表
  Future<void> loadPlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr == null || jsonStr.isEmpty) return;

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final tracksJson = data['tracks'] as List<dynamic>? ?? [];
      final currentIndex = data['currentIndex'] as int? ?? -1;

      final tracks = tracksJson
          .map((json) => Track.fromJson(json as Map<String, dynamic>))
          .whereType<Track>()
          .toList();

      playlist.tracks.clear();
      playlist.tracks.addAll(tracks);
      playlist.currentIndex = currentIndex.clamp(-1, tracks.length - 1);
      notifyListeners();
    } catch (e) {
      debugPrint('加载播放列表失败: $e');
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    // 确保 dispose 前立即保存一次
    _doSavePlaylist();
    super.dispose();
  }
}
