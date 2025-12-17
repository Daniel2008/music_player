import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';

class Controls extends StatelessWidget {
  const Controls({super.key});

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();
    final pos = playerProvider.position.inMilliseconds;
    final dur = max(1, playerProvider.duration.inMilliseconds);
    final progress = (pos / dur).clamp(0.0, 1.0);

    // 安全获取当前曲目，防止索引越界
    final hasValidIndex =
        playlistProvider.currentIndex >= 0 &&
        playlistProvider.currentIndex < playlistProvider.tracks.length;
    final currentTitle = hasValidIndex
        ? playlistProvider.current?.title ?? '未选择歌曲'
        : '未选择歌曲';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(width: 52, child: Text(_fmt(playerProvider.position))),
            Expanded(
              child: Slider(
                value: progress,
                onChanged: (v) {
                  final seekMs = (v * dur).toInt();
                  playerProvider.seek(Duration(milliseconds: seekMs));
                },
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                _fmt(playerProvider.duration),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: '上一首',
              onPressed: () async {
                playlistProvider.previous();
                if (playlistProvider.currentIndex >= 0 &&
                    playlistProvider.currentIndex <
                        playlistProvider.tracks.length) {
                  await playerProvider.playTrack(playlistProvider.current!);
                }
              },
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              tooltip: playerProvider.isPlaying ? '暂停' : '播放',
              onPressed: playerProvider.isPlaying
                  ? playerProvider.pause
                  : playerProvider.play,
              icon: Icon(
                playerProvider.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
            IconButton(
              tooltip: '下一首',
              onPressed: () async {
                playlistProvider.next();
                if (playlistProvider.currentIndex >= 0 &&
                    playlistProvider.currentIndex <
                        playlistProvider.tracks.length) {
                  await playerProvider.playTrack(playlistProvider.current!);
                }
              },
              icon: const Icon(Icons.skip_next),
            ),
            const Spacer(),
            const Icon(Icons.volume_up),
            SizedBox(
              width: 160,
              child: Slider(
                value: playerProvider.volume,
                onChanged: (v) => playerProvider.setVolume(v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
