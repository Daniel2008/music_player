import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';

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

  IconData get _modeIcon {
    switch (playlist.playMode) {
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

  String get _modeTooltip {
    switch (playlist.playMode) {
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

  Future<void> _togglePlayback() async {
    if (player.isPlaying) {
      await player.pause();
      return;
    }

    final current = playlist.current;
    if (current != null && player.duration == Duration.zero) {
      await player.playTrackSmart(current, playlistProvider: playlist);
    } else {
      await player.play();
    }
  }

  Future<void> _previous() async {
    playlist.previous();
    final current = playlist.current;
    if (current != null) {
      await player.playTrackSmart(current, playlistProvider: playlist);
    }
  }

  Future<void> _next() async {
    playlist.next();
    final current = playlist.current;
    if (current != null) {
      await player.playTrackSmart(current, playlistProvider: playlist);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sideButtonSize = compact ? 34.0 : 40.0;
    final playButtonSize = compact ? 42.0 : 54.0;
    final sideIconSize = compact ? 20.0 : 24.0;
    final playIconSize = compact ? 24.0 : 30.0;
    final modeActive = playlist.playMode != PlayMode.sequence;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMode)
          IconButton(
            onPressed: playlist.cyclePlayMode,
            tooltip: _modeTooltip,
            icon: Icon(
              _modeIcon,
              size: sideIconSize - 2,
              color: modeActive ? scheme.primary : scheme.onSurfaceVariant,
            ),
            style: IconButton.styleFrom(
              minimumSize: Size.square(sideButtonSize),
              backgroundColor: modeActive
                  ? scheme.primaryContainer.withValues(alpha: 0.65)
                  : Colors.transparent,
            ),
          ),
        if (showMode) SizedBox(width: compact ? 2 : 8),
        IconButton(
          onPressed: _previous,
          tooltip: '上一首',
          icon: Icon(Icons.skip_previous_rounded, size: sideIconSize),
          style: IconButton.styleFrom(minimumSize: Size.square(sideButtonSize)),
        ),
        SizedBox(width: compact ? 4 : 10),
        IconButton.filled(
          onPressed: _togglePlayback,
          tooltip: player.isPlaying ? '暂停' : '播放',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(player.isPlaying),
              size: playIconSize,
            ),
          ),
          style: IconButton.styleFrom(
            minimumSize: Size.square(playButtonSize),
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            elevation: 0,
          ),
        ),
        SizedBox(width: compact ? 4 : 10),
        IconButton(
          onPressed: _next,
          tooltip: '下一首',
          icon: Icon(Icons.skip_next_rounded, size: sideIconSize),
          style: IconButton.styleFrom(minimumSize: Size.square(sideButtonSize)),
        ),
      ],
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
    final scheme = Theme.of(context).colorScheme;

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
            trackHeight: widget.compact ? 2 : 3,
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

        return Row(
          children: [
            SizedBox(
              width: widget.compact ? 36 : 44,
              child: Text(
                _format(Duration(milliseconds: positions.round())),
                style: TextStyle(
                  fontSize: widget.compact ? 10 : 11,
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(child: slider),
            SizedBox(
              width: widget.compact ? 36 : 44,
              child: Text(
                _format(player.duration),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: widget.compact ? 10 : 11,
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
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
    final scheme = Theme.of(context).colorScheme;
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
            SizedBox(width: compact ? 2 : 6),
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
