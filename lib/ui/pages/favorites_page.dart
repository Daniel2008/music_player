import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../services/gd_music_api.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String _quality = '320';

  static const _qualities = [
    ('128', '标准 128k'),
    ('192', '较高 192k'),
    ('320', '高品 320k'),
    ('999', '无损'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlayerProvider>();
    final scheme = Theme.of(context).colorScheme;
    final favorites = p.favorites.favorites;

    return Column(
      children: [
        // 头部
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant.withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.favorite, color: Colors.red, size: 28),
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
              // 音质选择
              PopupMenuButton<String>(
                initialValue: _quality,
                onSelected: (v) => setState(() => _quality = v),
                child: Chip(
                  label: Text(
                    _qualities.firstWhere((e) => e.$1 == _quality).$2,
                    style: const TextStyle(fontSize: 13),
                  ),
                  avatar: const Icon(Icons.high_quality, size: 18),
                ),
                itemBuilder: (context) => _qualities
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
                        color: scheme.outline.withOpacity(0.5),
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
                      quality: _quality,
                    );
                  },
                ),
        ),
      ],
    );
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
    final p = context.read<PlayerProvider>();
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.red.withOpacity(0.1),
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
              await p.toggleFavorite(track);
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_filled),
            tooltip: '播放',
            color: scheme.primary,
            onPressed: () async {
              final ok = await p.playSearchResult(track, br: quality);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(content: Text(p.playError ?? '播放失败')),
                  );
              }
            },
          ),
        ],
      ),
    );
  }
}
