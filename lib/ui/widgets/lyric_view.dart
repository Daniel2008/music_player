import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../utils/lrc_parser.dart';
import '../../models/track.dart';

class LyricView extends StatefulWidget {
  const LyricView({super.key});

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView> {
  List<LrcLine> lines = [];
  PlayerProvider? _player;
  PlaylistProvider? _playlist;
  String? _lastTrackId;
  int? _lastLyricRevision;
  final List<GlobalKey> _lineKeys = [];
  int _lastHighlighted = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _player?.removeListener(_onPlayerChanged);
    _playlist?.removeListener(_onPlaylistChanged);

    _player = context.read<PlayerProvider>();
    _playlist = context.read<PlaylistProvider>();

    _player?.addListener(_onPlayerChanged);
    _playlist?.addListener(_onPlaylistChanged);

    _lastLyricRevision = _player?.lyricRevision;
    _loadForCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    // 也监听 PlaylistProvider 以便在曲目变化时重建
    context.watch<PlaylistProvider>();
    final pos = p.position;
    final idx = _currentIndex(pos);
    final scheme = Theme.of(context).colorScheme;

    if (lines.isEmpty) {
      // 如果当前播放的是本地歌曲，提供在线搜索歌词的入口
      final current = _playlist?.current;
      final isLocal = current != null && !current.isRemote;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('暂无歌词', style: TextStyle(color: scheme.outline)),
            const SizedBox(height: 8),
            if (isLocal)
              FilledButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('搜索在线歌词'),
                onPressed: () async {
                  final t = current;
                  final path = await _player!.fetchOnlineLyricForLocal(t);
                  if (!context.mounted) return;

                  if (path != null) {
                    // 触发 reload
                    setState(() {});
                  } else {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('未找到在线歌词')));
                  }
                },
              ),
          ],
        ),
      );
    }

    // 当高亮行发生变化时，延迟一次滚动以保证 item 已渲染
    if (idx != -1 && idx != _lastHighlighted) {
      _lastHighlighted = idx;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (idx >= 0 && idx < _lineKeys.length) {
          final ctx = _lineKeys[idx].currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 300),
              alignment: 0.5,
              curve: Curves.easeInOut,
            );
          }
        }
      });
    }

    return ListView.builder(
      itemCount: lines.length,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemBuilder: (context, i) {
        final isActive = i == idx;
        // 确保有对应的 GlobalKey
        if (i >= _lineKeys.length) {
          _lineKeys.addAll(
            List.generate(i - _lineKeys.length + 1, (_) => GlobalKey()),
          );
        }
        return Container(
          key: _lineKeys[i],
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: isActive ? 20 : 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.6),
              height: 1.5,
            ),
            child: Text(lines[i].text, textAlign: TextAlign.center),
          ),
        );
      },
    );
  }

  int _currentIndex(Duration pos) {
    for (var i = 0; i < lines.length; i++) {
      final nextTime = i + 1 < lines.length
          ? lines[i + 1].time
          : pos + const Duration(hours: 1);
      if (pos >= lines[i].time && pos < nextTime) return i;
    }
    return -1;
  }

  void _onPlayerChanged() {
    final rev = _player?.lyricRevision;
    final lyricChanged = rev != _lastLyricRevision;
    if (lyricChanged) {
      _lastLyricRevision = rev;
      _loadForCurrent();
    }
  }

  void _onPlaylistChanged() {
    final current = _playlist?.current;
    final trackChanged = current?.id != _lastTrackId;
    if (trackChanged) {
      _loadForCurrent();
    }
  }

  Future<void> _loadForCurrent() async {
    final t = _playlist?.current;
    if (t == null) return;
    _lastTrackId = t.id;
    final file = File(await _lyricPathFor(t));
    if (await file.exists()) {
      final content = await file.readAsString();
      lines = LrcParser.parse(content);
      // 重建 keys
      _lineKeys.clear();
      _lineKeys.addAll(List.generate(lines.length, (_) => GlobalKey()));
      if (mounted) setState(() {});
      // 首次加载后滚动到当前播放位置
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final p = _player;
        if (p == null) return;
        final idx = _currentIndex(p.position);
        if (idx >= 0 && idx < _lineKeys.length) {
          final ctx = _lineKeys[idx].currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 300),
              alignment: 0.5,
            );
          }
        }
      });
    } else {
      lines = [];
      if (mounted) setState(() {});
    }
  }

  Future<String> _lyricPathFor(Track track) async {
    // 如果 provider 中已缓存本地歌词路径，优先使用
    final cached = _player?.localLyricPaths[track.id];
    if (cached != null && await File(cached).exists()) return cached;

    if (track.isRemote && track.lyricKey != null) {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}/${track.lyricKey}.lrc';
    }

    final audioPath = track.path;
    final name = audioPath.replaceAll(RegExp(r"\.[^/.]+$"), '');
    final lrcLocal = '$name.lrc';
    if (await File(lrcLocal).exists()) return lrcLocal;
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/${name.split(Platform.pathSeparator).last}.lrc';
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayerChanged);
    _playlist?.removeListener(_onPlaylistChanged);
    super.dispose();
  }
}
