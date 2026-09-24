import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/track.dart';
import '../../providers/download_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/gd_music_api.dart';
import 'app_surfaces.dart';

class CompactSearchResultList extends StatelessWidget {
  const CompactSearchResultList({
    super.key,
    required this.items,
    required this.quality,
  });

  final List<GdSearchTrack> items;
  final String quality;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: AppSectionTitle(
              title: '搜索结果',
              subtitle: '找到 ${items.length} 首歌曲',
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              itemBuilder: (context, index) => _CompactSearchResultRow(
                track: items[index],
                quality: quality,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CompactSearchLoadingList extends StatelessWidget {
  const CompactSearchLoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: EdgeInsets.zero,
      child: ListView.builder(
        itemCount: 8,
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) => const _CompactShimmerRow(),
      ),
    );
  }
}

class _CompactSearchResultRow extends StatelessWidget {
  const _CompactSearchResultRow({required this.track, required this.quality});

  final GdSearchTrack track;
  final String quality;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gdApi = context.read<GdMusicApiClient>();
    final coverUrl = gdApi.buildCoverUrl(track.picId, track.source);
    final isFavorite = context.select<FavoritesProvider, bool>(
      (provider) => provider.isFavorite(track),
    );
    final downloadState = context.select<DownloadProvider, (bool, double)>(
      (provider) => (
        provider.isDownloading(track.source, track.id),
        provider.getDownloadProgress(track.source, track.id),
      ),
    );

    return AppMediaRow(
      title: track.name,
      subtitle: [
        track.artistText,
        track.album,
        track.source,
      ].where((text) => text.isNotEmpty).join('  ·  '),
      leading: _SearchCover(
        imageProvider: coverUrl == null
            ? null
            : coverImageProvider(coverUrl, size: 44),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () =>
                context.read<FavoritesProvider>().toggleFavorite(track),
            tooltip: isFavorite ? '取消收藏' : '收藏',
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 19,
              color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          if (downloadState.$1)
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: downloadState.$2,
                    strokeWidth: 2,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                  Text(
                    '${(downloadState.$2 * 100).round()}',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            )
          else
            IconButton(
              onPressed: () => _download(context),
              tooltip: '下载',
              icon: const Icon(Icons.download_rounded, size: 19),
            ),
          const SizedBox(width: 2),
          IconButton.filled(
            onPressed: () => _play(context),
            tooltip: '立即播放',
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _play(BuildContext context) async {
    final player = context.read<PlayerProvider>();
    final playlist = context.read<PlaylistProvider>();
    playlist.addOrSelectTrack(Track.fromGdSearchTrack(track));

    final ok = await player.resolveAndPlayTrackUrl(
      track,
      br: quality,
      playlistProvider: playlist,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? '正在播放：${track.name}' : player.playError ?? '播放失败'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _download(BuildContext context) async {
    final downloadProvider = context.read<DownloadProvider>();
    final result = await downloadProvider.downloadTrack(track, br: quality);
    if (!context.mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('下载失败：${downloadProvider.downloadError ?? '未知错误'}'),
          ),
        );
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('下载完成：${track.name}'),
          action: SnackBarAction(
            label: '打开位置',
            onPressed: () {
              final directory = result.substring(
                0,
                result.lastIndexOf(Platform.pathSeparator),
              );
              Process.run('explorer', [directory]);
            },
          ),
        ),
      );
  }
}

class _SearchCover extends StatelessWidget {
  const _SearchCover({required this.imageProvider});

  final ImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.music_note_rounded,
        size: 18,
        color: scheme.onSurfaceVariant,
      ),
    );

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: imageProvider == null
            ? placeholder
            : Image(
                image: imageProvider!,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, _) =>
                    frame == null ? placeholder : child,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}

class _CompactShimmerRow extends StatefulWidget {
  const _CompactShimmerRow();

  @override
  State<_CompactShimmerRow> createState() => _CompactShimmerRowState();
}

class _CompactShimmerRowState extends State<_CompactShimmerRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Opacity(opacity: 0.45 + _controller.value * 0.3, child: child),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Row(
          children: [
            _block(scheme, 44, 44, 6),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(scheme, 180, 12, 4),
                  const SizedBox(height: 8),
                  _block(scheme, 110, 9, 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _block(
    ColorScheme scheme,
    double width,
    double height,
    double radius,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
