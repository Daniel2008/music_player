import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../models/track.dart';
import '../services/gd_music_api.dart';
import '../services/lyric_service.dart';
import 'playlist_provider.dart';

class PlayerProvider extends ChangeNotifier {
  PlayerProvider({
    GdMusicApiClient? gdApi,
    bool Function()? shouldAutoFetchLocalLyric,
  }) : _gdApi = gdApi ?? GdMusicApiClient(),
       _ownsApi = gdApi == null,
       _shouldAutoFetchLocalLyric = shouldAutoFetchLocalLyric ?? (() => true) {
    _lyricService = LyricService(_gdApi);
    _lyricService.onLyricChanged = () => notifyListeners();
    _init();
  }
  final SoLoud _soloud = SoLoud.instance;
  GdMusicApiClient _gdApi;
  final bool _ownsApi;
  final bool Function() _shouldAutoFetchLocalLyric;
  late final LyricService _lyricService;

  AudioSource? _currentSource;
  SoundHandle? _currentHandle;
  Timer? _positionTimer;
  AudioData? _audioData;
  bool _disposed = false;

  FutureOr<void> Function()? onTrackComplete;

  GdMusicApiClient get gdApi => _gdApi;
  LyricService get lyricService => _lyricService;

  final ValueNotifier<double> volumeNotifier = ValueNotifier(1.0);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  late final Listenable timelineListenable = Listenable.merge([
    positionNotifier,
    durationNotifier,
  ]);

  double get volume => volumeNotifier.value;
  bool isPlaying = false;
  Duration get position => positionNotifier.value;
  Duration get duration => durationNotifier.value;

  bool isResolvingUrl = false;
  String? playError;
  int _resolveGeneration = 0;
  String playQuality = '320';

  // 均衡器状态持久化（切歌后重新应用）
  bool _equalizerEnabled = false;
  List<double> _equalizerGains = const [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5];

  // 可视化只消费 FFT 前半段，紧凑为 128 个采样点以降低常驻缓冲和复制量。
  final Float32List fftData = Float32List(128);
  final Set<Object> _visualizerConsumers = <Object>{};
  bool _initialized = false;

  void updateApiClient(GdMusicApiClient client) {
    _gdApi = client;
  }

  Future<void> _init() async {
    try {
      await _soloud.init();
      _soloud.setVisualizationEnabled(false);
      _soloud.setFftSmoothing(0.8);
      _audioData = AudioData(GetSamplesKind.linear);
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('SoLoud 初始化失败: $e');
    }
  }

  void _updateAudioData() {
    if (!_initialized ||
        _audioData == null ||
        _visualizerConsumers.isEmpty ||
        !isPlaying ||
        _currentHandle == null) {
      fftData.fillRange(0, fftData.length, 0);
      return;
    }
    try {
      _audioData!.updateSamples();
      final samples = _audioData!.getAudioData();
      if (samples.length >= fftData.length) {
        for (var i = 0; i < fftData.length; i++) {
          fftData[i] = samples[i];
        }
      }
    } catch (e) {
      debugPrint('更新音频数据失败: $e');
    }
  }

  void setVisualizationConsumerActive(Object consumer, bool active) {
    if (active) {
      _visualizerConsumers.add(consumer);
    } else {
      _visualizerConsumers.remove(consumer);
    }
    if (_visualizerConsumers.isEmpty) {
      fftData.fillRange(0, fftData.length, 0);
    }
    if (isPlaying) {
      _setVisualizationEnabled(_visualizerConsumers.isNotEmpty);
    }
  }

  void _setVisualizationEnabled(bool enabled) {
    if (!_initialized) return;
    try {
      _soloud.setVisualizationEnabled(enabled);
    } catch (e) {
      debugPrint('切换音频可视化失败: $e');
    }
  }

  /// 用于检测快速切歌竞态的计数器
  int _playGeneration = 0;

  Future<bool> playTrack(
    Track track, {
    bool preserveResolveGeneration = false,
  }) async {
    if (!_initialized) await _init();
    await stop(invalidateResolve: !preserveResolveGeneration);

    final myGeneration = ++_playGeneration;
    AudioSource? loadedSource;

    try {
      loadedSource = track.isRemote
          ? await _soloud.loadUrl(track.path, mode: LoadMode.disk)
          : await _soloud.loadFile(track.path, mode: LoadMode.disk);

      // 竞态保护：如果加载期间用户已切到下一首，释放这个孤儿 source
      if (myGeneration != _playGeneration) {
        try {
          await _soloud.disposeSource(loadedSource);
        } catch (_) {}
        return false;
      }

      _currentSource = loadedSource;
      _currentHandle = _soloud.play(_currentSource!);
      _setVisualizationEnabled(_visualizerConsumers.isNotEmpty);
      _soloud.setVolume(_currentHandle!, volume);
      // 重新应用均衡器 — 切歌后 filter 不在新 source 上生效
      if (_equalizerEnabled) {
        setEqualizer(true, _equalizerGains);
      }
      durationNotifier.value = _soloud.getLength(_currentSource!);
      isPlaying = true;
      positionNotifier.value = Duration.zero;
      playError = null;
      _startPositionTimer();
      notifyListeners();

      if (track.isRemote) {
        unawaited(_lyricService.ensureLyricCachedFor(track));
      } else if (_shouldAutoFetchLocalLyric()) {
        unawaited(_lyricService.autoFetchLyricForLocalTrack(track));
      }
      return true;
    } catch (e) {
      // 加载失败时也要确保释放可能已部分加载的资源
      if (myGeneration == _playGeneration) {
        playError = '播放失败: $e';
        _positionTimer?.cancel();
        _setVisualizationEnabled(false);
        isPlaying = false;
        fftData.fillRange(0, fftData.length, 0);
        notifyListeners();
      } else if (loadedSource != null) {
        try {
          await _soloud.disposeSource(loadedSource);
        } catch (_) {}
      }
      return false;
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed) return;
      if (!isPlaying || _currentHandle == null) {
        _positionTimer?.cancel();
        return;
      }
      if (_currentHandle != null && isPlaying) {
        try {
          if (!_soloud.getIsValidVoiceHandle(_currentHandle!)) {
            _handleComplete();
            return;
          }
          positionNotifier.value = _soloud.getPosition(_currentHandle!);
          _updateAudioData();
        } catch (e) {
          debugPrint('位置更新失败: $e');
        }
      }
    });
  }

  Future<bool> resolveAndPlayTrackUrl(
    GdSearchTrack item, {
    String br = '999',
    PlaylistProvider? playlistProvider,
  }) async {
    final requestGeneration = ++_resolveGeneration;
    final targetIndex = playlistProvider?.currentIndex;
    final targetTrackId = playlistProvider?.current?.id;
    isResolvingUrl = true;
    playError = null;
    notifyListeners();

    try {
      final url = await _gdApi.getTrackUrl(
        source: item.source,
        id: item.id,
        br: br,
      );
      if (requestGeneration != _resolveGeneration || _disposed) return false;

      if (playlistProvider != null &&
          (playlistProvider.currentIndex != targetIndex ||
              playlistProvider.current?.id != targetTrackId)) {
        return false;
      }

      final displayArtist = item.artistText;
      final title = displayArtist.isEmpty
          ? item.name
          : '${item.name} - $displayArtist';
      final artUri = _gdApi.buildCoverUrl(item.picId, item.source);

      if (playlistProvider != null) {
        final current = playlistProvider.current;
        final currentMatchesItem =
            current != null &&
            current.isRemote &&
            current.remoteSource == item.source &&
            current.remoteTrackId == item.id;
        if (currentMatchesItem) {
          final updatedTrack = current.copyWith(path: url.url, artUri: artUri);
          playlistProvider.updateTrackAt(
            playlistProvider.currentIndex,
            updatedTrack,
          );
          return await playTrack(updatedTrack, preserveResolveGeneration: true);
        }
      }

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
        lyricKey: 'gd_${item.source}_${item.lyricId ?? item.id}',
      );
      return await playTrack(track, preserveResolveGeneration: true);
    } catch (e) {
      if (requestGeneration == _resolveGeneration && !_disposed) {
        playError = _friendlyPlayError(e, source: item.source, br: br);
        notifyListeners();
      }
      return false;
    } finally {
      if (requestGeneration == _resolveGeneration) {
        isResolvingUrl = false;
        notifyListeners();
      }
    }
  }

  Future<void> playTrackSmart(
    Track track, {
    PlaylistProvider? playlistProvider,
    String? br,
  }) async {
    if (!track.isRemote) {
      await playTrack(track);
      return;
    }
    final quality = br ?? playQuality;
    if (track.path.isNotEmpty &&
        (track.path.startsWith('http://') ||
            track.path.startsWith('https://'))) {
      final played = await playTrack(track);
      if (played) return;
      if (track.remoteSource == null || track.remoteTrackId == null) return;
    }
    final source = track.remoteSource;
    final trackId = track.remoteTrackId;
    if (source == null || trackId == null) {
      playError = '无法播放：缺少远程曲目信息';
      notifyListeners();
      return;
    }
    final gdTrack = GdSearchTrack(
      id: trackId,
      name: track.title,
      artists: track.artist != null ? [track.artist!] : [],
      album: '',
      picId: null,
      lyricId: track.remoteLyricId,
      source: source,
    );
    await resolveAndPlayTrackUrl(
      gdTrack,
      br: quality,
      playlistProvider: playlistProvider,
    );
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

  Future<void> play() async {
    if (_currentHandle != null) {
      _soloud.setPause(_currentHandle!, false);
      _setVisualizationEnabled(_visualizerConsumers.isNotEmpty);
      isPlaying = true;
      _startPositionTimer();
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (_currentHandle != null) {
      _soloud.setPause(_currentHandle!, true);
      _positionTimer?.cancel();
      _setVisualizationEnabled(false);
      isPlaying = false;
      fftData.fillRange(0, fftData.length, 0);
      notifyListeners();
    }
  }

  Future<void> stop({bool invalidateResolve = true}) async {
    if (_disposed) return;
    _playGeneration++;
    if (invalidateResolve) {
      _resolveGeneration++;
      isResolvingUrl = false;
    }
    _positionTimer?.cancel();
    _setVisualizationEnabled(false);
    try {
      if (_currentHandle != null) {
        try {
          await _soloud.stop(_currentHandle!);
        } catch (e) {
          debugPrint('停止播放失败: $e');
        }
        _currentHandle = null;
      }
      if (_currentSource != null) {
        try {
          await _soloud.disposeSource(_currentSource!);
        } catch (e) {
          debugPrint('释放音频源失败: $e');
        }
        _currentSource = null;
      }
    } catch (e) {
      debugPrint('stop 整体异常: $e');
      _currentHandle = null;
      _currentSource = null;
    }
    isPlaying = false;
    positionNotifier.value = Duration.zero;
    durationNotifier.value = Duration.zero;
    fftData.fillRange(0, fftData.length, 0);
    notifyListeners();
  }

  Future<void> seek(Duration d) async {
    if (_currentHandle != null) {
      final clamped = _clampDuration(d, Duration.zero, duration);
      _soloud.seek(_currentHandle!, clamped);
      positionNotifier.value = clamped;
    }
  }

  Future<void> setVolume(double v) async {
    volumeNotifier.value = v;
    if (_currentHandle != null) _soloud.setVolume(_currentHandle!, v);
  }

  /// 启用均衡器（8段 peaking EQ，增益范围 0.0 ~ 4.0，1.0为无增益）
  void setEqualizer(bool enabled, List<double> gains) {
    _equalizerEnabled = enabled;
    _equalizerGains = List.unmodifiable(gains);
    try {
      final eq = _soloud.filters.parametricEqFilter;
      if (enabled) {
        if (!eq.isActive) {
          eq.activate();
        }
        // 确保 band 数足够（默认 3，需设 8 段 EQ）
        if (gains.length >= 8) {
          // getNumBands 受保护，绕过方法不可用；直接写 8（写入幂等）
          eq.numBands.value = 8;
          for (var i = 0; i < 8; i++) {
            eq.bandGain(i).value = _mapSliderToEq(gains[i]);
          }
        }
      } else {
        if (eq.isActive) {
          eq.deactivate();
        }
      }
    } catch (e) {
      debugPrint('设置均衡器失败: $e');
    }
  }

  double _mapSliderToEq(double sliderVal) {
    if (sliderVal <= 0.5) {
      return sliderVal * 2.0; // [0.0, 0.5] -> [0.0, 1.0]
    } else {
      return 1.0 + (sliderVal - 0.5) * 6.0; // (0.5, 1.0] -> (1.0, 4.0]
    }
  }

  Future<void> _handleComplete() async {
    _positionTimer?.cancel();
    _setVisualizationEnabled(false);

    // 释放已完成播放的音频资源 — 防止 native 内存泄漏
    try {
      if (_currentHandle != null) {
        try {
          await _soloud.stop(_currentHandle!);
        } catch (_) {}
        _currentHandle = null;
      }
      if (_currentSource != null) {
        try {
          await _soloud.disposeSource(_currentSource!);
        } catch (_) {}
        _currentSource = null;
      }
    } catch (_) {
      _currentHandle = null;
      _currentSource = null;
    }

    isPlaying = false;
    positionNotifier.value = Duration.zero;
    durationNotifier.value = Duration.zero;
    fftData.fillRange(0, fftData.length, 0);
    notifyListeners();
    if (onTrackComplete != null && !_disposed) {
      await onTrackComplete!.call();
    }
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max && max > Duration.zero) return max;
    return value;
  }

  @override
  void dispose() {
    _disposed = true;
    _positionTimer?.cancel();
    _setVisualizationEnabled(false);
    _audioData?.dispose();
    volumeNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    if (_currentSource != null) _soloud.disposeSource(_currentSource!);
    _soloud.deinit();
    if (_ownsApi) _gdApi.close();
    super.dispose();
  }
}
