import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';

/// 播放模式枚举
enum PlayMode {
  sequence, // 顺序播放
  loop, // 列表循环
  single, // 单曲循环
  shuffle, // 随机播放
}

/// 固定在底部的迷你播放控制栏
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  double? _dragValue;
  late final AnimationController _rotationController;
  PlayMode _playMode = PlayMode.sequence;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _updateRotation(bool isPlaying) {
    if (isPlaying) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
    }
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  void _cyclePlayMode() {
    setState(() {
      final modes = PlayMode.values;
      final nextIndex = (modes.indexOf(_playMode) + 1) % modes.length;
      _playMode = modes[nextIndex];
    });
    // TODO: 实际应用播放模式到播放器
  }

  IconData _getPlayModeIcon() {
    switch (_playMode) {
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

  String _getPlayModeTooltip() {
    switch (_playMode) {
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
    final playerProvider = context.watch<PlayerProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();
    final scheme = Theme.of(context).colorScheme;
    final track = playlistProvider.current;
    final pos = playerProvider.position.inMilliseconds;
    final dur = max(1, playerProvider.duration.inMilliseconds);
    final progress = (pos / dur).clamp(0.0, 1.0);
    final sliderValue = _dragValue ?? progress;

    // 更新旋转动画状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRotation(playerProvider.isPlaying);
    });

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: scheme.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 可拖动的进度条
          _buildProgressSlider(context, playerProvider, sliderValue, scheme),
          // 主内容区域
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                // 专辑封面（旋转）
                _buildRotatingAlbumArt(track, playerProvider.isPlaying, scheme),
                const SizedBox(width: 16),
                // 曲目信息
                Expanded(
                  flex: 2,
                  child: _buildTrackInfo(track, playerProvider, scheme),
                ),
                // 播放控制
                _buildPlayControls(playerProvider, playlistProvider, scheme),
                const SizedBox(width: 8),
                // 音量控制
                _buildVolumeControl(playerProvider, scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSlider(
    BuildContext context,
    PlayerProvider playerProvider,
    double sliderValue,
    ColorScheme scheme,
  ) {
    return SizedBox(
      height: 24,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: scheme.primary,
          inactiveTrackColor: scheme.surfaceContainerHighest,
          thumbColor: scheme.primary,
          overlayColor: scheme.primary.withValues(alpha: 0.2),
          trackShape: _RoundedTrackShape(),
        ),
        child: Slider(
          value: sliderValue,
          onChanged: (v) => setState(() => _dragValue = v),
          onChangeEnd: (v) {
            setState(() => _dragValue = null);
            final ms = (v * playerProvider.duration.inMilliseconds).round();
            playerProvider.seek(Duration(milliseconds: ms));
          },
        ),
      ),
    );
  }

  Widget _buildRotatingAlbumArt(
    dynamic track,
    bool isPlaying,
    ColorScheme scheme,
  ) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * pi,
          child: child,
        );
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            children: [
              // 专辑图片
              if (track?.artUri != null)
                CachedNetworkImage(
                  imageUrl: track!.artUri!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => _buildAlbumPlaceholder(scheme),
                  errorWidget: (ctx, url, err) =>
                      _buildAlbumPlaceholder(scheme),
                )
              else
                _buildAlbumPlaceholder(scheme),
              // 中心圆点（唱片效果）
              Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              // 播放状态指示
              if (isPlaying)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumPlaceholder(ColorScheme scheme) {
    return Container(
      color: scheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 24,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(
    dynamic track,
    PlayerProvider playerProvider,
    ColorScheme scheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          track?.title ?? '未选择歌曲',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (track?.artist != null) ...[
              Flexible(
                child: Text(
                  track!.artist!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '·',
                  style: TextStyle(
                    color: scheme.outline.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
            Text(
              _fmt(playerProvider.position),
              style: TextStyle(
                fontSize: 12,
                color: scheme.outline,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              ' / ',
              style: TextStyle(
                fontSize: 12,
                color: scheme.outline.withValues(alpha: 0.5),
              ),
            ),
            Text(
              _fmt(playerProvider.duration),
              style: TextStyle(
                fontSize: 12,
                color: scheme.outline,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayControls(
    PlayerProvider playerProvider,
    PlaylistProvider playlistProvider,
    ColorScheme scheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 播放模式按钮（合并了随机和循环）
        _buildPlayModeButton(scheme),
        const SizedBox(width: 4),
        // 上一首
        _buildControlButton(
          icon: Icons.skip_previous_rounded,
          tooltip: '上一首',
          onPressed: () async {
            playlistProvider.previous();
            if (playlistProvider.current != null) {
              await playerProvider.playTrack(playlistProvider.current!);
            }
          },
          scheme: scheme,
        ),
        const SizedBox(width: 8),
        // 播放/暂停
        _buildPlayPauseButton(playerProvider, scheme),
        const SizedBox(width: 8),
        // 下一首
        _buildControlButton(
          icon: Icons.skip_next_rounded,
          tooltip: '下一首',
          onPressed: () async {
            playlistProvider.next();
            if (playlistProvider.current != null) {
              await playerProvider.playTrack(playlistProvider.current!);
            }
          },
          scheme: scheme,
        ),
      ],
    );
  }

  Widget _buildPlayModeButton(ColorScheme scheme) {
    final isActive = _playMode != PlayMode.sequence;

    return Tooltip(
      message: _getPlayModeTooltip(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _cyclePlayMode,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? scheme.primaryContainer.withValues(alpha: 0.7)
                  : Colors.transparent,
            ),
            child: Icon(
              _getPlayModeIcon(),
              size: 18,
              color: isActive ? scheme.primary : scheme.outline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ColorScheme scheme,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: Icon(icon, size: 24, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton(
    PlayerProvider playerProvider,
    ColorScheme scheme,
  ) {
    return Tooltip(
      message: playerProvider.isPlaying ? '暂停' : '播放',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: playerProvider.isPlaying
              ? playerProvider.pause
              : playerProvider.play,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                playerProvider.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                key: ValueKey(playerProvider.isPlaying),
                size: 30,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeControl(
    PlayerProvider playerProvider,
    ColorScheme scheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVolumeIcon(playerProvider.volume, scheme),
        const SizedBox(width: 4),
        SizedBox(
          width: 90,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: scheme.primary,
              inactiveTrackColor: scheme.surfaceContainerHighest,
              thumbColor: scheme.primary,
              overlayColor: scheme.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: playerProvider.volume,
              onChanged: (v) => playerProvider.setVolume(v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeIcon(double volume, ColorScheme scheme) {
    IconData icon;
    if (volume == 0) {
      icon = Icons.volume_off_rounded;
    } else if (volume < 0.3) {
      icon = Icons.volume_mute_rounded;
    } else if (volume < 0.7) {
      icon = Icons.volume_down_rounded;
    } else {
      icon = Icons.volume_up_rounded;
    }

    return Icon(icon, size: 20, color: scheme.outline);
  }
}

/// 自定义圆角轨道形状
class _RoundedTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4;
    final trackLeft = offset.dx + 12;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width - 24;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
