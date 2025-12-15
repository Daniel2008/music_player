import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';

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
    final p = context.watch<PlayerProvider>();
    final pos = p.position.inMilliseconds;
    final dur = max(1, p.duration.inMilliseconds);
    final progress = (pos / dur).clamp(0.0, 1.0);

    final currentTitle = p.playlist.current?.title ?? '未选择歌曲';
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
            SizedBox(width: 52, child: Text(_fmt(p.position))),
            Expanded(
              child: Slider(
                value: progress,
                onChanged: (v) {
                  final seekMs = (v * dur).toInt();
                  p.seek(Duration(milliseconds: seekMs));
                },
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(_fmt(p.duration), textAlign: TextAlign.end),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: '上一首',
              onPressed: p.previous,
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              tooltip: p.isPlaying ? '暂停' : '播放',
              onPressed: p.isPlaying ? p.pause : p.play,
              icon: Icon(p.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              tooltip: '下一首',
              onPressed: p.next,
              icon: const Icon(Icons.skip_next),
            ),
            const Spacer(),
            const Icon(Icons.volume_up),
            SizedBox(
              width: 160,
              child: Slider(value: p.volume, onChanged: (v) => p.setVolume(v)),
            ),
          ],
        ),
      ],
    );
  }
}
