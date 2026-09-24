import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../providers/history_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../widgets/app_surfaces.dart';

class HistoryWorkspacePage extends StatelessWidget {
  const HistoryWorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<HistoryProvider>();
    final history = historyProvider.history;

    return Column(
      children: [
        AppPageHeader(
          title: '播放历史',
          subtitle: '${history.length} 条最近播放记录',
          eyebrow: '音乐库',
          icon: Icons.history_rounded,
          actions: [
            if (history.isNotEmpty)
              TextButton.icon(
                onPressed: () => _confirmClear(context, historyProvider),
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('清空'),
              ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: AppPanel(
              padding: EdgeInsets.zero,
              child: history.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.history_toggle_off_rounded,
                      title: '暂无播放历史',
                      description: '播放过的歌曲会按最近使用顺序显示在这里。',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: history.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 2),
                      itemBuilder: (context, index) =>
                          _HistoryRow(track: history[index], index: index),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmClear(BuildContext context, HistoryProvider provider) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空播放历史'),
        content: const Text('确定要清空所有播放历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              provider.clear();
              Navigator.pop(dialogContext);
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.track, required this.index});

  final Track track;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = [
      if (track.artist != null && track.artist!.isNotEmpty) track.artist!,
      if (track.duration != null) _formatDuration(track.duration!),
    ].join('  ·  ');

    return AppMediaRow(
      title: track.title,
      subtitle: subtitle.isEmpty ? '本地音乐' : subtitle,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Icon(
          Icons.music_note_rounded,
          size: 19,
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => context.read<HistoryProvider>().removeTrack(index),
            tooltip: '从历史中移除',
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
          IconButton.filled(
            onPressed: () => _play(context),
            tooltip: '播放',
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
          ),
        ],
      ),
      onTap: () => _play(context),
    );
  }

  void _play(BuildContext context) {
    final playlist = context.read<PlaylistProvider>();
    final player = context.read<PlayerProvider>();
    playlist.addOrSelectTrack(track);
    player.playTrackSmart(track, playlistProvider: playlist);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
