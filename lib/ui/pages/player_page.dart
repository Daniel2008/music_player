import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../widgets/visualizer_view.dart';
import '../widgets/lyric_view.dart';
import 'visualizer_fullscreen_page.dart';
import '../widgets/playlist_panel.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return Row(
            children: [
              // 左侧：频谱 + 歌词
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSection(
                        context,
                        title: '频谱可视化',
                        trailing: IconButton(
                          icon: const Icon(Icons.fullscreen),
                          tooltip: '全屏显示频谱',
                          onPressed: () {
                            final provider = context.read<PlayerProvider>();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider.value(
                                  value: provider,
                                  child: const VisualizerFullscreenPage(),
                                ),
                              ),
                            );
                          },
                        ),
                        child: const SizedBox(
                          height: 200,
                          child: VisualizerView(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        context,
                        title: '歌词',
                        child: const LyricView(),
                        expanded: true,
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              // 右侧：播放列表 + 均衡器
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSection(
                        context,
                        title: '播放列表',
                        child: const PlaylistPanel(),
                        expanded: true,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // 窄屏：垂直布局
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSection(
                context,
                title: '频谱可视化',
                trailing: IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: '全屏显示频谱',
                  onPressed: () {
                    final provider = context.read<PlayerProvider>();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: provider,
                          child: const VisualizerFullscreenPage(),
                        ),
                      ),
                    );
                  },
                ),
                child: const SizedBox(height: 160, child: VisualizerView()),
              ),
              const SizedBox(height: 12),
              _buildSection(
                context,
                title: '歌词',
                child: const SizedBox(height: 150, child: LyricView()),
              ),
              const SizedBox(height: 12),
              _buildSection(
                context,
                title: '播放列表',
                child: const SizedBox(height: 250, child: PlaylistPanel()),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 80), // 底部留空给 MiniPlayer
            ],
          ),
        );
      },
    );
  }

  // 均衡器已移除

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? trailing,
    bool expanded = false,
  }) {
    Widget content = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (trailing != null) ...[const Spacer(), trailing],
              ],
            ),
            const SizedBox(height: 12),
            expanded ? Expanded(child: child) : child,
          ],
        ),
      ),
    );

    return expanded ? Expanded(child: content) : content;
  }
}
