import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
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

  @override
  void dispose() {
    _hideTimer?.cancel();
    _fadeController.dispose();
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
    final player = context.watch<PlayerProvider>();
    final playlist = context.watch<PlaylistProvider>();
    final currentTrack = playlist.current;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop();
        },
        const SingleActivator(LogicalKeyboardKey.space): () {
          player.isPlaying ? player.pause() : player.play();
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          final newPos = player.position - const Duration(seconds: 5);
          player.seek(newPos < Duration.zero ? Duration.zero : newPos);
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
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
                          flex: _showLyrics ? 6 : 10,
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
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 歌词区域
                        if (_showLyrics)
                          Expanded(
                            flex: 4,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: _showLyrics ? 1.0 : 0.0,
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(
                                  24,
                                  0,
                                  24,
                                  24,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: scheme.outlineVariant.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
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
                      child: _buildBottomControls(
                        context,
                        scheme,
                        player,
                        playlist,
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
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            scheme.primary.withValues(alpha: 0.15),
            scheme.secondary.withValues(alpha: 0.08),
            Colors.black,
          ],
          stops: const [0.0, 0.5, 1.0],
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
          Row(
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
                    value: player.duration.inMilliseconds > 0
                        ? (player.position.inMilliseconds /
                                  player.duration.inMilliseconds)
                              .clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (value) {
                      final newPosition = Duration(
                        milliseconds: (value * player.duration.inMilliseconds)
                            .round(),
                      );
                      player.seek(newPosition);
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
                  if (playlist.current != null) {
                    await player.playTrack(playlist.current!);
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
                  onPressed: () =>
                      player.isPlaying ? player.pause() : player.play(),
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
                  if (playlist.current != null) {
                    await player.playTrack(playlist.current!);
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
          ...VisualizerStyle.values.map((style) {
            final isSelected = style == _currentStyle;
            return Tooltip(
              message: '${style.displayName} (S)',
              child: InkWell(
                onTap: () => setState(() => _currentStyle = style),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    style.icon,
                    size: 20,
                    color: isSelected
                        ? scheme.primary
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _cycleStyle() {
    final styles = VisualizerStyle.values;
    final currentIndex = styles.indexOf(_currentStyle);
    final nextIndex = (currentIndex + 1) % styles.length;
    setState(() => _currentStyle = styles[nextIndex]);
  }
}
