import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/track.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/theme_provider.dart';
import 'playback_controls.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playlist = context.watch<PlaylistProvider>();
    final player = context.watch<PlayerProvider>();
    final visual = Theme.of(context).extension<AppVisualTheme>()!;
    final track = _currentTrack(playlist);

    if (track == null) {
      return _buildEmptyState(context, playlist);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showVolume = width >= 1120;
        final showArtist = width >= 900;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: visual.panel,
            border: Border(top: BorderSide(color: visual.border)),
          ),
          child: width < 620
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _AlbumArtwork(
                          track: track,
                          isPlaying: player.isPlaying,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TrackIdentity(track: track, showArtist: true),
                        ),
                        PlaybackControls(
                          player: player,
                          playlist: playlist,
                          compact: true,
                          showMode: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PlaybackTimeline(player: player, compact: true),
                  ],
                )
              : Row(
                  children: [
                    _AlbumArtwork(track: track, isPlaying: player.isPlaying),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: showArtist ? 190 : 132,
                      child: _TrackIdentity(
                        track: track,
                        showArtist: showArtist,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 330),
                        child: PlaybackTimeline(
                          player: player,
                          compact: true,
                          showTimeLabels: width >= 1040,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    PlaybackControls(
                      player: player,
                      playlist: playlist,
                      compact: true,
                      showMode: width >= 980,
                    ),
                    if (showVolume) ...[
                      const SizedBox(width: 18),
                      PlaybackVolume(player: player, compact: true),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Track? _currentTrack(PlaylistProvider playlist) {
    final validIndex =
        playlist.currentIndex >= 0 &&
        playlist.currentIndex < playlist.tracks.length;
    return validIndex ? playlist.current : null;
  }

  Widget _buildEmptyState(BuildContext context, PlaylistProvider playlist) {
    final scheme = Theme.of(context).colorScheme;
    final visual = Theme.of(context).extension<AppVisualTheme>()!;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: visual.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: visual.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 19,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Text(
            '播放队列为空',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: playlist.addFiles,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('添加音乐'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumArtwork extends StatelessWidget {
  const _AlbumArtwork({required this.track, required this.isPlaying});

  final Track track;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.music_note_rounded,
        size: 20,
        color: scheme.onSurfaceVariant,
      ),
    );

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: track.artUri == null
                  ? placeholder
                  : Image(
                      image: coverImageProvider(track.artUri!, size: 48),
                      fit: BoxFit.cover,
                      frameBuilder: (context, child, frame, _) =>
                          frame == null ? placeholder : child,
                      errorBuilder: (context, error, stackTrace) => placeholder,
                    ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isPlaying ? scheme.primary : scheme.outline,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackIdentity extends StatelessWidget {
  const _TrackIdentity({required this.track, required this.showArtist});

  final Track track;
  final bool showArtist;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (showArtist) ...[
          const SizedBox(height: 3),
          Text(
            track.artist?.isNotEmpty == true
                ? track.artist!
                : (track.isRemote ? '在线音乐' : '本地音乐'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ],
    );
  }
}
