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

        if (isWide) {
          return _buildWideLayout(context, scheme);
        }
        return _buildNarrowLayout(context, scheme);
      },
    );
  }

  Widget _buildWideLayout(BuildContext context, ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 左侧: 频谱 + 歌词
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 12, 24),
            child: Column(
              children: [
                // 频谱卡片 - 占 2/3
                Expanded(flex: 2, child: _buildVisualizerCard(context, scheme)),
                const SizedBox(height: 16),
                // 歌词卡片 - 占 1/3
                Expanded(flex: 1, child: _buildLyricsCard(context, scheme)),
              ],
            ),
          ),
        ),
        // 右侧: 播放列表
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 24, 24, 24),
            child: _buildPlaylistCard(context, scheme),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, ColorScheme scheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 频谱 - 占更大比例
          SizedBox(height: 240, child: _buildVisualizerCard(context, scheme)),
          const SizedBox(height: 16),
          // 歌词 - 占较小比例
          SizedBox(height: 120, child: _buildLyricsCard(context, scheme)),
          const SizedBox(height: 16),
          // 播放列表
          SizedBox(height: 400, child: _buildPlaylistCard(context, scheme)),
        ],
      ),
    );
  }

  Widget _buildVisualizerCard(BuildContext context, ColorScheme scheme) {
    return Card(
      elevation: 0,
      color: scheme.surfaceContainer,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Stack(
        children: [
          // 频谱视图，使用外部管理的样式
          Padding(
            padding: const EdgeInsets.all(20),
            child: VisualizerView(
              showStyleSelector: false,
              fixedStyle: _visualizerStyle,
            ),
          ),
          // 全屏按钮 - 放在左上角
          Positioned(
            top: 8,
            left: 8,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: Icon(
                  Icons.fullscreen_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                tooltip: '全屏显示频谱',
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
          ),
          // 效果选择按钮 - 放在右上角
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: PopupMenuButton<VisualizerStyle>(
                tooltip: '频谱样式',
                initialValue: _visualizerStyle,
                icon: Icon(
                  _visualizerStyle.icon,
                  color: scheme.onSurfaceVariant,
                ),
                onSelected: (v) {
                  setState(() => _visualizerStyle = v);
                },
                itemBuilder: (context) => VisualizerStyle.values
                    .map(
                      (style) => PopupMenuItem(
                        value: style,
                        child: Row(
                          children: [
                            Icon(
                              style.icon,
                              size: 18,
                              color: style == _visualizerStyle
                                  ? scheme.primary
                                  : null,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsCard(BuildContext context, ColorScheme scheme) {
    return Card(
      elevation: 0,
      color: scheme.surfaceContainer,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Icon(Icons.lyrics_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  '歌词',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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

  Widget _buildPlaylistCard(BuildContext context, ColorScheme scheme) {
    return Card(
      elevation: 0,
      color: scheme.surfaceContainer,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Icon(
                  Icons.queue_music_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '播放列表',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
