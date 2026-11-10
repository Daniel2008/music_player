import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/track.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../theme/app_design.dart';
import 'playback_controls.dart';
import 'surface_texture.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PlaylistProvider, Track?>(
      selector: (_, playlist) => _currentTrack(playlist),
      builder: (context, track, _) {
        final playlist = context.read<PlaylistProvider>();
        final player = context.read<PlayerProvider>();

        if (track == null) {
          return _buildEmptyState(context, playlist);
        }

        return _buildPlayerBar(
          context,
          track: track,
          player: player,
          playlist: playlist,
        );
      },
    );
  }

  Widget _buildPlayerBar(
    BuildContext context, {
    required Track track,
    required PlayerProvider player,
    required PlaylistProvider playlist,
  }) {
    final visual = context.visual;
    final scheme = context.scheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showVolume = width >= AppBreakpoints.playerShowVolume;
        final showArtist = width >= AppBreakpoints.playerShowArtist;
        final compact = width < AppBreakpoints.playerCompactPadding;

        return Container(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : AppSpacing.xl,
            vertical: compact ? 10 : 9,
          ),
          decoration: BoxDecoration(
            color: visual.panel,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.14),
                  visual.panel,
                ),
                visual.panel,
                Color.alphaBlend(
                  scheme.tertiary.withValues(alpha: 0.06),
                  visual.panel,
                ),
              ],
              stops: const [0, 0.58, 1],
            ),
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: visual.border),
            boxShadow: AppShadows.soft(
              visual.shadow.withValues(alpha: context.isDark ? 0.18 : 0.06),
            ),
          ),
          child: TexturedSurface(
            kind: SurfaceTextureKind.brushed,
            child: width < AppBreakpoints.playerStacked
                ? _buildStackedPlayer(
                    context,
                    track: track,
                    player: player,
                    playlist: playlist,
                    showTimeLabels: width >= AppBreakpoints.playerCompactTime,
                  )
                : Row(
                    children: [
                      _buildArtwork(context, track),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(
                        width: showArtist ? 190 : 132,
                        child: _TrackIdentity(
                          track: track,
                          showArtist: showArtist,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 330),
                          child: PlaybackTimeline(
                            player: player,
                            compact: true,
                            showTimeLabels:
                                width >= AppBreakpoints.playerShowTime,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      PlaybackControls(
                        player: player,
                        playlist: playlist,
                        compact: true,
                        showMode: width >= AppBreakpoints.playerShowMode,
                      ),
                      if (showVolume) ...[
                        const SizedBox(width: AppSpacing.xl),
                        PlaybackVolume(player: player, compact: true),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildStackedPlayer(
    BuildContext context, {
    required Track track,
    required PlayerProvider player,
    required PlaylistProvider playlist,
    required bool showTimeLabels,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _buildArtwork(context, track),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _TrackIdentity(track: track, showArtist: true)),
            PlaybackControls(
              player: player,
              playlist: playlist,
              compact: true,
              showMode: false,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        PlaybackTimeline(
          player: player,
          compact: true,
          showTimeLabels: showTimeLabels,
        ),
      ],
    );
  }

  Widget _buildArtwork(BuildContext context, Track track) {
    return Selector<PlayerProvider, bool>(
      selector: (_, player) => player.isPlaying,
      builder: (_, isPlaying, _) {
        return _AlbumArtwork(track: track, isPlaying: isPlaying);
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
    final scheme = context.scheme;
    final visual = context.visual;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: visual.panel,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: visual.border),
        boxShadow: AppShadows.soft(
          visual.shadow.withValues(alpha: context.isDark ? 0.14 : 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: visual.accentSurface,
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(
              Icons.queue_music_rounded,
              size: 18,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '播放队列为空',
              style: context.textStyles.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: playlist.addFiles,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('添加音乐'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: context.textStyles.labelMedium,
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
    final scheme = context.scheme;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: 20,
        color: scheme.onPrimaryContainer,
      ),
    );

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: track.artUri == null
                  ? placeholder
                  : Image(
                      image: coverImageProvider(track.artUri!, size: 52),
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
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant, width: 0.5),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: AppMotion.normal,
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isPlaying ? scheme.primary : scheme.outline,
                    shape: BoxShape.circle,
                    boxShadow: isPlaying
                        ? AppShadows.glow(scheme.primary, alpha: 0.5)
                        : null,
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
    final scheme = context.scheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyles.titleSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (showArtist) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            track.artist?.isNotEmpty == true
                ? track.artist!
                : (track.isRemote ? '在线音乐' : '本地音乐'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
