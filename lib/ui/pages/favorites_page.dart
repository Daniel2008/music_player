import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/api_settings_provider.dart';
import '../../models/track.dart';
import '../../services/gd_music_api.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String? _quality;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apiSettings = context.read<ApiSettingsProvider>();
      setState(() {
        _quality = apiSettings.playQuality.brValue;
      });
    });
  }

  List<(String, String)> _getQualityOptions() {
    return AudioQuality.values
        .map((q) => (q.brValue, '${q.description} ${q.label}'))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = context.watch<FavoritesProvider>();
    final apiSettings = context.watch<ApiSettingsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favorites = favoritesProvider.favorites;

    final currentQuality = _quality ?? apiSettings.playQuality.brValue;

    return Column(
      children: [
        // 头部 — 毛玻璃效果
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      Colors.red.withValues(alpha: 0.08),
                      scheme.surface,
                    ]
                  : [
                      Colors.red.withValues(alpha: 0.05),
                      scheme.surfaceContainerLow,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              // 收藏图标 — 带发光效果
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withValues(alpha: 0.8),
                      Colors.pink.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '我的收藏',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${favorites.length} 首歌曲',
                      style: TextStyle(
                        color: scheme.outline,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // 播放全部按钮
              if (favorites.isNotEmpty) ...[
                FilledButton.tonalIcon(
                  onPressed: () => _playAll(context, favorites, currentQuality),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('播放全部'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // 音质选择
              PopupMenuButton<String>(
                initialValue: currentQuality,
                onSelected: (v) => setState(() => _quality = v),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Chip(
                  label: Text(
                    _getQualityOptions()
                        .firstWhere(
                          (e) => e.$1 == currentQuality,
                          orElse: () => (currentQuality, currentQuality),
                        )
                        .$2,
                    style: const TextStyle(fontSize: 13),
                  ),
                  avatar: const Icon(Icons.high_quality, size: 18),
                ),
                itemBuilder: (context) => _getQualityOptions()
                    .map((e) => PopupMenuItem(value: e.$1, child: Text(e.$2)))
                    .toList(),
              ),
            ],
          ),
        ),

        // 收藏列表
        Expanded(
          child: favorites.isEmpty
              ? _buildEmptyState(scheme)
              : ListView.builder(
                  itemCount: favorites.length,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  itemBuilder: (context, index) {
                    final t = favorites[index];
                    return _FavoriteItem(
                      track: t,
                      index: index,
                      quality: currentQuality,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 渐变圆形图标
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.red.withValues(alpha: 0.15),
                  Colors.pink.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: 40,
              color: Colors.red.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无收藏',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在搜索结果中点击 ❤ 添加收藏',
            style: TextStyle(
              color: scheme.outline.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playAll(
    BuildContext context,
    List<GdSearchTrack> favorites,
    String quality,
  ) async {
    if (favorites.isEmpty) return;

    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();

    // 清空当前播放列表
    playlistProvider.clear();

    // 将所有收藏添加到播放列表
    for (final item in favorites) {
      playlistProvider.addTrack(Track.fromGdSearchTrack(item));
    }

    // 设置当前播放索引为第一首
    playlistProvider.setCurrentIndex(0);

    // 播放第一首
    final first = favorites.first;
    final ok = await playerProvider.resolveAndPlayTrackUrl(
      first,
      br: quality,
      playlistProvider: playlistProvider,
    );

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(playerProvider.playError ?? '播放失败')),
        );
    }
  }
}

class _FavoriteItem extends StatefulWidget {
  final GdSearchTrack track;
  final int index;
  final String quality;

  const _FavoriteItem({
    required this.track,
    required this.index,
    required this.quality,
  });

  @override
  State<_FavoriteItem> createState() => _FavoriteItemState();
}

class _FavoriteItemState extends State<_FavoriteItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = context.read<FavoritesProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 构建封面 URL
    final gdApi = context.read<GdMusicApiClient>();
    final coverUrl = gdApi.buildCoverUrl(widget.track.picId, widget.track.source);

    return Dismissible(
      key: ValueKey('fav_${widget.track.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              scheme.error.withValues(alpha: 0.15),
              scheme.error.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: scheme.error,
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        return true;
      },
      onDismissed: (direction) {
        favoritesProvider.toggleFavorite(widget.track);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('已取消收藏: ${widget.track.name}'),
              action: SnackBarAction(
                label: '撤销',
                onPressed: () => favoritesProvider.toggleFavorite(widget.track),
              ),
            ),
          );
      },
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
                // 封面图
                _buildCoverArt(coverUrl, scheme),
                const SizedBox(width: 14),
                // 歌曲信息
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
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 操作按钮
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 取消收藏按钮
                    Tooltip(
                      message: '取消收藏',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => favoritesProvider.toggleFavorite(widget.track),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 播放按钮
                    const SizedBox(width: 2),
                    _buildPlayButton(context, scheme),
                  ],
                ),
              ],
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
        color: Colors.red.withValues(alpha: 0.1),
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
            ? CachedNetworkImage(
                imageUrl: coverUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (ctx, url) => _buildCoverPlaceholder(),
                errorWidget: (ctx, url, err) => _buildCoverPlaceholder(),
              )
            : _buildCoverPlaceholder(),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      color: Colors.red.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 20,
          color: Colors.red.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context, ColorScheme scheme) {
    return Tooltip(
      message: '播放',
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
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.8),
                ],
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
    final newTrack = Track.fromGdSearchTrack(widget.track);
    playlistProvider.addOrSelectTrack(newTrack);

    // 解析并播放
    final ok = await playerProvider.resolveAndPlayTrackUrl(
      widget.track,
      br: widget.quality,
      playlistProvider: playlistProvider,
    );

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(playerProvider.playError ?? '播放失败')),
        );
    }
  }
}
