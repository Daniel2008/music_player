import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';


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

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  IconData _getPlayModeIcon(PlayMode mode) {
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

  String _getPlayModeTooltip(PlayMode mode) {
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
    final playerProvider = context.watch<PlayerProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 安全获取当前曲目，防止索引越界
    final track =
        playlistProvider.currentIndex >= 0 &&
            playlistProvider.currentIndex < playlistProvider.tracks.length
        ? playlistProvider.current
        : null;

    // 空状态折叠
    if (track == null && !playerProvider.isPlaying) {
      return _buildEmptyState(context, scheme, isDark, playlistProvider);
    }

    final pos = playerProvider.position.inMilliseconds;
    final dur = max(1, playerProvider.duration.inMilliseconds);
    final progress = (pos / dur).clamp(0.0, 1.0);
    final sliderValue = _dragValue ?? progress;

    // 直接同步旋转动画
    if (playerProvider.isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!playerProvider.isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark ? const Color(0xFF1A1A26) : scheme.surfaceContainerHigh,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -2),
          ),
          if (isDark)
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.04),
              blurRadius: 40,
              offset: const Offset(0, -4),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 渐变进度条
          _buildGradientProgress(context, playerProvider, sliderValue, scheme),
          // 主内容区域
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Row(
              children: [
                // 专辑封面（旋转）
                _buildRotatingAlbumArt(track, playerProvider.isPlaying, scheme),
                const SizedBox(width: 14),
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

  /// 空状态 — 折叠成引导行
  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
    PlaylistProvider playlistProvider,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark
            ? const Color(0xFF1A1A26).withValues(alpha: 0.7)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer.withValues(alpha: 0.5),
            ),
            child: Icon(
              Icons.music_note_rounded,
              size: 16,
              color: scheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '添加音乐开始播放',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: playlistProvider.addFiles,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('添加'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientProgress(
    BuildContext context,
    PlayerProvider playerProvider,
    double sliderValue,
    ColorScheme scheme,
  ) {
    return SizedBox(
      height: 22,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          activeTrackColor: scheme.primary,
          inactiveTrackColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          thumbColor: scheme.primary,
          overlayColor: scheme.primary.withValues(alpha: 0.15),
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
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: isPlaying ? 0.25 : 0.1),
              blurRadius: isPlaying ? 16 : 8,
              offset: const Offset(0, 3),
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
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  placeholder: (ctx, url) => _buildAlbumPlaceholder(scheme),
                  errorWidget: (ctx, url, err) =>
                      _buildAlbumPlaceholder(scheme),
                )
              else
                _buildAlbumPlaceholder(scheme),
              // 中心唱片圆点
              Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
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
          size: 22,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.6),
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
            fontSize: 14,
            color: scheme.onSurface,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            if (track?.artist != null) ...[
              Flexible(
                child: Text(
                  track!.artist!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  '·',
                  style: TextStyle(
                    color: scheme.outline.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
            Text(
              _fmt(playerProvider.position),
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              ' / ',
              style: TextStyle(
                fontSize: 11,
                color: scheme.outline.withValues(alpha: 0.3),
              ),
            ),
            Text(
              _fmt(playerProvider.duration),
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
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
        // 播放模式按钮
        _buildPlayModeButton(context, scheme),
        const SizedBox(width: 2),
        // 上一首
        _buildControlButton(
          icon: Icons.skip_previous_rounded,
          tooltip: '上一首',
          onPressed: () async {
            playlistProvider.previous();
            if (playlistProvider.current != null) {
              await playerProvider.playTrackSmart(
                playlistProvider.current!,
                playlistProvider: playlistProvider,
              );
            }
          },
          scheme: scheme,
        ),
        const SizedBox(width: 6),
        // 播放/暂停
        _buildPlayPauseButton(playerProvider, playlistProvider, scheme),
        const SizedBox(width: 6),
        // 下一首
        _buildControlButton(
          icon: Icons.skip_next_rounded,
          tooltip: '下一首',
          onPressed: () async {
            playlistProvider.next();
            if (playlistProvider.current != null) {
              await playerProvider.playTrackSmart(
                playlistProvider.current!,
                playlistProvider: playlistProvider,
              );
            }
          },
          scheme: scheme,
        ),
      ],
    );
  }

  Widget _buildPlayModeButton(BuildContext context, ColorScheme scheme) {
    final playlistProvider = context.watch<PlaylistProvider>();
    final mode = playlistProvider.playMode;
    final isActive = mode != PlayMode.sequence;

    return Tooltip(
      message: _getPlayModeTooltip(mode),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => playlistProvider.cyclePlayMode(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? scheme.primaryContainer.withValues(alpha: 0.6)
                  : Colors.transparent,
            ),
            child: Icon(
              _getPlayModeIcon(mode),
              size: 17,
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
          hoverColor: scheme.primary.withValues(alpha: 0.08),
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton(
    PlayerProvider playerProvider,
    PlaylistProvider playlistProvider,
    ColorScheme scheme,
  ) {
    return Tooltip(
      message: playerProvider.isPlaying ? '暂停' : '播放',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (playerProvider.isPlaying) {
              await playerProvider.pause();
            } else {
              final current = playlistProvider.current;
              if (current != null && playerProvider.duration == Duration.zero) {
                await playerProvider.playTrackSmart(
                  current,
                  playlistProvider: playlistProvider,
                );
              } else {
                await playerProvider.play();
              }
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
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
                size: 26,
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
          width: 85,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: scheme.primary.withValues(alpha: 0.8),
              inactiveTrackColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
              thumbColor: scheme.primary,
              overlayColor: scheme.primary.withValues(alpha: 0.15),
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

    return Icon(icon, size: 18, color: scheme.outline.withValues(alpha: 0.7));
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
    final trackHeight = sliderTheme.trackHeight ?? 3;
    final trackLeft = offset.dx + 12;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width - 24;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
