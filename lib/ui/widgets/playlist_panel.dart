import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../models/track.dart';
import 'app_surfaces.dart';

/// 播放工作区右侧的紧凑播放列表面板。
class PlaylistPanel extends StatefulWidget {
  const PlaylistPanel({super.key});

  @override
  State<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends State<PlaylistPanel> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledTrackId;
  bool _userJustClicked = false;

  /// itemExtent — 为双行文本和拖拽操作保留稳定的 60 px 行高
  static const double _itemExtent = 60.0;

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
          (targetOffset - viewportHeight / 2 + _itemExtent / 2).clamp(
            0.0,
            maxOffset,
          );

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
    final playerIsPlaying = context.select<PlayerProvider, bool>(
      (provider) => provider.isPlaying,
    );

    // 自动滚动 — 只要曲目 ID 变了就触发
    if (hasValidIndex && !_userJustClicked && current != null) {
      if (current.id != _lastScrolledTrackId) {
        _lastScrolledTrackId = current.id;
        _scrollToIndex(playlistProvider.currentIndex, tracks.length);
      }
    }
    _userJustClicked = false;

    if (tracks.isEmpty) {
      return _buildCompactEmptyState(playlistProvider);
    }

    return Column(
      children: [
        _buildHeader(playlistProvider, scheme, context),
        Expanded(
          child: ReorderableListView.builder(
            scrollController: _scrollController,
            itemCount: tracks.length,
            itemExtent: _itemExtent,
            // ignore: deprecated_member_use
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;
              playlistProvider.reorderTrack(oldIndex, newIndex);
            },
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final elevation = Tween<double>(begin: 0, end: 8)
                      .animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      )
                      .value;
                  final scale = Tween<double>(begin: 1.0, end: 1.03)
                      .animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      )
                      .value;
                  return Transform.scale(
                    scale: scale,
                    child: Material(
                      elevation: elevation,
                      borderRadius: BorderRadius.circular(8),
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
              return _CompactPlaylistTrackTile(
                key: ValueKey(t.id),
                track: t,
                index: index,
                isPlaying: isPlaying,
                isActive: isPlaying && playerIsPlaying,
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
      padding: const EdgeInsets.fromLTRB(4, 0, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: AppSectionTitle(
              title: '播放队列',
              subtitle: '${playlistProvider.tracks.length} 首歌曲',
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_rounded, size: 19),
            tooltip: '添加音乐',
            onSelected: (v) {
              if (v == 'files') playlistProvider.addFiles();
              if (v == 'folder') playlistProvider.addFolder();
              if (v == 'import') playlistProvider.importM3u();
              if (v == 'export') playlistProvider.exportM3u();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'files',
                child: Row(
                  children: [
                    Icon(Icons.audio_file, size: 20),
                    SizedBox(width: 8),
                    Text('添加文件'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'folder',
                child: Row(
                  children: [
                    Icon(Icons.create_new_folder, size: 20),
                    SizedBox(width: 8),
                    Text('添加文件夹'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_open, size: 20),
                    SizedBox(width: 8),
                    Text('导入 M3U'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                enabled: playlistProvider.tracks.isNotEmpty,
                child: const Row(
                  children: [
                    Icon(Icons.save_alt, size: 20),
                    SizedBox(width: 8),
                    Text('导出 M3U'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 19),
            tooltip: '清空列表',
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmClear(context, playlistProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactEmptyState(PlaylistProvider playlistProvider) {
    return AppEmptyState(
      icon: Icons.queue_music_rounded,
      title: '播放队列为空',
      description: '添加本地文件或从在线搜索中加入歌曲。',
      action: FilledButton.tonalIcon(
        onPressed: playlistProvider.addFiles,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('添加音乐'),
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

class _CompactPlaylistTrackTile extends StatefulWidget {
  const _CompactPlaylistTrackTile({
    super.key,
    required this.track,
    required this.index,
    required this.isPlaying,
    required this.isActive,
    required this.onTap,
    required this.onRemove,
  });

  final Track track;
  final int index;
  final bool isPlaying;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  State<_CompactPlaylistTrackTile> createState() =>
      _CompactPlaylistTrackTileState();
}

class _CompactPlaylistTrackTileState extends State<_CompactPlaylistTrackTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final track = widget.track;
    final subtitle = track.artist == null || track.artist!.isEmpty
        ? (track.isRemote ? '在线音乐' : '本地音乐')
        : track.artist!;
    final showRemove = _hovered;
    final showDragHandle = _hovered || widget.isPlaying;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AppMediaRow(
        title: track.title,
        subtitle: subtitle,
        selected: widget.isPlaying,
        onTap: widget.onTap,
        leading: SizedBox(
          width: 26,
          child: widget.isPlaying
              ? widget.isActive
                    ? _PlayingIndicator(color: scheme.primary)
                    : Icon(Icons.pause_rounded, size: 16, color: scheme.primary)
              : Text(
                  '${widget.index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
        ),
        trailing: SizedBox(
          width: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedOpacity(
                opacity: showRemove ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: IgnorePointer(
                  ignoring: !showRemove,
                  child: _PlaylistRemoveButton(
                    color: scheme.onSurfaceVariant,
                    hoverColor: scheme.error,
                    onPressed: widget.onRemove,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              AnimatedOpacity(
                opacity: showDragHandle ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: IgnorePointer(
                  ignoring: !showDragHandle,
                  child: ReorderableDragStartListener(
                    index: widget.index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Tooltip(
                        message: '拖拽排序',
                        child: Container(
                          width: 26,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _hovered
                                ? scheme.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            size: 17,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: _hovered ? 0.9 : 0.55,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistRemoveButton extends StatelessWidget {
  const _PlaylistRemoveButton({
    required this.color,
    required this.hoverColor,
    required this.onPressed,
  });

  final Color color;
  final Color hoverColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: '从队列移除',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 26, height: 30),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: color,
        hoverColor: hoverColor.withValues(alpha: 0.1),
        highlightColor: hoverColor.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: const Icon(Icons.close_rounded, size: 15),
    );
  }
}

/// 播放列表中的单个曲目条目
// ignore: unused_element
class _PlaylistTrackTile extends StatelessWidget {
  const _PlaylistTrackTile({
    required this.track,
    required this.index,
    required this.isPlaying,
    required this.isDark,
    required this.onTap,
    required this.onRemove,
  });
  final Track track;
  final int index;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isPlaying
            ? scheme.primaryContainer.withValues(alpha: isDark ? 0.25 : 0.35)
            : Colors.transparent,
        border: isPlaying
            ? Border.all(color: scheme.primary.withValues(alpha: 0.2), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
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
                          style: TextStyle(color: scheme.outline, fontSize: 13),
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
                      fontWeight: isPlaying
                          ? FontWeight.w600
                          : FontWeight.normal,
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
  const _PlayingIndicator({required this.color});
  final Color color;

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
