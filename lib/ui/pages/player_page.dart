import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
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
                // 频谱卡片
                Expanded(flex: 2, child: _buildVisualizerCard(context, scheme)),
                const SizedBox(height: 24),
                // 歌词卡片
                Expanded(flex: 3, child: _buildLyricsCard(context, scheme)),
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
          // 频谱
          SizedBox(height: 180, child: _buildVisualizerCard(context, scheme)),
          const SizedBox(height: 16),
          // 歌词
          SizedBox(height: 300, child: _buildLyricsCard(context, scheme)),
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
          const Padding(padding: EdgeInsets.all(20), child: VisualizerView()),
          // 全屏按钮
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: Icon(
                  Icons.fullscreen_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                tooltip: '全屏显示频谱',
                onPressed: () {
                  final provider = context.read<PlayerProvider>();
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          ChangeNotifierProvider.value(
                            value: provider,
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
