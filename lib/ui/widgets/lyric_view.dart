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

  // 歌词加载状态
  bool _isLoadingLyric = false;
  bool _isSearchingLyric = false;
  String? _lyricError;

  // 自定义搜索控制器
  final TextEditingController _searchController = TextEditingController();

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
  void dispose() {
    _player?.removeListener(_onPlayerChanged);
    _playlist?.removeListener(_onPlaylistChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    // 也监听 PlaylistProvider 以便在曲目变化时重建
    context.watch<PlaylistProvider>();
    final pos = p.position;
    final idx = _currentIndex(pos);
    final scheme = Theme.of(context).colorScheme;

    // 加载中状态
    if (_isLoadingLyric) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('正在加载歌词...', style: TextStyle(color: scheme.outline)),
          ],
        ),
      );
    }

    // 搜索中状态
    if (_isSearchingLyric) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('正在搜索在线歌词...', style: TextStyle(color: scheme.outline)),
          ],
        ),
      );
    }

    // 无歌词状态
    if (lines.isEmpty) {
      final current = _playlist?.current;
      final isLocal = current != null && !current.isRemote;
      return _buildNoLyricView(context, scheme, current, isLocal);
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

  Widget _buildNoLyricView(
    BuildContext context,
    ColorScheme scheme,
    Track? current,
    bool isLocal,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 48,
              color: scheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _lyricError ?? '暂无歌词',
              style: TextStyle(color: scheme.outline, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 本地歌曲显示搜索选项
            if (isLocal && current != null) ...[
              // 自动搜索开关
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '自动搜索歌词',
                    style: TextStyle(color: scheme.outline, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _player?.autoFetchLyricForLocal ?? true,
                    onChanged: (value) {
                      setState(() {
                        _player?.autoFetchLyricForLocal = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 搜索按钮
              FilledButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('搜索在线歌词'),
                onPressed: () => _searchOnlineLyric(current),
              ),
              const SizedBox(height: 12),

              // 自定义搜索
              TextButton.icon(
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('自定义关键词搜索'),
                onPressed: () => _showCustomSearchDialog(context, current),
              ),
            ],

            // 在线歌曲显示重新获取按钮
            if (current != null && current.isRemote) ...[
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重新获取歌词'),
                onPressed: () => _refetchRemoteLyric(current),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCustomSearchDialog(BuildContext context, Track track) {
    _searchController.text = track.title;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义搜索歌词'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '输入歌曲名或歌手名进行搜索：',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '例如：歌曲名 - 歌手',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) {
                Navigator.pop(context);
                _searchOnlineLyric(track, keyword: _searchController.text);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _searchOnlineLyric(track, keyword: _searchController.text);
            },
            child: const Text('搜索'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchOnlineLyric(Track track, {String? keyword}) async {
    if (_player == null) return;

    setState(() {
      _isSearchingLyric = true;
      _lyricError = null;
    });

    try {
      final path = await _player!.fetchOnlineLyricForLocal(
        track,
        searchKeyword: keyword,
      );

      if (!mounted) return;

      if (path != null) {
        // 歌词获取成功，重新加载
        await _loadForCurrent();
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text('歌词获取成功'),
                duration: Duration(seconds: 2),
              ),
            );
        }
      } else {
        setState(() {
          _lyricError = '未找到匹配的歌词，请尝试自定义关键词搜索';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lyricError = '搜索歌词失败：$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingLyric = false;
        });
      }
    }
  }

  Future<void> _refetchRemoteLyric(Track track) async {
    if (_player == null || !track.isRemote) return;

    final source = track.remoteSource;
    final lyricId = track.remoteLyricId;
    final key = track.lyricKey;

    if (source == null || lyricId == null || key == null) {
      setState(() {
        _lyricError = '缺少歌词信息，无法获取';
      });
      return;
    }

    setState(() {
      _isSearchingLyric = true;
      _lyricError = null;
    });

    try {
      final gdApi = _player!.gdApi;
      final lyric = await gdApi.getLyric(source: source, id: lyricId);

      if (lyric.lyric.trim().isEmpty) {
        setState(() {
          _lyricError = '该歌曲暂无歌词';
        });
        return;
      }

      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$key.lrc');
      await file.writeAsString(lyric.lyric);

      _player!.notifyLyricUpdated();

      await _loadForCurrent();

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('歌词获取成功'),
              duration: Duration(seconds: 2),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lyricError = '获取歌词失败：$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingLyric = false;
        });
      }
    }
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
    if (t == null) {
      if (mounted) {
        setState(() {
          lines = [];
          _isLoadingLyric = false;
          _lyricError = null;
        });
      }
      return;
    }

    _lastTrackId = t.id;

    // 不显示加载状态，直接快速检查文件
    // 避免频繁切换时闪烁

    try {
      // 先检查是否有可用的歌词文件
      String? existingPath = await _findExistingLyricPath(t);

      if (existingPath != null) {
        final file = File(existingPath);
        final content = await file.readAsString();
        final parsed = LrcParser.parse(content);

        // 重建 keys
        _lineKeys.clear();
        _lineKeys.addAll(List.generate(parsed.length, (_) => GlobalKey()));

        if (mounted) {
          setState(() {
            lines = parsed;
            _isLoadingLyric = false;
            _lyricError = null;
          });

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
        }
      } else {
        // 没有找到歌词文件
        if (mounted) {
          setState(() {
            lines = [];
            _isLoadingLyric = false;
            _lyricError = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          lines = [];
          _isLoadingLyric = false;
          _lyricError = null; // 不显示错误，只是没有歌词
        });
      }
    }
  }

  /// 查找已存在的歌词文件路径
  Future<String?> _findExistingLyricPath(Track track) async {
    // 1. 检查 provider 中已缓存的本地歌词路径
    final cached = _player?.localLyricPaths[track.id];
    if (cached != null && await File(cached).exists()) return cached;

    // 2. 如果是远程曲目，检查 lyricKey 对应的缓存文件
    if (track.isRemote && track.lyricKey != null) {
      final dir = await getApplicationSupportDirectory();
      final remotePath = '${dir.path}/${track.lyricKey}.lrc';
      if (await File(remotePath).exists()) return remotePath;
    }

    // 3. 如果是本地曲目，检查同目录下的 .lrc 文件
    if (!track.isRemote && track.path.isNotEmpty) {
      final audioPath = track.path;
      final name = audioPath.replaceAll(RegExp(r"\.[^/.]+$"), '');
      final lrcLocal = '$name.lrc';
      if (await File(lrcLocal).exists()) return lrcLocal;
    }

    // 4. 检查应用缓存目录中的本地歌曲歌词
    final dir = await getApplicationSupportDirectory();
    final cachedPath = '${dir.path}/local_${track.id}.lrc';
    if (await File(cachedPath).exists()) return cachedPath;

    return null;
  }
}
