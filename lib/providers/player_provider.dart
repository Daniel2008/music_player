import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';
import '../services/gd_music_api.dart';
import 'playlist_provider.dart';

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final GdMusicApiClient _gdApi = GdMusicApiClient();

  /// 播放完成回调，用于自动下一曲
  VoidCallback? onTrackComplete;

  /// 获取 API 客户端（用于外部访问）
  GdMusicApiClient get gdApi => _gdApi;

  /// 触发歌词更新通知
  void notifyLyricUpdated() {
    lyricRevision++;
    notifyListeners();
  }

  double volume = 1.0;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  bool isResolvingUrl = false;
  String? playError;

  int lyricRevision = 0;
  // 本地歌曲在线歌词缓存：track.id -> absolute lrc path
  final Map<String, String> localLyricPaths = {};

  // 是否自动为本地歌曲搜索在线歌词
  bool autoFetchLyricForLocal = true;

  // 正在搜索歌词的曲目 ID 集合（防止重复搜索）
  final Set<String> _fetchingLyricIds = {};

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
  }

  Future<void> playTrack(Track track) async {
    await _player.stop();
    if (track.isRemote) {
      await _player.setSource(UrlSource(track.path));
      await _player.resume();
      unawaited(_ensureLyricCachedFor(track));
    } else {
      final path = await _resolveSourcePath(track.path);
      await _player.setSource(DeviceFileSource(path));
      await _player.resume();
      // 自动为本地歌曲搜索在线歌词
      if (autoFetchLyricForLocal) {
        unawaited(_autoFetchLyricForLocalTrack(track));
      }
    }
  }

  Future<String> _resolveSourcePath(String path) async {
    return path;
  }

  /// 解析并播放在线曲目
  ///
  /// [item] 搜索结果中的曲目
  /// [br] 音质
  /// [playlistProvider] 如果提供，会更新播放列表中当前曲目的 URL
  Future<bool> resolveAndPlayTrackUrl(
    GdSearchTrack item, {
    String br = '999',
    PlaylistProvider? playlistProvider,
  }) async {
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

      final artUri = _gdApi.buildCoverUrl(item.picId, item.source);
      final lyricKey = 'gd_${item.source}_${item.lyricId ?? item.id}';

      // 如果提供了 playlistProvider，更新当前曲目的 URL 和封面
      if (playlistProvider != null) {
        final current = playlistProvider.current;
        if (current != null) {
          final updatedTrack = current.copyWith(path: url.url, artUri: artUri);
          playlistProvider.updateTrackAt(
            playlistProvider.currentIndex,
            updatedTrack,
          );
          // 直接播放，使用更新后的 track
          await _playTrackDirectly(updatedTrack);
          return true;
        }
      }

      // 回退到原来的逻辑：创建新的 Track 并播放
      final track = Track(
        id: Track.generateRemoteId(item.source, item.id),
        title: title,
        path: url.url,
        artist: displayArtist.isEmpty ? null : displayArtist,
        artUri: artUri,
        kind: TrackKind.remote,
        remoteSource: item.source,
        remoteTrackId: item.id,
        remoteLyricId: item.lyricId ?? item.id,
        lyricKey: lyricKey,
      );

      await playTrack(track);
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

  /// 直接播放 Track（内部方法，不创建新 Track）
  Future<void> _playTrackDirectly(Track track) async {
    await _player.stop();
    if (track.isRemote) {
      await _player.setSource(UrlSource(track.path));
      await _player.resume();
      unawaited(_ensureLyricCachedFor(track));
    } else {
      final path = await _resolveSourcePath(track.path);
      await _player.setSource(DeviceFileSource(path));
      await _player.resume();
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

  /// 自动为本地歌曲搜索歌词（内部方法）
  Future<void> _autoFetchLyricForLocalTrack(Track track) async {
    if (track.isRemote) return;

    // 检查是否已有本地歌词文件
    final localLrcPath = await _getLocalLrcPath(track);
    if (localLrcPath != null) return;

    // 检查是否已缓存过
    if (localLyricPaths.containsKey(track.id)) return;

    // 检查是否正在搜索
    if (_fetchingLyricIds.contains(track.id)) return;

    // 开始自动搜索
    await fetchOnlineLyricForLocal(track);
  }

  /// 获取本地歌词文件路径（如果存在）
  Future<String?> _getLocalLrcPath(Track track) async {
    // 检查音频同目录下的 .lrc 文件
    final audioPath = track.path;
    final name = audioPath.replaceAll(RegExp(r"\.[^/.]+$"), '');
    final lrcLocal = '$name.lrc';
    if (await File(lrcLocal).exists()) return lrcLocal;

    // 检查应用缓存目录
    final dir = await getApplicationSupportDirectory();
    final cachedPath = '${dir.path}/local_${track.id}.lrc';
    if (await File(cachedPath).exists()) return cachedPath;

    return null;
  }

  /// 为本地歌曲搜索并缓存在线歌词。
  /// 返回已保存的文件路径，或 null 表示未找到或失败。
  ///
  /// [track] 本地歌曲
  /// [source] 音乐源，默认 netease
  /// [searchKeyword] 自定义搜索关键词，为空则使用歌曲标题
  Future<String?> fetchOnlineLyricForLocal(
    Track track, {
    String source = 'netease',
    String? searchKeyword,
  }) async {
    if (track.isRemote) return null;

    // 防止重复搜索
    if (_fetchingLyricIds.contains(track.id)) return null;
    _fetchingLyricIds.add(track.id);

    try {
      // 使用歌曲标题或自定义关键词搜索
      final keyword = searchKeyword ?? _extractSearchKeyword(track.title);
      final results = await _gdApi.search(
        keyword: keyword,
        source: source,
        count: 10,
      );

      // 选取最匹配的结果
      final match = _findBestLyricMatch(results, track.title);
      if (match == null) return null;

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
    } finally {
      _fetchingLyricIds.remove(track.id);
    }
  }

  /// 从文件名中提取搜索关键词
  /// 移除常见的无用信息如音质标记、括号内容等
  String _extractSearchKeyword(String title) {
    var keyword = title;

    // 移除括号及其内容 (xxx) [xxx] 【xxx】
    keyword = keyword.replaceAll(RegExp(r'[\(（\[【][^\)）\]】]*[\)）\]】]'), '');

    // 移除常见音质标记
    keyword = keyword.replaceAll(
      RegExp(r'(320k|128k|flac|ape|mp3|wav|hi-?res|无损)', caseSensitive: false),
      '',
    );

    // 移除多余空格
    keyword = keyword.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 如果处理后太短，返回原标题
    if (keyword.length < 2) return title;

    return keyword;
  }

  /// 从搜索结果中找到最匹配的歌词
  GdSearchTrack? _findBestLyricMatch(
    List<GdSearchTrack> results,
    String title,
  ) {
    if (results.isEmpty) return null;

    // 只考虑有歌词的结果
    final withLyric = results
        .where((r) => r.lyricId != null && r.lyricId!.isNotEmpty)
        .toList();
    if (withLyric.isEmpty) return null;

    // 简单匹配：标题包含关系
    final titleLower = title.toLowerCase();
    for (final r in withLyric) {
      final nameLower = r.name.toLowerCase();
      if (titleLower.contains(nameLower) || nameLower.contains(titleLower)) {
        return r;
      }
    }

    // 没有精确匹配，返回第一个有歌词的结果
    return withLyric.first;
  }

  Future<void> play() async {
    await _player.resume();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> seek(Duration d) async {
    final clamped = _clampDuration(d, Duration.zero, duration);
    await _player.seek(clamped);
  }

  Future<void> setVolume(double v) async {
    volume = v;
    await _player.setVolume(v);
  }

  Future<void> _handleComplete() async {
    // 调用外部注册的回调处理下一曲
    onTrackComplete?.call();
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
