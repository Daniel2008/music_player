import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/player_provider.dart';
import '../widgets/visualizer_view.dart';
import '../widgets/lyric_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  double? _dragValue;

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
                      // 顶部：正在播放（封面 + 控件）
                      _buildSection(
                        context,
                        title: '正在播放',
                        child: _nowPlayingCard(context),
                      ),
                      const SizedBox(height: 12),
                      // 下方：播放列表
                      _buildSection(
                        context,
                        title: '播放列表',
                        child: const PlaylistPanel(),
                        expanded: true,
                      ),
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
              // 在主页面中显示正在播放卡片（窄屏）
              _buildSection(
                context,
                title: '正在播放',
                child: _nowPlayingCard(context),
              ),
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
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withAlpha((0.5 * 255).round()),
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

  Widget _nowPlayingCard(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final track = p.playlist.current;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // 封面
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: track?.artUri != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: track!.artUri!,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => Container(
                      color: scheme.primaryContainer,
                      alignment: Alignment.center,
                      child: const SizedBox.shrink(),
                    ),
                    errorWidget: (ctx, url, err) => Container(
                      color: scheme.primaryContainer,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.music_note,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: scheme.primaryContainer,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.music_note,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 12),

        // 曲目信息 + 进度 + 控件
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track?.title ?? '未选择歌曲',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                track?.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.outline),
              ),
              const SizedBox(height: 8),
              // 进度条（可拖动 seek，拖拽仅在结束时调用真实 seek）
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: Builder(
                  builder: (ctx) {
                    final progress = p.duration.inMilliseconds == 0
                        ? 0.0
                        : (p.position.inMilliseconds /
                                  p.duration.inMilliseconds)
                              .clamp(0.0, 1.0);
                    final sliderValue = _dragValue ?? progress;
                    return Slider(
                      value: sliderValue,
                      onChanged: (v) => setState(() => _dragValue = v),
                      onChangeEnd: (v) {
                        setState(() => _dragValue = null);
                        final ms = (v * p.duration.inMilliseconds).round();
                        p.seek(Duration(milliseconds: ms));
                      },
                      activeColor: scheme.primary,
                      inactiveColor: scheme.surfaceContainerHighest,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    tooltip: '上一首',
                    onPressed: p.previous,
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(10),
                    ),
                    onPressed: p.isPlaying ? p.pause : p.play,
                    child: Icon(p.isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    tooltip: '下一首',
                    onPressed: p.next,
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
