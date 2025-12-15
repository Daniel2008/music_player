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

  double volume = 1.0;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

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
    // 播放完成处理，需要由外部调用者处理下一曲逻辑
    // 因为播放列表管理已经移到了PlaylistProvider
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
