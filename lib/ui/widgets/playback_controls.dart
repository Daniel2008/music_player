import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../theme/app_design.dart';

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({
    super.key,
    required this.player,
    required this.playlist,
    this.compact = false,
    this.showMode = true,
  });

  final PlayerProvider player;
  final PlaylistProvider playlist;
  final bool compact;
  final bool showMode;

  Future<void> _togglePlayback(BuildContext context) async {
    if (player.isPlaying) {
      await player.pause();
      return;
    }

    final ok = await player.playOrResume(
      playlist.current,
      playlistProvider: playlist,
    );
    if (context.mounted) _reportIfFailed(context, ok);
  }

  Future<void> _previous(BuildContext context) async {
    playlist.previous();
    final current = playlist.current;
    if (current != null) {
      final ok = await player.playTrackSmart(
        current,
        playlistProvider: playlist,
      );
      if (context.mounted) _reportIfFailed(context, ok);
    }
  }

  Future<void> _next(BuildContext context) async {
    playlist.next();
    final current = playlist.current;
    if (current != null) {
      final ok = await player.playTrackSmart(
        current,
        playlistProvider: playlist,
      );
      if (context.mounted) _reportIfFailed(context, ok);
    }
  }

  /// 播放失败时弹出提示，避免用户点击后没有任何反馈。
  void _reportIfFailed(BuildContext context, bool ok) {
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(player.playError ?? '播放失败')));
  }

  @override
  Widget build(BuildContext context) {
    final sideButtonSize = compact ? 34.0 : 40.0;
    final playButtonSize = compact ? 42.0 : 54.0;
    final sideIconSize = compact ? 20.0 : 24.0;
    final playIconSize = compact ? 24.0 : 30.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMode)
          _PlaybackModeButton(
            playlist: playlist,
            size: sideButtonSize,
            iconSize: sideIconSize - 2,
          ),
        if (showMode) const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: () => _previous(context),
          tooltip: '上一首',
          icon: Icon(Icons.skip_previous_rounded, size: sideIconSize),
          style: IconButton.styleFrom(minimumSize: Size.square(sideButtonSize)),
        ),
        SizedBox(width: compact ? AppSpacing.xs : AppSpacing.sm + 2),
        _PlayPauseButton(
          player: player,
          onPressed: () => _togglePlayback(context),
          size: playButtonSize,
          iconSize: playIconSize,
        ),
        SizedBox(width: compact ? AppSpacing.xs : AppSpacing.sm + 2),
        IconButton(
          onPressed: () => _next(context),
          tooltip: '下一首',
          icon: Icon(Icons.skip_next_rounded, size: sideIconSize),
          style: IconButton.styleFrom(minimumSize: Size.square(sideButtonSize)),
        ),
      ],
    );
  }
}

class _PlaybackModeButton extends StatelessWidget {
  const _PlaybackModeButton({
    required this.playlist,
    required this.size,
    required this.iconSize,
  });

  final PlaylistProvider playlist;
  final double size;
  final double iconSize;

  IconData _iconFor(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return Icons.arrow_forward_rounded;
      case PlayMode.loop:
        return Icons.repeat_rounded;
      case PlayMode.single:
        return Icons.repeat_one_rounded;
      case PlayMode.shuffle:
        return Icons.shuffle_rounded;
    }
  }

  String _tooltipFor(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return '顺序播放';
      case PlayMode.loop:
        return '列表循环';
      case PlayMode.single:
        return '单曲循环';
      case PlayMode.shuffle:
        return '随机播放';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return ListenableBuilder(
      listenable: playlist,
      builder: (context, _) {
        final mode = playlist.playMode;
        final active = mode != PlayMode.sequence;
        return IconButton(
          onPressed: playlist.cyclePlayMode,
          tooltip: _tooltipFor(mode),
          icon: Icon(
            _iconFor(mode),
            size: iconSize,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
          style: IconButton.styleFrom(
            minimumSize: Size.square(size),
            backgroundColor: active
                ? scheme.primaryContainer.withValues(alpha: 0.7)
                : Colors.transparent,
          ),
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.player,
    required this.onPressed,
    required this.size,
    required this.iconSize,
  });

  final PlayerProvider player;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final isPlaying = player.isPlaying;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary,
                Color.lerp(scheme.primary, scheme.tertiary, 0.55)!,
              ],
            ),
            boxShadow: AppShadows.glow(scheme.primary, alpha: 0.3),
          ),
          child: IconButton.filled(
            onPressed: onPressed,
            tooltip: isPlaying ? '暂停' : '播放',
            icon: AnimatedSwitcher(
              duration: AppMotion.fast,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(isPlaying),
                size: iconSize,
              ),
            ),
            style: IconButton.styleFrom(
              minimumSize: Size.square(size),
              backgroundColor: Colors.transparent,
              foregroundColor: scheme.onPrimary,
              shape: const CircleBorder(),
              elevation: 0,
            ),
          ),
        );
      },
    );
  }
}

class PlaybackTimeline extends StatefulWidget {
  const PlaybackTimeline({
    super.key,
    required this.player,
    this.showTimeLabels = true,
    this.compact = false,
  });

  final PlayerProvider player;
  final bool showTimeLabels;
  final bool compact;

  @override
  State<PlaybackTimeline> createState() => _PlaybackTimelineState();
}

class _PlaybackTimelineState extends State<PlaybackTimeline> {
  double? _dragValue;

  String _format(Duration duration) {
    String two(int value) => value.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final base = '${two(minutes)}:${two(seconds)}';
    return hours > 0 ? '${two(hours)}:$base' : base;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return AnimatedBuilder(
      animation: widget.player.timelineListenable,
      builder: (context, _) {
        final player = widget.player;
        final durationMs = player.duration.inMilliseconds;
        final progress = durationMs <= 0
            ? 0.0
            : (player.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
        final value = (_dragValue ?? progress).clamp(0.0, 1.0);
        final positions = value * durationMs;

        final slider = SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: widget.compact ? 3 : 4,
            activeTrackColor: scheme.primary,
            inactiveTrackColor: scheme.surfaceContainerHighest.withValues(
              alpha: 0.78,
            ),
            thumbColor: scheme.primary,
            overlayColor: scheme.primary.withValues(alpha: 0.14),
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: widget.compact ? 4 : 6,
            ),
            overlayShape: RoundSliderOverlayShape(
              overlayRadius: widget.compact ? 10 : 14,
            ),
            trackShape: const _PlaybackTrackShape(),
          ),
          child: Slider(
            value: value,
            onChanged: durationMs <= 0
                ? null
                : (next) => setState(() => _dragValue = next),
            onChangeEnd: durationMs <= 0
                ? null
                : (next) {
                    setState(() => _dragValue = null);
                    widget.player.seek(
                      Duration(milliseconds: (next * durationMs).round()),
                    );
                  },
          ),
        );

        if (!widget.showTimeLabels) {
          return SizedBox(height: widget.compact ? 20 : 28, child: slider);
        }

        final labelStyle = context.textStyles.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

        return Row(
          children: [
            SizedBox(
              width: widget.compact ? 36 : 44,
              child: Text(
                _format(Duration(milliseconds: positions.round())),
                style: labelStyle,
              ),
            ),
            Expanded(child: slider),
            SizedBox(
              width: widget.compact ? 36 : 44,
              child: Text(
                _format(player.duration),
                textAlign: TextAlign.end,
                style: labelStyle,
              ),
            ),
          ],
        );
      },
    );
  }
}

class PlaybackVolume extends StatelessWidget {
  const PlaybackVolume({super.key, required this.player, this.compact = false});

  final PlayerProvider player;
  final bool compact;

  IconData _icon(double value) {
    if (value <= 0.001) return Icons.volume_off_rounded;
    if (value < 0.45) return Icons.volume_mute_rounded;
    if (value < 1.05) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return ValueListenableBuilder<double>(
      valueListenable: player.volumeNotifier,
      builder: (context, value, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon(value),
              size: compact ? 17 : 19,
              color: scheme.onSurfaceVariant,
            ),
            SizedBox(width: compact ? AppSpacing.xxs : AppSpacing.xs + 2),
            SizedBox(
              width: compact ? 72 : 112,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: compact ? 4 : 5,
                  ),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: compact ? 9 : 11,
                  ),
                ),
                child: Slider(
                  value: value.clamp(0, 2),
                  max: 2,
                  onChanged: player.setVolume,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlaybackTrackShape extends RoundedRectSliderTrackShape {
  const _PlaybackTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 3.0;
    final trackLeft = offset.dx + 8;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = math.max(0.0, parentBox.size.width - 16);
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
