import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/track.dart';

class PlaylistProvider extends ChangeNotifier {
  final Playlist playlist;
  static const String _storageKey = 'saved_playlist';

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
    playlist.tracks.add(track);
    notifyListeners();
    _savePlaylist();
  }

  void addAll(List<Track> tracks) {
    playlist.tracks.addAll(tracks);
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
    playlist.next();
    notifyListeners();
    _savePlaylist();
  }

  void previous() {
    playlist.previous();
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
        final title = fileName.substring(0, fileName.lastIndexOf('.'));
        return Track(title: title, path: file.path ?? '');
      }).toList();

      addAll(tracks);
    }
  }

  Future<void> addFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      final directory = Directory(result);
      final files = directory
          .listSync()
          .where((entity) => entity is File && _isAudioFile(entity.path))
          .cast<File>()
          .toList();

      final tracks = files.map((file) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        final title = fileName.substring(0, fileName.lastIndexOf('.'));
        return Track(title: title, path: file.path);
      }).toList();

      addAll(tracks);
    }
  }

  bool _isAudioFile(String path) {
    final audioExtensions = ['.mp3', '.wav', '.aac', '.flac', '.ogg', '.wma'];
    final extension = path.toLowerCase().substring(path.lastIndexOf('.'));
    return audioExtensions.contains(extension);
  }

  /// 保存播放列表到本地存储
  Future<void> _savePlaylist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tracksJson = playlist.tracks
          .map((track) => _trackToJson(track))
          .toList();
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
          .map((json) => _trackFromJson(json as Map<String, dynamic>))
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

  /// 将 Track 转换为 JSON
  Map<String, dynamic> _trackToJson(Track track) {
    return {
      'id': track.id,
      'title': track.title,
      'path': track.path,
      'artist': track.artist,
      'artUri': track.artUri,
      'durationMs': track.duration?.inMilliseconds,
      'kind': track.kind.index,
      'remoteSource': track.remoteSource,
      'remoteTrackId': track.remoteTrackId,
      'remoteLyricId': track.remoteLyricId,
      'lyricKey': track.lyricKey,
    };
  }

  /// 从 JSON 恢复 Track
  Track? _trackFromJson(Map<String, dynamic> json) {
    try {
      final durationMs = json['durationMs'] as int?;
      final kindIndex = json['kind'] as int? ?? 0;

      return Track(
        id: json['id'] as String?,
        title: json['title'] as String? ?? '未知曲目',
        path: json['path'] as String? ?? '',
        artist: json['artist'] as String?,
        artUri: json['artUri'] as String?,
        duration: durationMs != null
            ? Duration(milliseconds: durationMs)
            : null,
        kind: TrackKind.values[kindIndex.clamp(0, TrackKind.values.length - 1)],
        remoteSource: json['remoteSource'] as String?,
        remoteTrackId: json['remoteTrackId'] as String?,
        remoteLyricId: json['remoteLyricId'] as String?,
        lyricKey: json['lyricKey'] as String?,
      );
    } catch (e) {
      debugPrint('解析 Track 失败: $e');
      return null;
    }
  }
}
