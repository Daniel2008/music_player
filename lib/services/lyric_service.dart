import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track.dart';
import 'gd_music_api.dart';

/// 歌词获取与缓存服务
///
/// 从 [PlayerProvider] 拆分出来，负责：
/// - 本地 .lrc 文件查找
/// - 在线歌词获取与磁盘缓存
/// - 歌词搜索关键词提取
class LyricService {
  LyricService(this._gdApi);
  final GdMusicApiClient _gdApi;

  int lyricRevision = 0;

  // 本地歌曲在线歌词缓存：track.id -> absolute lrc path
  final Map<String, String> localLyricPaths = {};
  static const int _maxLocalLyricPaths = 50;
  final List<String> _localLyricOrder = [];

  // 正在搜索歌词的曲目 ID 集合（防止重复搜索）
  final Set<String> _fetchingLyricIds = {};

  /// 歌词变更回调
  VoidCallback? onLyricChanged;

  /// 为远程曲目缓存歌词到本地磁盘
  Future<void> ensureLyricCachedFor(Track track) async {
    if (!track.isRemote) return;
    final source = track.remoteSource;
    final lyricId = track.remoteLyricId;
    final key = track.lyricKey;
    if (source == null || lyricId == null || key == null) return;

    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$key.lrc');
    if (await file.exists()) return;

    try {
      final lyric = await _gdApi.getLyric(source: source, id: lyricId);
      if (lyric.lyric.trim().isEmpty) return;
      await file.writeAsString(lyric.lyric);
      lyricRevision++;
      onLyricChanged?.call();
    } catch (e) {
      debugPrint('歌词缓存失败: $e');
    }
  }

  /// 查找本地曲目的 .lrc 文件
  Future<String?> findLocalLrcPath(Track track) async {
    final audioPath = track.path;
    final name = audioPath.replaceAll(RegExp(r'\.[^/.]+$'), '');
    final lrcLocal = '$name.lrc';
    if (await File(lrcLocal).exists()) return lrcLocal;

    final dir = await getApplicationSupportDirectory();
    final cachedPath = '${dir.path}/local_${track.id}.lrc';
    if (await File(cachedPath).exists()) return cachedPath;

    return null;
  }

  /// 为本地曲目自动搜索在线歌词
  Future<void> autoFetchLyricForLocalTrack(Track track) async {
    if (track.isRemote) return;

    final localLrcPath = await findLocalLrcPath(track);
    if (localLrcPath != null) return;

    if (localLyricPaths.containsKey(track.id)) return;
    if (_fetchingLyricIds.contains(track.id)) return;

    await fetchOnlineLyricForLocal(track);
  }

  /// 为本地曲目在线搜索歌词
  Future<String?> fetchOnlineLyricForLocal(
    Track track, {
    String source = 'netease',
    String? searchKeyword,
  }) async {
    if (track.isRemote) return null;
    if (_fetchingLyricIds.contains(track.id)) return null;
    _fetchingLyricIds.add(track.id);

    try {
      final keyword = searchKeyword ?? _extractSearchKeyword(track.title);
      final results = await _gdApi.search(
        keyword: keyword,
        source: source,
        count: 10,
      );

      final match = _findBestLyricMatch(results, track.title);
      if (match == null) return null;

      final lyric = await _gdApi.getLyric(
        source: match.source,
        id: match.lyricId!,
      );
      if (lyric.lyric.trim().isEmpty) return null;

      final dir = await getApplicationSupportDirectory();
      final filename = 'local_${track.id}.lrc';
      final path = '${dir.path}/$filename';
      final file = File(path);
      await file.writeAsString(lyric.lyric);

      _localLyricOrder.add(track.id);
      if (_localLyricOrder.length > _maxLocalLyricPaths) {
        final oldest = _localLyricOrder.removeAt(0);
        localLyricPaths.remove(oldest);
      }
      localLyricPaths[track.id] = path;

      lyricRevision++;
      onLyricChanged?.call();
      return path;
    } catch (_) {
      return null;
    } finally {
      _fetchingLyricIds.remove(track.id);
    }
  }

  String _extractSearchKeyword(String title) {
    var keyword = title;
    keyword = keyword.replaceAll(RegExp(r'[\(（\[【][^\)）\]】]*[\)）\]】]'), '');
    keyword = keyword.replaceAll(
      RegExp(r'(320k|128k|flac|ape|mp3|wav|hi-?res|无损)', caseSensitive: false),
      '',
    );
    keyword = keyword.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (keyword.length < 2) return title;
    return keyword;
  }

  GdSearchTrack? _findBestLyricMatch(
    List<GdSearchTrack> results,
    String title,
  ) {
    if (results.isEmpty) return null;
    final withLyric = results
        .where((r) => r.lyricId != null && r.lyricId!.isNotEmpty)
        .toList();
    if (withLyric.isEmpty) return null;

    final titleLower = title.toLowerCase();
    for (final r in withLyric) {
      final nameLower = r.name.toLowerCase();
      if (titleLower.contains(nameLower) || nameLower.contains(titleLower)) {
        return r;
      }
    }
    return withLyric.first;
  }

  /// 查找曲目已有的歌词路径（远程/本地/缓存）
  Future<String?> findExistingLyricPath(Track track) async {
    final cached = localLyricPaths[track.id];
    if (cached != null && await File(cached).exists()) return cached;

    if (track.isRemote && track.lyricKey != null) {
      final dir = await getApplicationSupportDirectory();
      final remotePath = '${dir.path}/${track.lyricKey}.lrc';
      if (await File(remotePath).exists()) return remotePath;
    }

    if (!track.isRemote && track.path.isNotEmpty) {
      final audioPath = track.path;
      final name = audioPath.replaceAll(RegExp(r'\.[^/.]+$'), '');
      final lrcLocal = '$name.lrc';
      if (await File(lrcLocal).exists()) return lrcLocal;
    }

    final dir = await getApplicationSupportDirectory();
    final cachedPath = '${dir.path}/local_${track.id}.lrc';
    if (await File(cachedPath).exists()) return cachedPath;

    return null;
  }
}
