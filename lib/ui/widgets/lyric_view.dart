import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/lyric_service.dart';
import '../../utils/lrc_parser.dart';
import '../../models/track.dart';
import 'lyric_widgets.dart';

class LyricView extends StatefulWidget {
  const LyricView({super.key});

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView> {
  List<LrcLine> lines = [];
  PlayerProvider? _player;
  PlaylistProvider? _playlist;
  LyricService? _lyricService;
  String? _lastTrackId;
  int? _lastLyricRevision;

  final ScrollController _scrollController = ScrollController();
  int _activeIndex = -1;
  int _lastHighlighted = -1;
  bool _userInteracting = false;
  bool _scrollPending = false;
  Timer? _scrollResetTimer;

  bool _isLoadingLyric = false;
  bool _isSearchingLyric = false;
  String? _lyricError;

  /// 估算每行歌词的平均高度（padding: 10*2 + 文字高度约 24）
  static const double _estimatedLineHeight = 44.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _player?.removeListener(_onPlayerChanged);
    _player?.positionNotifier.removeListener(_onPositionChanged);
    _playlist?.removeListener(_onPlaylistChanged);

    _player = context.read<PlayerProvider>();
    _playlist = context.read<PlaylistProvider>();
    _lyricService = _player!.lyricService;

    _player?.addListener(_onPlayerChanged);
    _player?.positionNotifier.addListener(_onPositionChanged);
    _playlist?.addListener(_onPlaylistChanged);

    _lastLyricRevision = _lyricService?.lyricRevision;
    _onPositionChanged();
    _loadForCurrent();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollResetTimer?.cancel();
    _player?.removeListener(_onPlayerChanged);
    _player?.positionNotifier.removeListener(_onPositionChanged);
    _playlist?.removeListener(_onPlaylistChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idx = _activeIndex;
    final scheme = Theme.of(context).colorScheme;

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

    if (lines.isEmpty) {
      final hasValidIndex =
          _playlist?.currentIndex != null &&
          _playlist!.currentIndex >= 0 &&
          _playlist!.currentIndex < _playlist!.tracks.length;
      final current = hasValidIndex ? _playlist?.current : null;
      final isLocal = current != null && !current.isRemote;
      return LyricEmptyState(
        error: _lyricError,
        current: current,
        isLocal: isLocal,
        onSearch: () {
          if (current != null) _searchOnlineLyric(current);
        },
        onCustomSearch: () {
          if (current != null) _showCustomSearchDialog(context, current);
        },
        onRefetch: () {
          if (current != null) _refetchRemoteLyric(current);
        },
      );
    }

    if (!_userInteracting && !_scrollPending) {
      _scrollPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollPending = false;
        if (mounted && !_userInteracting) {
          _performAutoScroll(idx);
        }
      });
    }

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              _userInteracting = true;
              _scrollResetTimer?.cancel();
              _scrollResetTimer = Timer(const Duration(seconds: 4), () {
                if (mounted) setState(() => _userInteracting = false);
              });
            }
            return false;
          },
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: lines.length,
              padding: const EdgeInsets.symmetric(vertical: 56),
              itemBuilder: (context, i) {
                final isActive = i == idx;
                final distance = idx >= 0 ? (i - idx).abs() : 0;
                final distanceAlpha = distance <= 1
                    ? 0.8
                    : (0.65 - (distance * 0.08)).clamp(0.2, 0.65);

                return LyricLineTile(
                  text: lines[i].text,
                  isActive: isActive,
                  distanceAlpha: distanceAlpha,
                  onTap: () {
                    context.read<PlayerProvider>().seek(lines[i].time);
                  },
                );
              },
            ),
          ),
        ),
        if (_userInteracting && idx >= 0)
          Positioned(
            bottom: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() => _userInteracting = false);
                  _scrollToLine(idx);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_double_arrow_down_rounded,
                        size: 16,
                        color: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '回到当前',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _performAutoScroll(int idx) {
    if (idx == -1 || idx >= lines.length || _userInteracting) return;
    final isNewLine = idx != _lastHighlighted;
    if (isNewLine) {
      _scrollToLine(idx);
      _lastHighlighted = idx;
    } else {
      _checkVisibilityAndScroll(idx);
    }
  }

  void _scrollToLine(int idx) {
    if (!_scrollController.hasClients) return;
    if (idx < 0 || idx >= lines.length) return;
    // 基于估算行高计算偏移，居中显示
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = idx * _estimatedLineHeight + 56 - viewportHeight / 2;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);
    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _checkVisibilityAndScroll(int idx) {
    if (!_scrollController.hasClients) return;
    if (idx < 0 || idx >= lines.length) return;
    // 基于估算偏移检查当前行是否在视口舒适区域内
    final estimatedTop =
        idx * _estimatedLineHeight + 56 - _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    final comfortableTop = viewportHeight * 0.25;
    final comfortableBottom = viewportHeight * 0.75;
    if (estimatedTop < comfortableTop || estimatedTop > comfortableBottom) {
      _scrollToLine(idx);
    }
  }

  Future<void> _showCustomSearchDialog(
    BuildContext context,
    Track track,
  ) async {
    final keyword = await showCustomLyricSearchDialog(
      context,
      initialKeyword: track.title,
    );
    if (!mounted || keyword == null) return;
    await _searchOnlineLyric(track, keyword: keyword);
  }

  Future<void> _searchOnlineLyric(Track track, {String? keyword}) async {
    if (_lyricService == null) return;
    setState(() {
      _isSearchingLyric = true;
      _lyricError = null;
    });
    try {
      final path = await _lyricService!.fetchOnlineLyricForLocal(
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
        setState(() => _lyricError = '未找到匹配的歌词，请尝试自定义关键词搜索');
      }
    } catch (e) {
      if (mounted) setState(() => _lyricError = '搜索歌词失败：$e');
    } finally {
      if (mounted) setState(() => _isSearchingLyric = false);
    }
  }

  Future<void> _refetchRemoteLyric(Track track) async {
    if (_player == null || !track.isRemote) return;
    final source = track.remoteSource;
    final lyricId = track.remoteLyricId;
    final key = track.lyricKey;
    if (source == null || lyricId == null || key == null) {
      setState(() => _lyricError = '缺少歌词信息，无法获取');
      return;
    }
    setState(() {
      _isSearchingLyric = true;
      _lyricError = null;
    });
    try {
      final lyric = await _player!.gdApi.getLyric(source: source, id: lyricId);
      if (lyric.lyric.trim().isEmpty) {
        setState(() => _lyricError = '该歌曲暂无歌词');
        return;
      }
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$key.lrc');
      await file.writeAsString(lyric.lyric);
      _lyricService!.lyricRevision++;
      _lyricService!.onLyricChanged?.call();
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
      if (mounted) setState(() => _lyricError = '获取歌词失败：$e');
    } finally {
      if (mounted) setState(() => _isSearchingLyric = false);
    }
  }

  void _onPositionChanged() {
    if (!mounted || lines.isEmpty) return;
    final index = LrcParser.indexAt(lines, _player?.position ?? Duration.zero);
    if (index != _activeIndex) {
      setState(() => _activeIndex = index);
    }
  }

  void _onPlayerChanged() {
    final rev = _lyricService?.lyricRevision;
    if (rev != _lastLyricRevision) {
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
      if (current != null && !current.isRemote) {
        _tryAutoSearchLyric(current);
      }
    }
  }

  Future<void> _tryAutoSearchLyric(Track track) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (lines.isNotEmpty) return;
    final existingPath = await _lyricService?.findExistingLyricPath(track);
    if (existingPath != null) return;
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
          _activeIndex = -1;
          _isLoadingLyric = false;
          _lyricError = null;
          _lastHighlighted = -1;
        });
      }
      return;
    }

    _lastTrackId = t.id;
    try {
      final existingPath = await _lyricService?.findExistingLyricPath(t);
      if (existingPath != null) {
        final file = File(existingPath);
        final content = await file.readAsString();
        final parsed = LrcParser.parse(content);
        if (mounted) {
          final activeIndex = LrcParser.indexAt(
            parsed,
            _player?.position ?? Duration.zero,
          );
          setState(() {
            lines = parsed;
            _activeIndex = activeIndex;
            _isLoadingLyric = false;
            _lyricError = null;
            _lastHighlighted = -1;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          lines = [];
          _activeIndex = -1;
          _isLoadingLyric = false;
          _lyricError = null;
          _lastHighlighted = -1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          lines = [];
          _activeIndex = -1;
          _isLoadingLyric = false;
          _lyricError = null;
          _lastHighlighted = -1;
        });
      }
    }
  }
}
