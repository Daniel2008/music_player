import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/gd_music_api.dart';
import '../services/favorites_service.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final Playlist playlist = Playlist(name: '默认播放列表');
  final GdMusicApiClient _gdApi = GdMusicApiClient();
  final FavoritesService favorites = FavoritesService();

  double volume = 1.0;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  List<GdSearchTrack> searchResults = const [];
  bool isSearching = false;
  String? searchError;
  int _searchSeq = 0;

  bool isResolvingUrl = false;
  String? playError;

  int lyricRevision = 0;
  // 本地歌曲在线歌词缓存：track.id -> absolute lrc path
  final Map<String, String> localLyricPaths = {};

  PlayerProvider() {
    _init();
  }

  Future<void> _init() async {
    _player.setVolume(volume);
    _player.onPositionChanged.listen((d) {
      position = d;
      notifyListeners();
    });
    _player.onDurationChanged.listen((d) {
      duration = d;
      notifyListeners();
    });
    _player.onPlayerStateChanged.listen((s) {
      isPlaying = s == PlayerState.playing;
      notifyListeners();
    });
    _player.onPlayerComplete.listen((_) {
      _handleComplete();
    });
    await favorites.load();
    await _loadHistory();
  }

  Future<void> toggleFavorite(GdSearchTrack track) async {
    await favorites.toggle(track);
    notifyListeners();
  }

  Future<void> addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'flac', 'm4a', 'ogg'],
    );
    if (result == null) return;
    final existing = playlist.tracks.map((e) => e.path).toSet();
    final files = result.paths.whereType<String>().where((p) => p.isNotEmpty);
    final tracks = files
        .where((p) => !existing.contains(p))
        .map((p) => Track(title: p.split(Platform.pathSeparator).last, path: p))
        .toList();
    if (tracks.isNotEmpty) {
      playlist.addAll(tracks);
      notifyListeners();
    }
  }

  Future<void> addFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;

    final dir = Directory(result);
    final existing = playlist.tracks.map((e) => e.path).toSet();
    final audioExtensions = {
      '.mp3',
      '.wav',
      '.flac',
      '.m4a',
      '.ogg',
      '.aac',
      '.wma',
    };
    final tracks = <Track>[];

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final path = entity.path;
        final ext = path.substring(path.lastIndexOf('.')).toLowerCase();
        if (audioExtensions.contains(ext) && !existing.contains(path)) {
          tracks.add(
            Track(title: path.split(Platform.pathSeparator).last, path: path),
          );
        }
      }
    }

    if (tracks.isNotEmpty) {
      // 按文件名排序
      tracks.sort((a, b) => a.title.compareTo(b.title));
      playlist.addAll(tracks);
      notifyListeners();
    }
  }

  Future<void> playCurrent() async {
    final t = playlist.current;
    if (t == null) return;
    await _player.stop();
    if (t.isRemote) {
      await _player.setSource(UrlSource(t.path));
      await _player.resume();
      unawaited(_ensureLyricCachedFor(t));
    } else {
      final path = await _resolveSourcePath(t.path);
      await _player.setSource(DeviceFileSource(path));
      await _player.resume();
      _saveHistory(t.path);
    }
  }

  Future<String> _resolveSourcePath(String path) async {
    return path;
  }

  Future<void> searchOnline(String keyword, {String source = 'netease'}) async {
    final q = keyword.trim();
    if (q.isEmpty) {
      searchResults = const [];
      searchError = null;
      isSearching = false;
      notifyListeners();
      return;
    }

    final seq = ++_searchSeq;
    isSearching = true;
    searchError = null;
    notifyListeners();

    try {
      final results = await _gdApi.search(keyword: q, source: source);
      if (seq != _searchSeq) return;
      searchResults = results;
    } catch (e) {
      if (seq != _searchSeq) return;
      searchError = e.toString();
      searchResults = const [];
    } finally {
      if (seq != _searchSeq) return;
      isSearching = false;
      notifyListeners();
    }
  }

  void removeTrack(int index) {
    if (index < 0 || index >= playlist.tracks.length) return;
    playlist.tracks.removeAt(index);
    if (playlist.currentIndex >= playlist.tracks.length) {
      playlist.currentIndex = playlist.tracks.length - 1;
    }
    notifyListeners();
  }

  void clearPlaylist() {
    playlist.tracks.clear();
    playlist.currentIndex = -1;
    notifyListeners();
  }

  Future<bool> playSearchResult(GdSearchTrack item, {String br = '999'}) async {
    if (isResolvingUrl) return false;
    isResolvingUrl = true;
    playError = null;
    notifyListeners();

    try {
      final url = await _gdApi.getTrackUrl(
        source: item.source,
        id: item.id,
        br: br,
      );

      final displayArtist = item.artistText;
      final title = displayArtist.isEmpty
          ? item.name
          : '${item.name} - $displayArtist';

      final track = Track(
        title: title,
        path: url.url,
        kind: TrackKind.remote,
        remoteSource: item.source,
        remoteTrackId: item.id,
        remoteLyricId: item.lyricId ?? item.id,
        lyricKey: 'gd_${item.source}_${item.lyricId ?? item.id}',
      );

      final existingIndex = playlist.tracks.indexWhere(
        (t) =>
            t.kind == TrackKind.remote &&
            t.remoteSource == track.remoteSource &&
            t.remoteTrackId == track.remoteTrackId,
      );
      if (existingIndex >= 0) {
        playlist.currentIndex = existingIndex;
      } else {
        playlist.addAll([track]);
        playlist.currentIndex = playlist.tracks.length - 1;
      }

      notifyListeners();
      await playCurrent();
      return true;
    } catch (e) {
      playError = _friendlyPlayError(e, source: item.source, br: br);
      notifyListeners();
      return false;
    } finally {
      isResolvingUrl = false;
      notifyListeners();
    }
  }

  String _friendlyPlayError(
    Object e, {
    required String source,
    required String br,
  }) {
    if (e is GdMusicApiTimeout) {
      return '获取播放链接超时（源：$source，音质：$br），请稍后重试或切换源/音质。';
    }
    if (e is GdMusicApiHttpException) {
      return '服务返回 ${e.statusCode}（源：$source，音质：$br），请稍后重试或切换源/音质。';
    }
    if (e is FormatException) {
      return '服务响应解析失败（源：$source，音质：$br），请稍后重试。';
    }
    return '播放失败（源：$source，音质：$br）：${e.toString()}';
  }

  // 下载相关
  Map<String, double> downloadProgress = {};
  Set<String> downloadingIds = {};

  Future<String?> downloadTrack(GdSearchTrack item, {String br = '320'}) async {
    final trackKey = '${item.source}_${item.id}';
    if (downloadingIds.contains(trackKey)) return null;

    downloadingIds.add(trackKey);
    downloadProgress[trackKey] = 0.0;
    notifyListeners();

    try {
      // 获取下载链接
      final urlInfo = await _gdApi.getTrackUrl(
        source: item.source,
        id: item.id,
        br: br,
      );

      // 选择保存目录
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存音乐',
        fileName: '${item.name} - ${item.artistText}.mp3',
        type: FileType.custom,
        allowedExtensions: ['mp3'],
      );

      if (savePath == null) {
        downloadingIds.remove(trackKey);
        downloadProgress.remove(trackKey);
        notifyListeners();
        return null;
      }

      // 下载文件
      final request = http.Request('GET', Uri.parse(urlInfo.url));
      final response = await http.Client().send(request);

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          downloadProgress[trackKey] = received / contentLength;
          notifyListeners();
        }
      }

      // 保存文件
      final file = File(savePath);
      await file.writeAsBytes(bytes);

      downloadProgress[trackKey] = 1.0;
      notifyListeners();

      // 延迟后清理状态
      Future.delayed(const Duration(seconds: 2), () {
        downloadingIds.remove(trackKey);
        downloadProgress.remove(trackKey);
        notifyListeners();
      });

      return savePath;
    } catch (e) {
      downloadingIds.remove(trackKey);
      downloadProgress.remove(trackKey);
      notifyListeners();
      rethrow;
    }
  }

  bool isDownloading(String source, String id) {
    return downloadingIds.contains('${source}_$id');
  }

  double getDownloadProgress(String source, String id) {
    return downloadProgress['${source}_$id'] ?? 0.0;
  }

  Future<void> _ensureLyricCachedFor(Track track) async {
    if (!track.isRemote) return;
    final source = track.remoteSource;
    final lyricId = track.remoteLyricId;
    final key = track.lyricKey;
    if (source == null || lyricId == null || key == null) return;

    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$key.lrc');
    if (await file.exists()) return;

    try {
      final lyric = await _gdApi.getLyric(source: source, id: lyricId);
      if (lyric.lyric.trim().isEmpty) return;
      await file.writeAsString(lyric.lyric);
      lyricRevision++;
      notifyListeners();
    } catch (_) {
      // Ignore lyric fetch errors.
    }
  }

  /// 为本地歌曲搜索并缓存在线歌词。
  /// 返回已保存的文件路径，或 null 表示未找到或失败。
  Future<String?> fetchOnlineLyricForLocal(
    Track track, {
    String source = 'netease',
  }) async {
    if (track.isRemote) return null;
    try {
      // 使用歌曲标题作为关键词搜索
      final results = await _gdApi.search(
        keyword: track.title,
        source: source,
        count: 8,
      );
      // 选取第一个带有 lyricId 的结果
      final matches = results
          .where((r) => r.lyricId != null && r.lyricId!.isNotEmpty)
          .toList();
      if (matches.isEmpty) return null;
      final match = matches.first;

      final lyric = await _gdApi.getLyric(
        source: match.source,
        id: match.lyricId!,
      );
      if (lyric.lyric.trim().isEmpty) return null;

      final dir = await getApplicationSupportDirectory();
      final filename = 'local_${track.id}.lrc';
      final path = '${dir.path}/$filename';
      final file = File(path);
      await file.writeAsString(lyric.lyric);
      localLyricPaths[track.id] = path;
      lyricRevision++;
      notifyListeners();
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<void> play() async {
    await _player.resume();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> next() async {
    playlist.next();
    await playCurrent();
  }

  Future<void> previous() async {
    playlist.previous();
    await playCurrent();
  }

  Future<void> seek(Duration d) async {
    final clamped = _clampDuration(d, Duration.zero, duration);
    await _player.seek(clamped);
  }

  Future<void> setVolume(double v) async {
    volume = v;
    await _player.setVolume(v);
  }

  // 均衡器功能已移除

  Future<void> _saveHistory(String lastPath) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('history') ?? [];
    list.remove(lastPath);
    list.insert(0, lastPath);
    while (list.length > 50) {
      list.removeLast();
    }
    await prefs.setStringList('history', list);
  }

  Future<List<String>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('history') ?? [];
  }

  Future<void> _loadHistory() async {
    final list = await loadHistory();
    if (list.isNotEmpty) {
      final last = list.first;
      final file = File(last);
      if (await file.exists()) {
        final track = Track(
          title: last.split(Platform.pathSeparator).last,
          path: last,
        );
        playlist.addAll([track]);
        await playCurrent();
      }
    }
  }

  Future<void> _handleComplete() async {
    if (playlist.isEmpty) return;
    playlist.next();
    await playCurrent();
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max && max > Duration.zero) return max;
    return value;
  }

  @override
  void dispose() {
    _gdApi.close();
    _player.dispose();
    super.dispose();
  }
}
