import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/api_settings_provider.dart';
import '../../models/track.dart';
import '../../services/gd_music_api.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String? _source;
  String? _quality;

  @override
  void initState() {
    super.initState();
    // 初始化时从设置中获取默认值
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiSettings = context.read<ApiSettingsProvider>();
      setState(() {
        _source = apiSettings.defaultSource;
        _quality = apiSettings.playQuality.brValue;
      });
    });
  }

  List<(String, String)> _getAvailableSources(ApiSettingsProvider apiSettings) {
    return apiSettings.availableSources.map((s) => (s.id, s.name)).toList();
  }

  List<(String, String)> _getQualityOptions() {
    return AudioQuality.values
        .map((q) => (q.brValue, '${q.description} ${q.label}'))
        .toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(SearchProvider searchProvider) {
    final q = _controller.text.trim();
    if (q.isNotEmpty) {
      final apiSettings = context.read<ApiSettingsProvider>();
      final source = _source ?? apiSettings.defaultSource;
      searchProvider.searchOnline(q, source: source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = context.watch<SearchProvider>();
    final apiSettings = context.watch<ApiSettingsProvider>();
    final scheme = Theme.of(context).colorScheme;

    // 确保有默认值
    final currentSource = _source ?? apiSettings.defaultSource;
    final currentQuality = _quality ?? apiSettings.playQuality.brValue;

    return Column(
      children: [
        // 搜索栏
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.search, color: scheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    '在线音乐搜索',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '搜索歌曲、歌手、专辑...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _controller.clear();
                                  searchProvider.clearSearch();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: scheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (_) => _search(searchProvider),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: searchProvider.isSearching
                        ? null
                        : () => _search(searchProvider),
                    icon: searchProvider.isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: const Text('搜索'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  // 音乐源选择
                  _buildChipSelector(
                    context: context,
                    label: '音乐源',
                    value: currentSource,
                    items: _getAvailableSources(apiSettings),
                    onChanged: (v) {
                      setState(() => _source = v);
                      if (_controller.text.trim().isNotEmpty) {
                        _search(searchProvider);
                      }
                    },
                  ),
                  // 音质选择
                  _buildChipSelector(
                    context: context,
                    label: '音质',
                    value: currentQuality,
                    items: _getQualityOptions(),
                    onChanged: (v) => setState(() => _quality = v),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 搜索结果
        Expanded(
          child: searchProvider.searchError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: scheme.error),
                      const SizedBox(height: 12),
                      Text(
                        searchProvider.searchError!,
                        style: TextStyle(color: scheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: () => _search(searchProvider),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : searchProvider.searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.music_note_outlined,
                        size: 64,
                        color: scheme.outline.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '输入关键词搜索音乐',
                        style: TextStyle(color: scheme.outline, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '支持多个音乐平台',
                        style: TextStyle(color: scheme.outline, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : _SearchResultList(
                  items: searchProvider.searchResults,
                  quality: currentQuality,
                ),
        ),
      ],
    );
  }

  Widget _buildChipSelector({
    required BuildContext context,
    required String label,
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        PopupMenuButton<String>(
          initialValue: value,
          onSelected: onChanged,
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Chip(
            label: Text(
              items.firstWhere((e) => e.$1 == value).$2,
              style: const TextStyle(fontSize: 13),
            ),
            avatar: const Icon(Icons.arrow_drop_down, size: 18),
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
          ),
          itemBuilder: (context) => items
              .map(
                (e) => PopupMenuItem(
                  value: e.$1,
                  child: Row(
                    children: [
                      if (e.$1 == value)
                        Icon(Icons.check, size: 18, color: scheme.primary)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(e.$2),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SearchResultList extends StatelessWidget {
  final List<GdSearchTrack> items;
  final String quality;

  const _SearchResultList({required this.items, required this.quality});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '找到 ${items.length} 首歌曲',
            style: TextStyle(color: scheme.outline, fontSize: 13),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            padding: const EdgeInsets.only(bottom: 16),
            itemBuilder: (context, index) {
              final t = items[index];
              return _SearchResultItem(
                track: t,
                index: index,
                quality: quality,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final GdSearchTrack track;
  final int index;
  final String quality;

  const _SearchResultItem({
    required this.track,
    required this.index,
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final playlistProvider = context.watch<PlaylistProvider>();
    final favoritesProvider = context.watch<FavoritesProvider>();
    final downloadProvider = context.watch<DownloadProvider>();
    final scheme = Theme.of(context).colorScheme;

    final isDownloading = downloadProvider.isDownloading(
      track.source,
      track.id,
    );
    final downloadProgress = downloadProvider.getDownloadProgress(
      track.source,
      track.id,
    );
    final isFavorite = favoritesProvider.isFavorite(track);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        track.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        [
          track.artistText,
          track.album,
          track.source,
        ].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: scheme.outline),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 收藏按钮
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : scheme.outline,
              size: 20,
            ),
            tooltip: isFavorite ? '取消收藏' : '收藏',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await favoritesProvider.toggleFavorite(track);
            },
          ),
          // 下载按钮
          if (isDownloading)
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: downloadProgress,
                    strokeWidth: 2.5,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                  Text(
                    '${(downloadProgress * 100).toInt()}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            )
          else
            IconButton(
              icon: Icon(
                Icons.download_outlined,
                size: 20,
                color: scheme.outline,
              ),
              tooltip: '下载',
              visualDensity: VisualDensity.compact,
              onPressed: () => _downloadTrack(context, downloadProvider, track),
            ),
          // 播放按钮
          IconButton(
            icon: Icon(Icons.play_circle_filled, color: scheme.primary),
            tooltip: '立即播放',
            onPressed: () =>
                _playTrack(context, playerProvider, playlistProvider, track),
          ),
        ],
      ),
    );
  }

  Future<void> _playTrack(
    BuildContext context,
    PlayerProvider playerProvider,
    PlaylistProvider playlistProvider,
    GdSearchTrack item,
  ) async {
    // 创建 Track 对象并添加到播放列表
    final displayArtist = item.artistText;
    final title = displayArtist.isEmpty
        ? item.name
        : '${item.name} - $displayArtist';

    final trackId = Track.generateRemoteId(item.source, item.id);

    // 检查是否已存在于播放列表中
    final existingIndex = playlistProvider.playlist.tracks.indexWhere(
      (t) => t.id == trackId,
    );

    if (existingIndex >= 0) {
      // 已存在，直接切换到该曲目
      playlistProvider.setCurrentIndex(existingIndex);
    } else {
      // 不存在，创建新的 Track 并添加
      final newTrack = Track(
        id: trackId,
        title: title,
        path: '', // 路径会在 resolveAndPlayTrackUrl 中解析
        artist: displayArtist.isEmpty ? null : displayArtist,
        kind: TrackKind.remote,
        remoteSource: item.source,
        remoteTrackId: item.id,
        remoteLyricId: item.lyricId ?? item.id,
        lyricKey: 'gd_${item.source}_${item.lyricId ?? item.id}',
      );

      playlistProvider.addTrack(newTrack);
      playlistProvider.setCurrentIndex(
        playlistProvider.playlist.tracks.length - 1,
      );
    }

    final ok = await playerProvider.resolveAndPlayTrackUrl(
      item,
      br: quality,
      playlistProvider: playlistProvider,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(playerProvider.playError ?? '播放失败'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    } else if (ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('正在播放: ${item.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _downloadTrack(
    BuildContext context,
    DownloadProvider downloadProvider,
    GdSearchTrack t,
  ) async {
    final result = await downloadProvider.downloadTrack(t, br: quality);
    if (!context.mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('下载完成: ${t.name}'),
            action: SnackBarAction(
              label: '打开位置',
              onPressed: () async {
                // 打开文件所在目录
                final dir = result.substring(0, result.lastIndexOf('\\'));
                await Process.run('explorer', [dir]);
              },
            ),
          ),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('下载失败: ${downloadProvider.downloadError ?? '未知错误'}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }
}
