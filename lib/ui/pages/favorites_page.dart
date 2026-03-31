import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final favorites = favoritesProvider.favorites;

    final currentQuality = _quality ?? apiSettings.playQuality.brValue;

    return Column(
      children: [
        // 头部
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 28),
              const SizedBox(width: 12),
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
                    Text(
                      '${favorites.length} 首歌曲',
                      style: TextStyle(color: scheme.outline),
                    ),
                  ],
                ),
              ),
              // 播放全部按钮
              if (favorites.isNotEmpty) ...[
                FilledButton.tonalIcon(
                  onPressed: () => _playAll(context, favorites, currentQuality),
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('播放全部'),
                ),
                const SizedBox(width: 12),
              ],
              // 音质选择
              PopupMenuButton<String>(
                initialValue: currentQuality,
                onSelected: (v) => setState(() => _quality = v),
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
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 64,
                        color: scheme.outline.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无收藏',
                        style: TextStyle(color: scheme.outline, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '在搜索结果中点击 ❤ 添加收藏',
                        style: TextStyle(color: scheme.outline, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: favorites.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
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

class _FavoriteItem extends StatelessWidget {
  final GdSearchTrack track;
  final int index;
  final String quality;

  const _FavoriteItem({
    required this.track,
    required this.index,
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        child: const Icon(Icons.music_note, color: Colors.red),
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
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.red),
            tooltip: '取消收藏',
            onPressed: () async {
              await favoritesProvider.toggleFavorite(track);
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_filled),
            tooltip: '播放',
            color: scheme.primary,
            onPressed: () =>
                _playTrack(context, playerProvider, playlistProvider),
          ),
        ],
      ),
    );
  }

  Future<void> _playTrack(
    BuildContext context,
    PlayerProvider playerProvider,
    PlaylistProvider playlistProvider,
  ) async {
    final newTrack = Track.fromGdSearchTrack(track);
    playlistProvider.addOrSelectTrack(newTrack);

    // 解析并播放
    final ok = await playerProvider.resolveAndPlayTrackUrl(
      track,
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
