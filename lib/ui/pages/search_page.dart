import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
              ? _buildErrorState(scheme, searchProvider)
              : searchProvider.isSearching
              ? _buildShimmerLoading(scheme)
              : searchProvider.searchResults.isEmpty
              ? _buildEmptyState(scheme)
              : _SearchResultList(
                  items: searchProvider.searchResults,
                  quality: currentQuality,
                ),
        ),
      ],
    );
  }

  /// 骨架屏加载动画
  Widget _buildShimmerLoading(ColorScheme scheme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 8,
      itemBuilder: (context, index) {
        return _ShimmerItem(index: index, scheme: scheme);
      },
    );
  }

  /// 空状态
  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.5),
                  scheme.tertiaryContainer.withValues(alpha: 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.search_rounded,
              size: 36,
              color: scheme.primary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '搜索在线音乐',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '输入歌名、歌手或专辑名称',
            style: TextStyle(
              color: scheme.outline.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// 错误状态
  Widget _buildErrorState(ColorScheme scheme, SearchProvider searchProvider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.errorContainer.withValues(alpha: 0.3),
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 28,
              color: scheme.error.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '搜索失败',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 280,
            child: Text(
              searchProvider.searchError!,
              style: TextStyle(color: scheme.outline, fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => _search(searchProvider),
            child: const Text('重试'),
          ),
        ],
      ),
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
            padding: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
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

class _SearchResultItem extends StatefulWidget {
  final GdSearchTrack track;
  final int index;
  final String quality;

  const _SearchResultItem({
    required this.track,
    required this.index,
    required this.quality,
  });

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
    // 交错入场动画
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
    // 性能优化：只 watch 跟此组件渲染直接相关的 Provider
    // PlayerProvider 不需要 watch — 不需要响应播放进度变化
    final favoritesProvider = context.watch<FavoritesProvider>();
    final downloadProvider = context.watch<DownloadProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isDownloading = downloadProvider.isDownloading(
      widget.track.source,
      widget.track.id,
    );
    final downloadProgress = downloadProvider.getDownloadProgress(
      widget.track.source,
      widget.track.id,
    );
    final isFavorite = favoritesProvider.isFavorite(widget.track);

    // 构建封面 URL
    final gdApi = context.read<GdMusicApiClient>();
    final coverUrl = gdApi.buildCoverUrl(widget.track.picId, widget.track.source);

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
                      // 收藏按钮
                      _buildActionButton(
                        icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : scheme.outline,
                        tooltip: isFavorite ? '取消收藏' : '收藏',
                        onPressed: () => favoritesProvider.toggleFavorite(widget.track),
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
                        _buildActionButton(
                          icon: Icons.download_outlined,
                          color: scheme.outline,
                          tooltip: '下载',
                          onPressed: () => _downloadTrack(context, downloadProvider, widget.track),
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
            ? CachedNetworkImage(
                imageUrl: coverUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (ctx, url) => _buildCoverPlaceholder(scheme),
                errorWidget: (ctx, url, err) => _buildCoverPlaceholder(scheme),
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
    GdSearchTrack t,
  ) async {
    final result = await downloadProvider.downloadTrack(t, br: widget.quality);
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

/// 骨架屏动画条目
class _ShimmerItem extends StatefulWidget {
  final int index;
  final ColorScheme scheme;

  const _ShimmerItem({required this.index, required this.scheme});

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
    // Stagger the animation start
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
        return Opacity(
          opacity: 0.3 + 0.5 * _controller.value,
          child: child,
        );
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
            // 封面骨架
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.scheme.surfaceContainerHighest.withValues(alpha: 0.4),
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
                      color: widget.scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 90,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.scheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
