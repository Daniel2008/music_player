import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../widgets/visualizer_view.dart';
import '../widgets/lyric_view.dart';

class VisualizerFullscreenPage extends StatefulWidget {
  const VisualizerFullscreenPage({super.key});

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

  VisualizerStyle _currentStyle = VisualizerStyle.bars;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
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
    final scheme = Theme.of(context).colorScheme;
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
            if (hasValidIndex && player.duration == Duration.zero) {
              await player.playTrackSmart(
                playlist.current!,
                playlistProvider: playlist,
              );
            } else {
              player.play();
            }
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
              backgroundColor: Colors.black,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: double.infinity,
                                child: VisualizerView(
                                  showStyleSelector: false,
                                  fixedStyle: _currentStyle,
                                  enableGlow: true,
                                  showGuides: false,
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
                              duration: const Duration(milliseconds: 300),
                              opacity: _showLyrics ? 1.0 : 0.0,
                              child: Container(
                                margin: EdgeInsets.fromLTRB(
                                  24,
                                  0,
                                  24,
                                  bottomSafeInset + _bottomControlReserve,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.38),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: const LyricView(),
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
      color: Colors.black,
      child: CustomPaint(
        painter: _FullscreenBackdropPainter(
          primary: scheme.primary,
          secondary: scheme.secondary,
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
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (currentTrack?.artist != null)
                  Text(
                    currentTrack!.artist!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
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
            color: Colors.white,
            tooltip: '显示/隐藏歌词 (L)',
            onPressed: () => setState(() => _showLyrics = !_showLyrics),
          ),

          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close),
            color: Colors.white,
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
    // 安全获取当前曲目，防止索引越界
    final hasValidIndex =
        playlist.currentIndex >= 0 &&
        playlist.currentIndex < playlist.tracks.length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
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
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
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
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                        thumbColor: Colors.white,
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
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
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
                color: Colors.white,
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
                  color: scheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
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
                      // 安全检查后再播放
                      if (hasValidIndex && player.duration == Duration.zero) {
                        await player.playTrack(playlist.current!);
                      } else {
                        player.play();
                      }
                    }
                  },
                  tooltip: player.isPlaying ? '暂停 (空格)' : '播放 (空格)',
                ),
              ),

              const SizedBox(width: 8),

              // 下一曲
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 32),
                color: Colors.white,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '样式',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: SizedBox(
              width: 88,
              child: Wrap(
                spacing: 2,
                runSpacing: 2,
                children: VisualizerStyle.values.map((style) {
                  final isSelected = style == _currentStyle;
                  return Tooltip(
                    message: '${style.displayName} (S)',
                    child: InkWell(
                      onTap: () => setState(() => _currentStyle = style),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 42,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.primary.withValues(alpha: 0.3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          style == _currentStyle
                              ? Icons.check_rounded
                              : style.icon,
                          size: 18,
                          color: isSelected
                              ? scheme.primary
                              : Colors.white.withValues(alpha: 0.62),
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
    );
  }

  void _cycleStyle() {
    const styles = VisualizerStyle.values;
    final currentIndex = styles.indexOf(_currentStyle);
    final nextIndex = (currentIndex + 1) % styles.length;
    setState(() => _currentStyle = styles[nextIndex]);
  }
}

class _FullscreenBackdropPainter extends CustomPainter {
  const _FullscreenBackdropPainter({
    required this.primary,
    required this.secondary,
  });

  final Color primary;
  final Color secondary;

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
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 0.7;
    for (var i = 1; i < 8; i++) {
      final y = size.height * i / 8;
      canvas.drawLine(Offset(24, y), Offset(size.width - 24, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FullscreenBackdropPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.secondary != secondary;
}
