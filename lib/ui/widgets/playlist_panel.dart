import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';

/// 简化版播放列表面板，用于 PlayerPage
class PlaylistPanel extends StatelessWidget {
  const PlaylistPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final playlistProvider = context.watch<PlaylistProvider>();
    final playerProvider = context.watch<PlayerProvider>();
    final tracks = playlistProvider.playlist.tracks;
    final current = playlistProvider.current;
    final scheme = Theme.of(context).colorScheme;

    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music,
              size: 48,
              color: scheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text('播放列表为空', style: TextStyle(color: scheme.outline)),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonalIcon(
                  onPressed: playlistProvider.addFiles,
                  icon: const Icon(Icons.audio_file),
                  label: const Text('添加文件'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: playlistProvider.addFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('添加文件夹'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 列表头部
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                '${tracks.length} 首歌曲',
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
                        Icon(Icons.folder_open, size: 20),
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
        ),
        // 列表
        Expanded(
          child: ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final t = tracks[index];
              final isPlaying = current?.id == t.id;
              return ListTile(
                dense: true,
                selected: isPlaying,
                selectedTileColor: scheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                leading: isPlaying
                    ? Icon(Icons.play_arrow, color: scheme.primary, size: 20)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(color: scheme.outline),
                      ),
                title: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.close, size: 16, color: scheme.outline),
                  visualDensity: VisualDensity.compact,
                  tooltip: '移除',
                  onPressed: () => playlistProvider.removeTrack(index),
                ),
                onTap: () {
                  playlistProvider.setCurrentIndex(index);
                  if (playlistProvider.current != null) {
                    playerProvider.playTrack(playlistProvider.current!);
                  }
                },
              );
            },
          ),
        ),
      ],
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
