import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/storage_service.dart';

/// 播放模式枚举
enum PlayMode {
  sequence, // 顺序播放（播完最后一首停止）
  loop, // 列表循环
  single, // 单曲循环
  shuffle, // 随机播放
}

class PlaylistProvider extends ChangeNotifier {
  PlaylistProvider({Playlist? initialPlaylist})
    : playlist = initialPlaylist ?? Playlist(name: '默认播放列表') {
    ready = loadPlaylist();
  }
  final Playlist playlist;
  static const String _storageKey = 'saved_playlist';
  static const int _maxTracks = 500;
  static const int _schemaVersion = 1;
  final Random _random = Random();
  Timer? _saveDebounce;
  late final Future<void> ready;

  PlayMode _playMode = PlayMode.loop;
  PlayMode get playMode => _playMode;

  void setPlayMode(PlayMode mode) {
    _playMode = mode;
    notifyListeners();
  }

  /// 循环切换播放模式
  void cyclePlayMode() {
    const modes = PlayMode.values;
    final nextIndex = (modes.indexOf(_playMode) + 1) % modes.length;
    setPlayMode(modes[nextIndex]);
  }

  Track? get current => playlist.current;
  bool get isEmpty => playlist.isEmpty;
  int get currentIndex => playlist.currentIndex;
  List<Track> get tracks => playlist.tracks;

  /// 初始化并加载保存的播放列表
  Future<void> init() => ready;

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
    final oldCurrentIndex = playlist.currentIndex;
    playlist.tracks.removeAt(index);
    if (playlist.tracks.isEmpty) {
      playlist.currentIndex = -1;
    } else if (index < oldCurrentIndex) {
      playlist.currentIndex = oldCurrentIndex - 1;
    } else if (index == oldCurrentIndex) {
      playlist.currentIndex = oldCurrentIndex.clamp(
        0,
        playlist.tracks.length - 1,
      );
    } else if (oldCurrentIndex >= playlist.tracks.length) {
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
    final result = await FilePicker.pickFiles(
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
    final result = await FilePicker.getDirectoryPath();

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
    if (playlist.tracks.length >= _maxTracks) return -1;
    playlist.tracks.add(track);
    playlist.currentIndex = playlist.tracks.length - 1;
    notifyListeners();
    _savePlaylist();
    return playlist.currentIndex;
  }

  bool _isAudioFile(String path) {
    final audioExtensions = [
      '.mp3',
      '.wav',
      '.aac',
      '.flac',
      '.ogg',
      '.wma',
      '.m4a',
      '.opus',
    ];
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex <= 0) return false;
    final extension = path.toLowerCase().substring(dotIndex);
    return audioExtensions.contains(extension);
  }

  /// 路径白名单校验：path 必须在 baseDir 之下（防 ../ 越权）
  bool _isWithinDir(String path, String baseDir) {
    try {
      final resolved = p.canonicalize(path);
      final base = baseDir.endsWith(p.separator)
          ? baseDir
          : '$baseDir${p.separator}';
      return resolved == baseDir || resolved.startsWith(base);
    } catch (_) {
      return false;
    }
  }

  /// 保存播放列表到本地存储（防抖动，避免过于频繁的磁盘写入）
  void _savePlaylist() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _doSavePlaylist);
  }

  Future<void> _doSavePlaylist() async {
    await StorageService.instance.writeJsonFile(
      fileName: _storageKey,
      currentSchemaVersion: _schemaVersion,
      encode: () => {
        'name': playlist.name,
        'currentIndex': playlist.currentIndex,
        'tracks': playlist.tracks.map((t) => t.toJson()).toList(),
      },
    );
  }

  Future<void> flush() async {
    _saveDebounce?.cancel();
    await _doSavePlaylist();
  }

  /// 从本地存储加载播放列表
  Future<void> loadPlaylist() async {
    final result = await StorageService.instance
        .readJsonFile<Map<String, dynamic>>(
          fileName: _storageKey,
          currentSchemaVersion: _schemaVersion,
          decode: (raw, _) {
            if (raw is! Map<String, dynamic>) return null;
            return raw;
          },
        );
    if (result == null) return;

    final tracksJson = result['tracks'] as List<dynamic>? ?? [];
    final currentIndex = result['currentIndex'] as int? ?? -1;

    final tracks = tracksJson
        .whereType<Map>()
        .map((j) => Track.fromJson(j.cast<String, dynamic>()))
        .whereType<Track>()
        .toList();

    playlist.tracks.clear();
    playlist.tracks.addAll(tracks);
    playlist.currentIndex = currentIndex.clamp(-1, tracks.length - 1);
    notifyListeners();
  }

  /// 从 M3U 文件导入播放列表
  Future<void> importM3u() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8'],
      );
      if (result == null || result.files.isEmpty) return;

      final m3uFilePath = result.files.single.path!;
      final file = File(m3uFilePath);
      final m3uDir = p.dirname(m3uFilePath);
      // 规范化 m3u 所在目录，做路径白名单基线（防止 ../ 越权访问系统盘/敏感目录）
      final m3uDirReal = p.canonicalize(m3uDir);
      final lines = await file.readAsLines();
      final imported = <Track>[];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        // 确定音频文件的绝对路径
        final absolutePath = p.isAbsolute(trimmed)
            ? p.normalize(trimmed)
            : p.normalize(p.join(m3uDir, trimmed));

        // 路径白名单：必须解析到 m3u 所在目录内
        if (!_isWithinDir(absolutePath, m3uDirReal)) {
          debugPrint('跳过越权路径: $absolutePath');
          continue;
        }

        final trackFile = File(absolutePath);
        if (await trackFile.exists() && _isAudioFile(absolutePath)) {
          final fileName = p.basename(absolutePath);
          final dotIndex = fileName.lastIndexOf('.');
          final title = dotIndex > 0
              ? fileName.substring(0, dotIndex)
              : fileName;
          imported.add(Track(title: title, path: absolutePath));
        }
      }

      if (imported.isNotEmpty) addAll(imported);
    } catch (e) {
      debugPrint('导入 M3U 失败: $e');
    }
  }

  /// 导出当前播放列表为 M3U 文件
  Future<void> exportM3u() async {
    try {
      final result = await FilePicker.saveFile(
        dialogTitle: '导出播放列表',
        fileName: '${playlist.name}.m3u',
        type: FileType.custom,
        allowedExtensions: ['m3u'],
      );
      if (result == null) return;

      final buffer = StringBuffer();
      buffer.writeln('#EXTM3U');
      buffer.writeln('#PLAYLIST:${playlist.name}');

      for (final track in playlist.tracks) {
        buffer.writeln(track.path);
      }

      await File(result).writeAsString(buffer.toString());
    } catch (e) {
      debugPrint('导出 M3U 失败: $e');
    }
  }

  @override
  void dispose() {
    // 触发关闭前保存；应用生命周期可调用 flush() 等待完成。
    unawaited(flush());
    super.dispose();
  }
}
