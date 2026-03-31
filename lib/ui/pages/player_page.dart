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
  VisualizerStyle _visualizerStyle = VisualizerStyle.bars;

  // 折叠状态
  bool _lyricsExpanded = true;
  bool _playlistExpanded = true;

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
          flex: _playlistExpanded ? 3 : 5,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, _playlistExpanded ? 10 : 20, 20),
            child: Column(
              children: [
                // 频谱卡片 — 歌词折叠后自动占满
                Expanded(
                  flex: _lyricsExpanded ? 3 : 1,
                  child: _buildVisualizerCard(context, scheme, isDark),
                ),
                // 歌词卡片 — 可折叠
                if (_lyricsExpanded) ...[
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 2,
                    child: _buildLyricsCard(context, scheme, isDark),
                  ),
                ],
              ],
            ),
          ),
        ),
        // 右侧: 播放列表 — 可折叠
        if (_playlistExpanded)
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
          // 歌词 — 可折叠
          _buildCollapsibleCard(
            title: '歌词',
            icon: Icons.lyrics_outlined,
            isExpanded: _lyricsExpanded,
            onToggle: () => setState(() => _lyricsExpanded = !_lyricsExpanded),
            scheme: scheme,
            isDark: isDark,
            expandedChild: SizedBox(
              height: 220,
              child: _buildLyricsContent(),
            ),
          ),
          const SizedBox(height: 12),
          // 播放列表 — 可折叠
          _buildCollapsibleCard(
            title: '播放列表',
            icon: Icons.queue_music_rounded,
            isExpanded: _playlistExpanded,
            onToggle: () => setState(() => _playlistExpanded = !_playlistExpanded),
            scheme: scheme,
            isDark: isDark,
            expandedChild: const SizedBox(
              height: 400,
              child: PlaylistPanel(),
            ),
          ),
        ],
      ),
    );
  }

  /// 窄布局用的可折叠卡片
  Widget _buildCollapsibleCard({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required ColorScheme scheme,
    required bool isDark,
    required Widget expandedChild,
  }) {
    return _buildGlowCard(
      scheme: scheme,
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSectionHeader(
            title: title,
            icon: icon,
            isExpanded: isExpanded,
            onToggle: onToggle,
            scheme: scheme,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded ? expandedChild : const SizedBox.shrink(),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: VisualizerView(
              showStyleSelector: false,
              fixedStyle: _visualizerStyle,
            ),
          ),
          // 全屏按钮
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
          // 右上角控制按钮组
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 歌词折叠按钮
                _buildIconAction(
                  icon: _lyricsExpanded
                      ? Icons.lyrics_rounded
                      : Icons.lyrics_outlined,
                  tooltip: _lyricsExpanded ? '收起歌词' : '展开歌词',
                  scheme: scheme,
                  isDark: isDark,
                  onPressed: () => setState(() => _lyricsExpanded = !_lyricsExpanded),
                ),
                const SizedBox(width: 6),
                // 播放列表折叠按钮
                _buildIconAction(
                  icon: _playlistExpanded
                      ? Icons.playlist_remove_rounded
                      : Icons.playlist_play_rounded,
                  tooltip: _playlistExpanded ? '收起播放列表' : '展开播放列表',
                  scheme: scheme,
                  isDark: isDark,
                  onPressed: () => setState(() => _playlistExpanded = !_playlistExpanded),
                ),
                const SizedBox(width: 6),
                // 频谱样式
                _buildStyleSelector(scheme, isDark),
              ],
            ),
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

  /// 通用的可折叠区块头部
  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required ColorScheme scheme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: isExpanded ? 0.0 : -0.25,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 22,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 歌词卡片（宽布局 — 带可折叠头部）
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
          _buildSectionHeader(
            title: '歌词',
            icon: Icons.lyrics_outlined,
            isExpanded: _lyricsExpanded,
            onToggle: () => setState(() => _lyricsExpanded = !_lyricsExpanded),
            scheme: scheme,
          ),
          Expanded(child: _buildLyricsContent()),
        ],
      ),
    );
  }

  /// 歌词内容
  Widget _buildLyricsContent() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: LyricView(),
    );
  }

  /// 播放列表卡片（宽布局 — 带可折叠头部）
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
          _buildSectionHeader(
            title: '播放列表',
            icon: Icons.queue_music_rounded,
            isExpanded: _playlistExpanded,
            onToggle: () => setState(() => _playlistExpanded = !_playlistExpanded),
            scheme: scheme,
          ),
          const Expanded(child: PlaylistPanel()),
        ],
      ),
    );
  }
}
