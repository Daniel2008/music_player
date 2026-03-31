import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../widgets/visualizer_view.dart';
import '../widgets/lyric_view.dart';
import 'visualizer_fullscreen_page.dart';
import '../widgets/playlist_panel.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  // 当前选择的频谱样式
  VisualizerStyle _visualizerStyle = VisualizerStyle.bars;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final scheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (isWide) {
          return _buildWideLayout(context, scheme, isDark);
        }
        return _buildNarrowLayout(context, scheme, isDark);
      },
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 左侧: 频谱 + 歌词
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 10, 20),
            child: Column(
              children: [
                // 频谱卡片 — 主焦点
                Expanded(
                  flex: 3,
                  child: _buildVisualizerCard(context, scheme, isDark),
                ),
                const SizedBox(height: 12),
                // 歌词卡片
                Expanded(
                  flex: 2,
                  child: _buildLyricsCard(context, scheme, isDark),
                ),
              ],
            ),
          ),
        ),
        // 右侧: 播放列表
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 20, 20, 20),
            child: _buildPlaylistCard(context, scheme, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 频谱 — 主焦点
          SizedBox(
            height: 260,
            child: _buildVisualizerCard(context, scheme, isDark),
          ),
          const SizedBox(height: 12),
          // 歌词
          SizedBox(
            height: 220,
            child: _buildLyricsCard(context, scheme, isDark),
          ),
          const SizedBox(height: 12),
          // 播放列表
          SizedBox(
            height: 400,
            child: _buildPlaylistCard(context, scheme, isDark),
          ),
        ],
      ),
    );
  }

  /// 带发光边框的容器
  Widget _buildGlowCard({
    required Widget child,
    required ColorScheme scheme,
    required bool isDark,
    bool isMain = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        // 微光边框（暗色模式下更明显）
        border: isDark
            ? Border.all(
                color: isMain
                    ? scheme.primary.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
                width: 1,
              )
            : Border.all(
                color: Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
        color: isDark ? const Color(0xFF16161F) : scheme.surfaceContainer,
        boxShadow: [
          if (isDark && isMain)
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.06),
              blurRadius: 30,
              spreadRadius: -4,
            ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: child,
      ),
    );
  }

  Widget _buildVisualizerCard(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
  ) {
    return _buildGlowCard(
      scheme: scheme,
      isDark: isDark,
      isMain: true,
      child: Stack(
        children: [
          // 频谱视图
          Padding(
            padding: const EdgeInsets.all(16),
            child: VisualizerView(
              showStyleSelector: false,
              fixedStyle: _visualizerStyle,
            ),
          ),
          // 全屏按钮 — 左上角
          Positioned(
            top: 8,
            left: 8,
            child: _buildIconAction(
              icon: Icons.fullscreen_rounded,
              tooltip: '全屏显示频谱',
              scheme: scheme,
              isDark: isDark,
              onPressed: () {
                final playerProvider = context.read<PlayerProvider>();
                final playlistProvider = context.read<PlaylistProvider>();
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        MultiProvider(
                          providers: [
                            ChangeNotifierProvider.value(
                              value: playerProvider,
                            ),
                            ChangeNotifierProvider.value(
                              value: playlistProvider,
                            ),
                          ],
                          child: const VisualizerFullscreenPage(),
                        ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                );
              },
            ),
          ),
          // 效果选择 — 右上角
          Positioned(
            top: 8,
            right: 8,
            child: _buildStyleSelector(scheme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildIconAction({
    required IconData icon,
    required String tooltip,
    required ColorScheme scheme,
    required bool isDark,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyleSelector(ColorScheme scheme, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<VisualizerStyle>(
        tooltip: '频谱样式',
        initialValue: _visualizerStyle,
        icon: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Icon(
            _visualizerStyle.icon,
            size: 18,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        onSelected: (v) {
          setState(() => _visualizerStyle = v);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        itemBuilder: (context) => VisualizerStyle.values
            .map(
              (style) => PopupMenuItem(
                value: style,
                child: Row(
                  children: [
                    Icon(
                      style.icon,
                      size: 18,
                      color:
                          style == _visualizerStyle ? scheme.primary : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      style.displayName,
                      style: TextStyle(
                        color: style == _visualizerStyle
                            ? scheme.primary
                            : null,
                        fontWeight: style == _visualizerStyle
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildLyricsCard(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
  ) {
    return _buildGlowCard(
      scheme: scheme,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.lyrics_outlined,
                    size: 16,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '歌词',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: LyricView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
  ) {
    return _buildGlowCard(
      scheme: scheme,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.queue_music_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '播放列表',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: PlaylistPanel()),
        ],
      ),
    );
  }
}
