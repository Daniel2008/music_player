import 'dart:io';
import 'dart:async';
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

  // 用于自动滚动的控制器
  final ScrollController _scrollController = ScrollController();
  int _lastHighlighted = -1;
  bool _userInteracting = false;
  Timer? _scrollResetTimer;

  // 歌词加载状态
  bool _isLoadingLyric = false;
  bool _isSearchingLyric = false;
  String? _lyricError;

  // 自定义搜索控制器
  final TextEditingController _searchController = TextEditingController();

  // GlobalKeys 用于获取实际渲染尺寸
  final Map<int, GlobalKey> _lineKeys = {};

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
  void initState() {
    super.initState();

    // 监听用户的手动滚动 - 更快速响应
    _scrollController.addListener(() {
      if (!_userInteracting) {
        _userInteracting = true;

        // 取消之前的定时器
        _scrollResetTimer?.cancel();

        // 1秒后恢复自动滚动（更短延迟）
        _scrollResetTimer = Timer(const Duration(seconds: 1), () {
          if (mounted && _userInteracting) {
            setState(() {
              _userInteracting = false;
            });
          }
        });
      } else {
        // 用户还在滚动，重置定时器
        _scrollResetTimer?.cancel();
        _scrollResetTimer = Timer(const Duration(seconds: 1), () {
          if (mounted && _userInteracting) {
            setState(() {
              _userInteracting = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollResetTimer?.cancel();
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
      final current =
          _playlist?.currentIndex != null &&
              _playlist!.currentIndex >= 0 &&
              _playlist!.currentIndex < _playlist!.tracks.length
          ? _playlist?.current
          : null;
      final isLocal = current != null && !current.isRemote;
      return _buildNoLyricView(context, scheme, current, isLocal);
    }

    // 关键：在 build 的最后调用滚动逻辑，使用 addPostFrameCallback
    // 这确保滚动在真实渲染尺寸确定后执行
    if (!_userInteracting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _performAutoScroll(idx);
        }
      });
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: lines.length,
        padding: const EdgeInsets.symmetric(vertical: 16 + 40), // 顶部底部额外空间
        itemBuilder: (context, i) {
          final isActive = i == idx;

          // 为每行创建 GlobalKey
          if (i >= _lineKeys.length) {
            _lineKeys[i] = GlobalKey();
          }

          return Container(
            key: _lineKeys[i],
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: isActive ? 24 : 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? scheme.primary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                height: 1.5,
                shadows: isActive
                    ? [
                        Shadow(
                          color: scheme.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                lines[i].text,
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ),
          );
        },
      ),
    );
  }

  void _performAutoScroll(int idx) {
    if (idx == -1 || idx >= lines.length || _userInteracting) return;

    // 如果是新行，总是滚动
    final isNewLine = idx != _lastHighlighted;

    if (isNewLine) {
      _scrollToLine(idx);
      _lastHighlighted = idx;
    } else {
      // 检查当前行是否在可视范围内
      _checkVisibilityAndScroll(idx);
    }
  }

  void _scrollToLine(int idx) {
    if (!_scrollController.hasClients) return;

    final key = idx < _lineKeys.length ? _lineKeys[idx] : null;
    if (key == null || key.currentContext == null) return;

    // 使用 EnsureVisible 来精确滚动到当前行
    Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 350),
      alignment: 0.5, // 让当前行位于视口中央
      curve: Curves.easeInOutCubic,
    );
  }

  void _checkVisibilityAndScroll(int idx) {
    if (!_scrollController.hasClients) return;

    final key = idx < _lineKeys.length ? _lineKeys[idx] : null;
    if (key == null || key.currentContext == null) return;

    // 获取当前行的位置信息
    final renderBox = key.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewportBox =
        _scrollController.position.context.notificationContext
                ?.findRenderObject()
            as RenderBox?;
    if (viewportBox == null) return;

    // 获取相对位置
    final offset = renderBox.localToGlobal(Offset.zero, ancestor: viewportBox);
    final viewportHeight = viewportBox.size.height;
    final itemHeight = renderBox.size.height;

    // 定义舒适可视区域（视口的 25%-75%）
    final comfortableTop = viewportHeight * 0.25;
    final comfortableBottom = viewportHeight * 0.75;

    // 检查是否在舒适区域内
    final itemTop = offset.dy;
    final itemBottom = offset.dy + itemHeight;

    if (itemTop < comfortableTop || itemBottom > comfortableBottom) {
      _scrollToLine(idx);
    }
  }

  Stream<String?> _findExistingLyricPath(Track track) async* {
    // 检查缓存路径
    final cached = _player?.localLyricPaths[track.id];
    if (cached != null && await File(cached).exists()) {
      yield cached;
      return;
    }

    // 检查远程歌曲的歌词
    if (track.isRemote && track.lyricKey != null) {
      final dir = await getApplicationSupportDirectory();
      final remotePath = '${dir.path}/${track.lyricKey}.lrc';
      if (await File(remotePath).exists()) {
        yield remotePath;
        return;
      }
    }

    // 检查同目录下的lrc文件
    if (!track.isRemote && track.path.isNotEmpty) {
      final audioPath = track.path;
      final name = audioPath.replaceAll(RegExp(r"\.[^/.]+$"), '');
      final lrcLocal = '$name.lrc';
      if (await File(lrcLocal).exists()) {
        yield lrcLocal;
        return;
      }
    }

    // 检查应用支持目录
    final dir = await getApplicationSupportDirectory();
    final cachedPath = '${dir.path}/local_${track.id}.lrc';
    if (await File(cachedPath).exists()) {
      yield cachedPath;
      return;
    }

    yield null;
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

              FilledButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('搜索在线歌词'),
                onPressed: () => _searchOnlineLyric(current),
              ),
              const SizedBox(height: 12),

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
    final hasValidIndex =
        _playlist?.currentIndex != null &&
        _playlist!.currentIndex >= 0 &&
        _playlist!.currentIndex < _playlist!.tracks.length;

    final current = hasValidIndex ? _playlist?.current : null;
    final trackChanged = current?.id != _lastTrackId;

    if (trackChanged) {
      _loadForCurrent();
      if (current != null &&
          !current.isRemote &&
          (_player?.autoFetchLyricForLocal ?? false)) {
        _tryAutoSearchLyric(current);
      }
    }
  }

  Future<void> _tryAutoSearchLyric(Track track) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (lines.isNotEmpty) return;

    await for (final path in _findExistingLyricPath(track)) {
      if (path != null) return;
    }

    await _searchOnlineLyric(track);
  }

  Future<void> _loadForCurrent() async {
    final hasValidIndex =
        _playlist?.currentIndex != null &&
        _playlist!.currentIndex >= 0 &&
        _playlist!.currentIndex < _playlist!.tracks.length;

    final t = hasValidIndex ? _playlist?.current : null;

    if (t == null) {
      if (mounted) {
        setState(() {
          lines = [];
          _isLoadingLyric = false;
          _lyricError = null;
          _lastHighlighted = -1;
          _lineKeys.clear();
        });
      }
      return;
    }

    _lastTrackId = t.id;

    try {
      // 使用流式检查
      await for (final existingPath in _findExistingLyricPath(t)) {
        if (existingPath != null) {
          final file = File(existingPath);
          final content = await file.readAsString();
          final parsed = LrcParser.parse(content);

          if (mounted) {
            setState(() {
              lines = parsed;
              _isLoadingLyric = false;
              _lyricError = null;
              _lastHighlighted = -1;
              _lineKeys.clear();
              // 重建 keys
              for (int i = 0; i < parsed.length; i++) {
                _lineKeys[i] = GlobalKey();
              }
            });
          }
          return;
        }
      }

      // 没找到歌词
      if (mounted) {
        setState(() {
          lines = [];
          _isLoadingLyric = false;
          _lyricError = null;
          _lastHighlighted = -1;
          _lineKeys.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          lines = [];
          _isLoadingLyric = false;
          _lyricError = null;
          _lastHighlighted = -1;
          _lineKeys.clear();
        });
      }
    }
  }
}
