import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:smtc_windows/smtc_windows.dart';

import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../utils/logger.dart';

/// Windows 媒体传输控制（System Media Transport Controls）桥接服务
///
/// - 只在 Windows 平台生效
/// - 监听 PlayerProvider 状态变化 → 更新 SMTC 元数据/播放状态
/// - 接收 SMTC 媒体键事件 → 转发给 PlayerProvider / PlaylistProvider
class SmtcService {
  SmtcService(this._player, this._playlist);

  final PlayerProvider _player;
  final PlaylistProvider _playlist;

  SMTCWindows? _smtc;
  StreamSubscription? _buttonSub;
  bool _playerListening = false;
  bool _positionListening = false;
  bool _initialized = false;

  bool get isAvailable => _smtc != null;

  /// 初始化（应用启动时调用一次）
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!isWindows) return;

    try {
      await SMTCWindows.initialize();
      _smtc = SMTCWindows(
        metadata: const MusicMetadata(title: '', album: '', artist: ''),
        timeline: const PlaybackTimeline(
          startTimeMs: 0,
          endTimeMs: 0,
          positionMs: 0,
          minSeekTimeMs: 0,
          maxSeekTimeMs: 0,
        ),
        config: const SMTCConfig(
          fastForwardEnabled: true,
          nextEnabled: true,
          pauseEnabled: true,
          playEnabled: true,
          rewindEnabled: true,
          prevEnabled: true,
          stopEnabled: true,
        ),
      );

      _buttonSub = _smtc!.buttonPressStream.listen(_onButtonPressed);
      _player.addListener(_onPlayerChanged);
      _player.positionNotifier.addListener(_onPositionChanged);
      _playerListening = true;
      _positionListening = true;

      // 推送一次当前状态
      _onPlayerChanged();
      AppLog.i('SmtcService 初始化完成');
    } catch (e) {
      AppLog.w('SmtcService 初始化失败（可忽略）：$e');
      _smtc = null;
    }
  }

  void _onButtonPressed(PressedButton btn) {
    AppLog.d('SMTC 按键: $btn');
    switch (btn) {
      case PressedButton.play:
        _player.play();
        break;
      case PressedButton.pause:
        _player.pause();
        break;
      case PressedButton.next:
        unawaited(_skipAndPlay(next: true));
        break;
      case PressedButton.previous:
        unawaited(_skipAndPlay(next: false));
        break;
      case PressedButton.stop:
        _player.stop();
        break;
      case PressedButton.rewind:
      case PressedButton.fastForward:
      default:
        break;
    }
  }

  Future<void> _skipAndPlay({required bool next}) async {
    if (next) {
      _playlist.next();
    } else {
      _playlist.previous();
    }
    final track = _playlist.current;
    if (track != null) {
      await _player.playTrackSmart(
        track,
        playlistProvider: _playlist,
        br: _player.playQuality,
      );
    }
  }

  void _onPlayerChanged() {
    final smtc = _smtc;
    if (smtc == null) return;
    final track = _playlist.current;
    if (track != null) {
      smtc.updateMetadata(
        MusicMetadata(
          title: track.title,
          album: '',
          artist: track.artist ?? '',
          albumArtist: '',
        ),
      );
    }
    final hasTrack = track != null;
    smtc.setPlaybackStatus(
      _player.isPlaying
          ? PlaybackStatus.playing
          : !hasTrack
          ? PlaybackStatus.stopped
          : PlaybackStatus.paused,
    );

    _updateTimeline();
  }

  void _onPositionChanged() {
    _updateTimeline();
  }

  void _updateTimeline() {
    final smtc = _smtc;
    if (smtc == null) return;
    final pos = _player.position.inMilliseconds;
    final dur = _player.duration.inMilliseconds;
    smtc.updateTimeline(
      PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: dur,
        positionMs: pos,
        minSeekTimeMs: 0,
        maxSeekTimeMs: dur,
      ),
    );
  }

  Future<void> dispose() async {
    if (_playerListening) {
      _player.removeListener(_onPlayerChanged);
      _playerListening = false;
    }
    if (_positionListening) {
      _player.positionNotifier.removeListener(_onPositionChanged);
      _positionListening = false;
    }
    await _buttonSub?.cancel();
    _smtc?.dispose();
    _smtc = null;
    _initialized = false;
  }

  static bool get isWindows {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows;
  }
}
