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

class SearchResultList extends StatelessWidget {
  const SearchResultList({
    super.key,
    required this.items,
    required this.quality,
  });

  final List<GdSearchTrack> items;
  final String quality;

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
            padding: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
            itemBuilder: (context, index) {
              return _SearchResultItem(
                track: items[index],
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

class SearchLoadingList extends StatelessWidget {
  const SearchLoadingList({super.key, required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 8,
      itemBuilder: (context, index) {
        return _ShimmerItem(index: index, scheme: scheme);
      },
    );
  }
}

class _SearchResultItem extends StatefulWidget {
  const _SearchResultItem({
    required this.track,
    required this.index,
    required this.quality,
  });

  final GdSearchTrack track;
  final int index;
  final String quality;

  @override
  State<_SearchResultItem> createState() => _SearchResultItemState();
}

class _SearchResultItemState extends State<_SearchResultItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _entranceController;
  late final Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _entranceController.stop();
      }
    });
    Future.delayed(Duration(milliseconds: 30 * widget.index.clamp(0, 15)), () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isFavorite = context.select<FavoritesProvider, bool>(
      (p) => p.isFavorite(widget.track),
    );
    final downloadState = context.select<DownloadProvider, (bool, double)>(
      (p) => (
        p.isDownloading(widget.track.source, widget.track.id),
        p.getDownloadProgress(widget.track.source, widget.track.id),
      ),
    );
    final isDownloading = downloadState.$1;
    final downloadProgress = downloadState.$2;

    final gdApi = context.read<GdMusicApiClient>();
    final coverUrl = gdApi.buildCoverUrl(
      widget.track.picId,
      widget.track.source,
    );

    return FadeTransition(
      opacity: _entranceAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_entranceAnimation),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _isHovered
                  ? (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : scheme.primaryContainer.withValues(alpha: 0.15))
                  : Colors.transparent,
              border: _isHovered
                  ? Border.all(
                      color: scheme.primary.withValues(alpha: 0.12),
                      width: 1,
                    )
                  : Border.all(color: Colors.transparent, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _buildCoverArt(coverUrl, scheme),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.track.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            widget.track.artistText,
                            widget.track.album,
                            widget.track.source,
                          ].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton(
                        icon: isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: isFavorite ? Colors.red : scheme.outline,
                        tooltip: isFavorite ? '取消收藏' : '收藏',
                        onPressed: () => context
                            .read<FavoritesProvider>()
                            .toggleFavorite(widget.track),
                      ),
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
                        _buildActionButton(
                          icon: Icons.download_outlined,
                          color: scheme.outline,
                          tooltip: '下载',
                          onPressed: () => _downloadTrack(
                            context,
                            context.read<DownloadProvider>(),
                            widget.track,
                          ),
                        ),
                      const SizedBox(width: 2),
                      _buildPlayButton(context, scheme),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverArt(String? coverUrl, ColorScheme scheme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: coverUrl != null
            ? Image(
                image: coverImageProvider(coverUrl),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, _) => _buildCoverPlaceholder(scheme),
                frameBuilder: (ctx, child, frame, _) =>
                    frame == null ? _buildCoverPlaceholder(scheme) : child,
              )
            : _buildCoverPlaceholder(scheme),
      ),
    );
  }

  Widget _buildCoverPlaceholder(ColorScheme scheme) {
    return Container(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 20,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context, ColorScheme scheme) {
    return Tooltip(
      message: '立即播放',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playTrack(context),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.primary.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 22,
              color: scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _playTrack(BuildContext context) async {
    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();
    final track = Track.fromGdSearchTrack(widget.track);
    playlistProvider.addOrSelectTrack(track);

    final ok = await playerProvider.resolveAndPlayTrackUrl(
      widget.track,
      br: widget.quality,
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
            content: Text('正在播放: ${widget.track.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _downloadTrack(
    BuildContext context,
    DownloadProvider downloadProvider,
    GdSearchTrack track,
  ) async {
    final result = await downloadProvider.downloadTrack(
      track,
      br: widget.quality,
    );
    if (!context.mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('下载完成: ${track.name}'),
            action: SnackBarAction(
              label: '打开位置',
              onPressed: () async {
                final directory = result.substring(
                  0,
                  result.lastIndexOf(Platform.pathSeparator),
                );
                await Process.run('explorer', [directory]);
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

class _ShimmerItem extends StatefulWidget {
  const _ShimmerItem({required this.index, required this.scheme});

  final int index;
  final ColorScheme scheme;

  @override
  State<_ShimmerItem> createState() => _ShimmerItemState();
}

class _ShimmerItemState extends State<_ShimmerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(opacity: 0.3 + 0.5 * _controller.value, child: child);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.scheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.scheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140.0 + widget.index * 10,
                    height: 13,
                    decoration: BoxDecoration(
                      color: widget.scheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 90,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.scheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
