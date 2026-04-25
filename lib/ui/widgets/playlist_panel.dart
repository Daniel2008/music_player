import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../models/track.dart';

/// 简化版播放列表面板，用于 PlayerPage
class PlaylistPanel extends StatefulWidget {
  const PlaylistPanel({super.key});

  @override
  State<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends State<PlaylistPanel> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledTrackId;
  bool _userJustClicked = false;

  /// itemExtent — 让 ReorderableListView 强制每项高度 = 56 px
  static const double _itemExtent = 56.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动到指定索引（居中）
  void _scrollToIndex(int targetIndex, int totalTracks) {
    if (targetIndex < 0 || targetIndex >= totalTracks) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final targetOffset = targetIndex * _itemExtent;
      final maxOffset = _scrollController.position.maxScrollExtent;
      final viewportHeight = _scrollController.position.viewportDimension;

      final centeredOffset =
          (targetOffset - viewportHeight / 2 + _itemExtent / 2)
              .clamp(0.0, maxOffset);

      // 避免无效滚动
      if ((centeredOffset - _scrollController.offset).abs() < 2.0) return;

      _scrollController.animateTo(
        centeredOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlistProvider = context.watch<PlaylistProvider>();
    final tracks = playlistProvider.playlist.tracks;

    final hasValidIndex =
        playlistProvider.currentIndex >= 0 &&
        playlistProvider.currentIndex < tracks.length;
    final current = hasValidIndex ? playlistProvider.current : null;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 自动滚动 — 只要曲目 ID 变了就触发
    if (hasValidIndex && !_userJustClicked && current != null) {
      if (current.id != _lastScrolledTrackId) {
        _lastScrolledTrackId = current.id;
        _scrollToIndex(playlistProvider.currentIndex, tracks.length);
      }
    }
    _userJustClicked = false;

    if (tracks.isEmpty) {
      return _buildEmptyState(playlistProvider, scheme);
    }

    return Column(
      children: [
        _buildHeader(playlistProvider, scheme, context),
        Expanded(
          child: ReorderableListView.builder(
            scrollController: _scrollController,
            itemCount: tracks.length,
            itemExtent: _itemExtent,
            onReorder: playlistProvider.reorderTrack,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final elevation = Tween<double>(begin: 0, end: 8)
                      .animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ))
                      .value;
                  final scale = Tween<double>(begin: 1.0, end: 1.03)
                      .animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ))
                      .value;
                  return Transform.scale(
                    scale: scale,
                    child: Material(
                      elevation: elevation,
                      borderRadius: BorderRadius.circular(12),
                      shadowColor: scheme.primary.withValues(alpha: 0.3),
                      child: child,
                    ),
                  );
                },
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final t = tracks[index];
              final isPlaying = current?.id == t.id;
              return _PlaylistTrackTile(
                key: ValueKey(t.id),
                track: t,
                index: index,
                isPlaying: isPlaying,
                isDark: isDark,
                onTap: () {
                  _userJustClicked = true;
                  playlistProvider.setCurrentIndex(index);
                  final playerProvider = context.read<PlayerProvider>();
                  if (playlistProvider.currentIndex >= 0 &&
                      playlistProvider.currentIndex < tracks.length) {
                    playerProvider.playTrackSmart(
                      playlistProvider.current!,
                      playlistProvider: playlistProvider,
                    );
                  }
                },
                onRemove: () => playlistProvider.removeTrack(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    PlaylistProvider playlistProvider,
    ColorScheme scheme,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '${playlistProvider.tracks.length} 首歌曲',
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add, size: 20),
            tooltip: '添加音乐',
            onSelected: (v) {
              if (v == 'files') playlistProvider.addFiles();
              if (v == 'folder') playlistProvider.addFolder();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'files',
                child: Row(
                  children: [
                    Icon(Icons.audio_file, size: 20),
                    SizedBox(width: 8),
                    Text('添加文件'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'folder',
                child: Row(
                  children: [
                    Icon(Icons.create_new_folder, size: 20),
                    SizedBox(width: 8),
                    Text('添加文件夹'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '清空列表',
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmClear(context, playlistProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(PlaylistProvider playlistProvider, ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.5),
                  scheme.tertiaryContainer.withValues(alpha: 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.queue_music_rounded,
              size: 28,
              color: scheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '播放列表为空',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '添加本地音乐或搜索在线歌曲',
            style: TextStyle(
              color: scheme.outline.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonalIcon(
                onPressed: playlistProvider.addFiles,
                icon: const Icon(Icons.audio_file, size: 18),
                label: const Text('添加文件'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: playlistProvider.addFolder,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('添加文件夹'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, PlaylistProvider playlistProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空播放列表'),
        content: const Text('确定要清空播放列表吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              playlistProvider.clear();
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// 播放列表中的单个曲目条目
class _PlaylistTrackTile extends StatelessWidget {
  final Track track;
  final int index;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PlaylistTrackTile({
    super.key,
    required this.track,
    required this.index,
    required this.isPlaying,
    required this.isDark,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isPlaying
            ? scheme.primaryContainer.withValues(alpha: isDark ? 0.25 : 0.35)
            : Colors.transparent,
        border: isPlaying
            ? Border.all(
                color: scheme.primary.withValues(alpha: 0.2),
                width: 1,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: scheme.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // 序号或播放图标
                SizedBox(
                  width: 28,
                  child: isPlaying
                      ? _PlayingIndicator(color: scheme.primary)
                      : Text(
                          '${index + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.outline,
                            fontSize: 13,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                // 歌曲标题
                Expanded(
                  child: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                      color: isPlaying ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
                // 操作按钮
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: scheme.outline),
                  visualDensity: VisualDensity.compact,
                  tooltip: '移除',
                  onPressed: onRemove,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle,
                    size: 18,
                    color: scheme.outline.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 正在播放的呼吸动画指示器
class _PlayingIndicator extends StatefulWidget {
  final Color color;

  const _PlayingIndicator({required this.color});

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _bar(0.5 + 0.5 * _controller.value, 3),
            const SizedBox(width: 2),
            _bar(1.0 - 0.4 * _controller.value, 3),
            const SizedBox(width: 2),
            _bar(0.3 + 0.7 * _controller.value, 3),
          ],
        );
      },
    );
  }

  Widget _bar(double heightFactor, double width) {
    return Container(
      width: width,
      height: 14 * heightFactor,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
