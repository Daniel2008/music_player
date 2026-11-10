import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/track.dart';
import '../../providers/api_settings_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../services/gd_music_api.dart';
import '../theme/app_design.dart';
import '../widgets/app_surfaces.dart';

class FavoritesWorkspacePage extends StatefulWidget {
  const FavoritesWorkspacePage({super.key});

  @override
  State<FavoritesWorkspacePage> createState() => _FavoritesWorkspacePageState();
}

class _FavoritesWorkspacePageState extends State<FavoritesWorkspacePage> {
  String? _quality;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _quality = context.read<ApiSettingsProvider>().playQuality.brValue;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = context.watch<FavoritesProvider>();
    final apiSettings = context.watch<ApiSettingsProvider>();
    final favorites = favoritesProvider.favorites;
    final quality = _quality ?? apiSettings.playQuality.brValue;

    return Column(
      children: [
        AppPageHeader(
          title: '收藏',
          subtitle: '${favorites.length} 首在线歌曲',
          eyebrow: '音乐库',
          icon: Icons.library_music_rounded,
          actions: [
            if (favorites.isNotEmpty)
              FilledButton.tonalIcon(
                onPressed: () => _playAll(context, favorites, quality),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('播放全部'),
              ),
            _QualityPicker(
              quality: quality,
              onChanged: (value) => setState(() => _quality = value),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: AppPanel(
              padding: EdgeInsets.zero,
              child: favorites.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.library_music_outlined,
                      title: '暂无收藏',
                      description: '在搜索结果中收藏歌曲后，会统一显示在这里。',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: favorites.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final track = favorites[index];
                        return _FavoriteRow(track: track, quality: quality);
                      },
                    ),
            ),
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
    final player = context.read<PlayerProvider>();
    final playlist = context.read<PlaylistProvider>();
    playlist.clear();
    for (final item in favorites) {
      playlist.addTrack(Track.fromGdSearchTrack(item));
    }
    playlist.setCurrentIndex(0);

    final ok = await player.resolveAndPlayTrackUrl(
      favorites.first,
      br: quality,
      playlistProvider: playlist,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(player.playError ?? '播放失败')));
    }
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({required this.track, required this.quality});

  final GdSearchTrack track;
  final String quality;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gdApi = context.read<GdMusicApiClient>();
    final coverUrl = gdApi.buildCoverUrl(track.picId, track.source);

    return AppMediaRow(
      title: track.name,
      subtitle: [
        track.artistText,
        track.album,
        track.source,
      ].where((text) => text.isNotEmpty).join('  ·  '),
      leading: AppCover(
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
            tooltip: '取消收藏',
            icon: Icon(Icons.favorite_rounded, size: 19, color: scheme.primary),
          ),
          IconButton.filled(
            onPressed: () => _play(context),
            tooltip: '播放',
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
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(player.playError ?? '播放失败')));
    }
  }
}

class _QualityPicker extends StatelessWidget {
  const _QualityPicker({required this.quality, required this.onChanged});

  final String quality;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = AudioQuality.values.firstWhere(
      (item) => item.brValue == quality,
      orElse: () => AudioQuality.values.first,
    );

    final scheme = context.scheme;
    return PopupMenuButton<AudioQuality>(
      initialValue: selected,
      onSelected: (value) => onChanged(value.brValue),
      itemBuilder: (context) => AudioQuality.values
          .map(
            (item) => PopupMenuItem(
              value: item,
              child: Text('${item.label}  ${item.description}'),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: context.visual.accentSurface,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.high_quality_rounded, size: 18, color: scheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              selected.label,
              style: context.textStyles.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
