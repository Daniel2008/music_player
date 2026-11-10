import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../theme/app_design.dart';
import '../widgets/visualizer_view.dart';
import '../widgets/lyric_view.dart';

class VisualizerFullscreenPage extends StatefulWidget {
  const VisualizerFullscreenPage({
    super.key,
    this.initialStyle = VisualizerStyle.bars,
    this.onStyleChanged,
  });

  final VisualizerStyle initialStyle;
  final ValueChanged<VisualizerStyle>? onStyleChanged;

  @override
  State<VisualizerFullscreenPage> createState() =>
      _VisualizerFullscreenPageState();
}

class _VisualizerFullscreenPageState extends State<VisualizerFullscreenPage>
    with SingleTickerProviderStateMixin {
  static const double _bottomControlReserve = 148;

  bool _showControls = true;
  bool _showLyrics = true;
  Timer? _hideTimer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late VisualizerStyle _currentStyle;

  @override
  void initState() {
    super.initState();
    _currentStyle = widget.initialStyle;
    _fadeController = AnimationController(
      vsync: this,
      duration: AppMotion.medium,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.value = 1.0;

    _startHideTimer();

    // 进入真正全屏
    windowManager.setFullScreen(true);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
        _fadeController.reverse();
      }
    });
  }

  void _onInteraction() {
    if (!_showControls) {
      setState(() => _showControls = true);
      _fadeController.forward();
    }
    _startHideTimer();
  }

  void _exitFullscreen() {
    windowManager.setFullScreen(false);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _fadeController.dispose();
    _exitFullscreen();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final visual = context.visual;
    final bottomSafeInset = MediaQuery.of(context).padding.bottom;
    final playlist = context.watch<PlaylistProvider>();

    // 安全获取当前曲目，防止索引越界
    final hasValidIndex =
        playlist.currentIndex >= 0 &&
        playlist.currentIndex < playlist.tracks.length;
    final currentTrack = hasValidIndex ? playlist.current : null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop();
        },
        const SingleActivator(LogicalKeyboardKey.space): () async {
          final player = context.read<PlayerProvider>();
          if (player.isPlaying) {
            player.pause();
          } else {
            await player.playOrResume(currentTrack, playlistProvider: playlist);
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          final player = context.read<PlayerProvider>();
          final newPos = player.position - const Duration(seconds: 5);
          player.seek(newPos < Duration.zero ? Duration.zero : newPos);
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          final player = context.read<PlayerProvider>();
          player.seek(player.position + const Duration(seconds: 5));
        },
        const SingleActivator(LogicalKeyboardKey.keyL): () {
          setState(() => _showLyrics = !_showLyrics);
        },
        const SingleActivator(LogicalKeyboardKey.keyS): () {
          _cycleStyle();
        },
      },
      child: Focus(
        autofocus: true,
        child: MouseRegion(
          onHover: (_) => _onInteraction(),
          child: GestureDetector(
            onTap: _onInteraction,
            behavior: HitTestBehavior.opaque,
            child: Scaffold(
              backgroundColor: scheme.surface,
              body: Stack(
                children: [
                  // 动态背景
                  _buildAnimatedBackground(scheme),

                  // 主内容
                  SafeArea(
                    child: Column(
                      children: [
                        // 频谱可视化
                        Expanded(
                          flex: _showLyrics ? 5 : 10,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                            child: Center(
                              child: SizedBox(
                                width: double.infinity,
                                child: VisualizerView(
                                  showStyleSelector: false,
                                  fixedStyle: _currentStyle,
                                  enableGlow: true,
                                  showGuides: true,
                                  maxFps: 30,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 歌词区域
                        if (_showLyrics)
                          Expanded(
                            flex: 5,
                            child: AnimatedOpacity(
                              duration: AppMotion.medium,
                              opacity: _showLyrics ? 1.0 : 0.0,
                              child: Container(
                                margin: EdgeInsets.fromLTRB(
                                  AppSpacing.xxl,
                                  0,
                                  AppSpacing.xxl,
                                  bottomSafeInset + _bottomControlReserve,
                                ),
                                decoration: BoxDecoration(
                                  color: visual.overlay,
                                  borderRadius: AppRadius.lgAll,
                                  border: Border.all(color: visual.border),
                                  boxShadow: AppShadows.soft(
                                    visual.shadow.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: const ClipRRect(
                                  borderRadius: AppRadius.lgAll,
                                  child: LyricView(),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 顶部控制栏
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildTopBar(context, scheme, currentTrack),
                    ),
                  ),

                  // 底部播放控制
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Consumer<PlayerProvider>(
                        builder: (context, player, _) {
                          return _buildBottomControls(
                            context,
                            scheme,
                            player,
                            playlist,
                          );
                        },
                      ),
                    ),
                  ),

                  // 样式选择器
                  Positioned(
                    right: 16,
                    top: MediaQuery.of(context).padding.top + 60,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildStyleSelector(scheme),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.surface,
      child: CustomPaint(
        painter: _FullscreenBackdropPainter(
          primary: scheme.primary,
          secondary: scheme.secondary,
          gridColor: scheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    ColorScheme scheme,
    dynamic currentTrack,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.of(context).padding.top + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.visual.scrim, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: scheme.onSurface,
            tooltip: '退出全屏 (Esc)',
            onPressed: () => Navigator.of(context).pop(),
          ),

          const SizedBox(width: 16),

          // 歌曲信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentTrack?.title ?? '未在播放',
                  style: context.textStyles.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (currentTrack?.artist != null)
                  Text(
                    currentTrack!.artist!,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // 歌词切换按钮
          IconButton(
            icon: Icon(
              _showLyrics ? Icons.subtitles : Icons.subtitles_off_outlined,
            ),
            color: scheme.onSurface,
            tooltip: '显示/隐藏歌词 (L)',
            onPressed: () => setState(() => _showLyrics = !_showLyrics),
          ),

          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close),
            color: scheme.onSurface,
            tooltip: '关闭 (Esc)',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(
    BuildContext context,
    ColorScheme scheme,
    PlayerProvider player,
    PlaylistProvider playlist,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [context.visual.scrim, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          AnimatedBuilder(
            animation: player.timelineListenable,
            builder: (context, _) {
              final durationMs = player.duration.inMilliseconds;
              final positionMs = player.position.inMilliseconds;
              return Row(
                children: [
                  Text(
                    _formatDuration(player.position),
                    style: context.textStyles.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        activeTrackColor: scheme.primary,
                        inactiveTrackColor: scheme.outlineVariant,
                        thumbColor: scheme.primary,
                        overlayColor: scheme.primary.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: durationMs > 0
                            ? (positionMs / durationMs).clamp(0.0, 1.0)
                            : 0.0,
                        onChanged: (value) {
                          player.seek(
                            Duration(
                              milliseconds: (value * durationMs).round(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDuration(player.duration),
                    style: context.textStyles.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 8),

          // 播放控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 48), // 占位

              const SizedBox(width: 16),

              // 上一曲
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, size: 32),
                color: scheme.onSurface,
                onPressed: () async {
                  playlist.previous();
                  final current = playlist.current;
                  if (current != null) {
                    await player.playTrackSmart(
                      current,
                      playlistProvider: playlist,
                    );
                  }
                },
                tooltip: '上一曲',
              ),

              const SizedBox(width: 8),

              // 播放/暂停
              Container(
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
                  boxShadow: AppShadows.glow(scheme.primary, alpha: 0.35),
                ),
                child: IconButton(
                  icon: Icon(
                    player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 36,
                  ),
                  color: scheme.onPrimary,
                  onPressed: () async {
                    if (player.isPlaying) {
                      player.pause();
                    } else {
                      await player.playOrResume(
                        playlist.current,
                        playlistProvider: playlist,
                      );
                    }
                  },
                  tooltip: player.isPlaying ? '暂停 (空格)' : '播放 (空格)',
                ),
              ),

              const SizedBox(width: 8),

              // 下一曲
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 32),
                color: scheme.onSurface,
                onPressed: () async {
                  playlist.next();
                  final current = playlist.current;
                  if (current != null) {
                    await player.playTrackSmart(
                      current,
                      playlistProvider: playlist,
                    );
                  }
                },
                tooltip: '下一曲',
              ),

              const SizedBox(width: 16),

              const SizedBox(width: 48), // 占位
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStyleSelector(ColorScheme scheme) {
    final visual = context.visual;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.55,
      ),
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: visual.overlay,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: visual.border),
            boxShadow: AppShadows.soft(visual.shadow.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  '样式',
                  style: context.textStyles.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm - 2,
                  0,
                  AppSpacing.sm - 2,
                  AppSpacing.sm - 2,
                ),
                child: SizedBox(
                  width: 88,
                  child: Wrap(
                    spacing: AppSpacing.xxs,
                    runSpacing: AppSpacing.xxs,
                    children: VisualizerStyle.values.map((style) {
                      final isSelected = style == _currentStyle;
                      return Tooltip(
                        message: '${style.displayName} (S)',
                        child: InkWell(
                          onTap: () {
                            setState(() => _currentStyle = style);
                            widget.onStyleChanged?.call(style);
                          },
                          borderRadius: AppRadius.smAll,
                          hoverColor: visual.hover,
                          child: AnimatedContainer(
                            duration: AppMotion.fast,
                            curve: AppMotion.curve,
                            width: 42,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? visual.selected
                                  : Colors.transparent,
                              borderRadius: AppRadius.smAll,
                              border: Border.all(
                                color: isSelected
                                    ? scheme.primary.withValues(alpha: 0.3)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Icon(
                              isSelected ? Icons.check_rounded : style.icon,
                              size: 18,
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _cycleStyle() {
    const styles = VisualizerStyle.values;
    final currentIndex = styles.indexOf(_currentStyle);
    final nextIndex = (currentIndex + 1) % styles.length;
    final nextStyle = styles[nextIndex];
    setState(() => _currentStyle = nextStyle);
    widget.onStyleChanged?.call(nextStyle);
  }
}

class _FullscreenBackdropPainter extends CustomPainter {
  const _FullscreenBackdropPainter({
    required this.primary,
    required this.secondary,
    required this.gridColor,
  });

  final Color primary;
  final Color secondary;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.46);
    final maxRadius = math.min(size.width, size.height) * 0.72;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 1; i <= 5; i++) {
      final radius = maxRadius * i / 5;
      paint.color = Color.lerp(
        primary,
        secondary,
        i / 5,
      )!.withValues(alpha: 0.035 + (5 - i) * 0.006);
      canvas.drawCircle(center, radius, paint);
    }

    paint
      ..color = gridColor.withValues(
        alpha: gridColor.computeLuminance() > 0.5 ? 0.08 : 0.035,
      )
      ..strokeWidth = 0.7;
    for (var i = 1; i < 8; i++) {
      final y = size.height * i / 8;
      canvas.drawLine(Offset(24, y), Offset(size.width - 24, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FullscreenBackdropPainter oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.gridColor != gridColor;
}
