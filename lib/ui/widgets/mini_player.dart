import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';

/// 固定在底部的迷你播放控制栏
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  double? _dragValue;

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

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
    final scheme = Theme.of(context).colorScheme;
    final track = p.playlist.current;
    final pos = p.position.inMilliseconds;
    final dur = max(1, p.duration.inMilliseconds);
    final progress = (pos / dur).clamp(0.0, 1.0);
    final sliderValue = _dragValue ?? progress;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          SizedBox(
            height: 24,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: sliderValue,
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) {
                  setState(() => _dragValue = null);
                  p.seek(Duration(milliseconds: (v * dur).round()));
                },
                activeColor: scheme.primary,
                inactiveColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // 当前曲目信息
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.music_note,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track?.title ?? '未选择歌曲',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_fmt(p.position)} / ${_fmt(p.duration)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 播放控制
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      tooltip: '上一首',
                      onPressed: p.previous,
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      onPressed: p.isPlaying ? p.pause : p.play,
                      child: Icon(
                        p.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      tooltip: '下一首',
                      onPressed: p.next,
                    ),
                  ],
                ),

                // 音量控制
                Expanded(
                  flex: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        p.volume == 0
                            ? Icons.volume_off
                            : p.volume < 0.5
                            ? Icons.volume_down
                            : Icons.volume_up,
                        size: 20,
                        color: scheme.outline,
                      ),
                      SizedBox(
                        width: 100,
                        child: Slider(
                          value: p.volume,
                          onChanged: (v) => p.setVolume(v),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
