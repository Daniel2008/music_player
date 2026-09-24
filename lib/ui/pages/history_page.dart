import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../models/track.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<HistoryProvider>();
    final scheme = Theme.of(context).colorScheme;

    final history = historyProvider.history;

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: scheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无播放历史',
              style: TextStyle(color: scheme.outline, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '播放过的歌曲会出现在这里',
              style: TextStyle(
                color: scheme.outline.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '播放历史 (${history.length})',
                style: TextStyle(color: scheme.outline, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('清空'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _confirmClear(context, historyProvider),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            padding: const EdgeInsets.only(bottom: 16),
            itemBuilder: (context, index) {
              final track = history[index];
              return _HistoryItem(track: track, index: index);
            },
          ),
        ),
      ],
    );
  }

  void _confirmClear(BuildContext context, HistoryProvider hp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空播放历史'),
        content: const Text('确定要清空所有播放历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              hp.clear();
              Navigator.pop(ctx);
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatefulWidget {
  const _HistoryItem({required this.track, required this.index});
  final Track track;
  final int index;

  @override
  State<_HistoryItem> createState() => _HistoryItemState();
}

class _HistoryItemState extends State<_HistoryItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _isHovered
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : scheme.primaryContainer.withValues(alpha: 0.15))
              : Colors.transparent,
        ),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: scheme.primaryContainer.withValues(alpha: 0.5),
            ),
            child: Icon(
              Icons.music_note_rounded,
              size: 20,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.6),
            ),
          ),
          title: Text(
            widget.track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Text(
            widget.track.artist ?? '未知艺术家',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isHovered)
                IconButton(
                  icon: Icon(
                    Icons.play_circle_outline,
                    color: scheme.primary,
                    size: 22,
                  ),
                  tooltip: '播放',
                  onPressed: () => _playTrack(context),
                ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: scheme.outline.withValues(alpha: 0.5),
                ),
                tooltip: '移除',
                onPressed: () =>
                    context.read<HistoryProvider>().removeTrack(widget.index),
              ),
            ],
          ),
          onTap: () => _playTrack(context),
        ),
      ),
    );
  }

  void _playTrack(BuildContext context) {
    final playlistProvider = context.read<PlaylistProvider>();
    final playerProvider = context.read<PlayerProvider>();
    playlistProvider.addOrSelectTrack(widget.track);
    playerProvider.playTrackSmart(
      widget.track,
      playlistProvider: playlistProvider,
    );
  }
}
