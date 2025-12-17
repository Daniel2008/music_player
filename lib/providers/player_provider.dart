import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';
import '../services/gd_music_api.dart';
import 'playlist_provider.dart';

class PlayerProvider extends ChangeNotifier {
  final SoLoud _soloud = SoLoud.instance;
  final GdMusicApiClient _gdApi = GdMusicApiClient();

  AudioSource? _currentSource;
  SoundHandle? _currentHandle;
  Timer? _positionTimer;
  AudioData? _audioData;

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

  // FFT 数据（用于频谱可视化）
  Float32List fftData = Float32List(256);
  Float32List waveData = Float32List(256);

  // 是否已初始化
  bool _initialized = false;

  PlayerProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _soloud.init();
      _soloud.setVisualizationEnabled(true);
      _soloud.setFftSmoothing(0.8);
      _audioData = AudioData(GetSamplesKind.linear);
      _initialized = true;
      notifyListeners();
    } catch (e) {
      // 静默处理初始化失败
    }
  }

  /// 更新 FFT 和波形数据
  void _updateAudioData() {
    if (!_initialized || _audioData == null || !isPlaying) {
      fftData = Float32List(256);
      waveData = Float32List(256);
      return;
    }

    try {
      _audioData!.updateSamples();
      final samples = _audioData!.getAudioData();
      if (samples.length >= 512) {
        fftData = samples.sublist(0, 256);
        waveData = samples.sublist(256, 512);
      }
    } catch (e) {
      // 静默处理错误，避免频繁打印日志
    }
  }

  Future<void> playTrack(Track track) async {
    if (!_initialized) {
      await _init();
    }

    await stop();

    try {
      if (track.isRemote) {
        // 远程 URL
        _currentSource = await _soloud.loadUrl(track.path);
      } else {
        // 本地文件
        final path = await _resolveSourcePath(track.path);
        _currentSource = await _soloud.loadFile(path);
      }

      if (_currentSource != null) {
        _currentHandle = await _soloud.play(_currentSource!);
        _soloud.setVolume(_currentHandle!, volume);

        // 获取时长
        duration = _soloud.getLength(_currentSource!);
        isPlaying = true;
        position = Duration.zero;
        playError = null;

        // 启动位置更新定时器
        _startPositionTimer();

        notifyListeners();

        // 处理歌词
        if (track.isRemote) {
          unawaited(_ensureLyricCachedFor(track));
        } else if (autoFetchLyricForLocal) {
          unawaited(_autoFetchLyricForLocalTrack(track));
        }
      }
    } catch (e) {
      playError = '播放失败: $e';
      isPlaying = false;
      notifyListeners();
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 50), (
      _,
    ) async {
      if (_currentHandle != null && isPlaying) {
        try {
          // 检查句柄是否有效
          if (!_soloud.getIsValidVoiceHandle(_currentHandle!)) {
            // 播放完成
            _handleComplete();
            return;
          }

          final pos = _soloud.getPosition(_currentHandle!);
          position = pos;

          // 更新 FFT 数据
          _updateAudioData();

          notifyListeners();
        } catch (e) {
          // 忽略错误
        }
      }
    });
  }

  Future<String> _resolveSourcePath(String path) async {
    return path;
  }

  /// 解析并播放在线曲目
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
          await playTrack(updatedTrack);
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

  Future<void> _autoFetchLyricForLocalTrack(Track track) async {
    if (track.isRemote) return;

    final localLrcPath = await _getLocalLrcPath(track);
    if (localLrcPath != null) return;

    if (localLyricPaths.containsKey(track.id)) return;

    if (_fetchingLyricIds.contains(track.id)) return;

    await fetchOnlineLyricForLocal(track);
  }

  Future<String?> _getLocalLrcPath(Track track) async {
    final audioPath = track.path;
    final name = audioPath.replaceAll(RegExp(r"\.[^/.]+$"), '');
    final lrcLocal = '$name.lrc';
    if (await File(lrcLocal).exists()) return lrcLocal;

    final dir = await getApplicationSupportDirectory();
    final cachedPath = '${dir.path}/local_${track.id}.lrc';
    if (await File(cachedPath).exists()) return cachedPath;

    return null;
  }

  Future<String?> fetchOnlineLyricForLocal(
    Track track, {
    String source = 'netease',
    String? searchKeyword,
  }) async {
    if (track.isRemote) return null;

    if (_fetchingLyricIds.contains(track.id)) return null;
    _fetchingLyricIds.add(track.id);

    try {
      final keyword = searchKeyword ?? _extractSearchKeyword(track.title);
      final results = await _gdApi.search(
        keyword: keyword,
        source: source,
        count: 10,
      );

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

  String _extractSearchKeyword(String title) {
    var keyword = title;
    keyword = keyword.replaceAll(RegExp(r'[\(（\[【][^\)）\]】]*[\)）\]】]'), '');
    keyword = keyword.replaceAll(
      RegExp(r'(320k|128k|flac|ape|mp3|wav|hi-?res|无损)', caseSensitive: false),
      '',
    );
    keyword = keyword.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (keyword.length < 2) return title;
    return keyword;
  }

  GdSearchTrack? _findBestLyricMatch(
    List<GdSearchTrack> results,
    String title,
  ) {
    if (results.isEmpty) return null;

    final withLyric = results
        .where((r) => r.lyricId != null && r.lyricId!.isNotEmpty)
        .toList();
    if (withLyric.isEmpty) return null;

    final titleLower = title.toLowerCase();
    for (final r in withLyric) {
      final nameLower = r.name.toLowerCase();
      if (titleLower.contains(nameLower) || nameLower.contains(titleLower)) {
        return r;
      }
    }

    return withLyric.first;
  }

  Future<void> play() async {
    if (_currentHandle != null) {
      _soloud.setPause(_currentHandle!, false);
      isPlaying = true;
      _startPositionTimer();
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (_currentHandle != null) {
      _soloud.setPause(_currentHandle!, true);
      isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _positionTimer?.cancel();
    if (_currentHandle != null) {
      try {
        await _soloud.stop(_currentHandle!);
      } catch (e) {
        // 忽略错误
      }
      _currentHandle = null;
    }
    if (_currentSource != null) {
      try {
        await _soloud.disposeSource(_currentSource!);
      } catch (e) {
        // 忽略错误
      }
      _currentSource = null;
    }
    isPlaying = false;
    position = Duration.zero;
    fftData = Float32List(256);
    waveData = Float32List(256);
    notifyListeners();
  }

  Future<void> seek(Duration d) async {
    if (_currentHandle != null) {
      final clamped = _clampDuration(d, Duration.zero, duration);
      _soloud.seek(_currentHandle!, clamped);
      position = clamped;
      notifyListeners();
    }
  }

  Future<void> setVolume(double v) async {
    volume = v;
    if (_currentHandle != null) {
      _soloud.setVolume(_currentHandle!, v);
    }
    notifyListeners();
  }

  Future<void> _handleComplete() async {
    _positionTimer?.cancel();
    isPlaying = false;
    position = Duration.zero;
    fftData = Float32List(256);
    waveData = Float32List(256);
    notifyListeners();
    onTrackComplete?.call();
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max && max > Duration.zero) return max;
    return value;
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _audioData?.dispose();
    _gdApi.close();
    if (_currentSource != null) {
      _soloud.disposeSource(_currentSource!);
    }
    _soloud.deinit();
    super.dispose();
  }
}
