import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/track.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/lyric_view.dart';
import '../widgets/playback_controls.dart';
import '../widgets/playlist_panel.dart';
import '../widgets/visualizer_view.dart';
import 'visualizer_fullscreen_page.dart';

enum _PlayerContentView { visualizer, lyrics }

class PlayerWorkspacePage extends StatefulWidget {
  const PlayerWorkspacePage({super.key});

  @override
  State<PlayerWorkspacePage> createState() => _PlayerWorkspacePageState();
}

class _PlayerWorkspacePageState extends State<PlayerWorkspacePage> {
  _PlayerContentView _contentView = _PlayerContentView.visualizer;
  VisualizerStyle _visualizerStyle = VisualizerStyle.bars;
  bool _playlistExpanded = true;

  @override
  Widget build(BuildContext context) {
    final playlist = context.watch<PlaylistProvider>();
    final track = _currentTrack(playlist);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 920 && constraints.maxHeight >= 520) {
          return _buildWideLayout(context, constraints, track);
        }
        return _buildNarrowLayout(context, track);
      },
    );
  }

  Track? _currentTrack(PlaylistProvider playlist) {
    final hasValidIndex =
        playlist.currentIndex >= 0 &&
        playlist.currentIndex < playlist.tracks.length;
    return hasValidIndex ? playlist.current : null;
  }

  Widget _buildWideLayout(
    BuildContext context,
    BoxConstraints constraints,
    Track? track,
  ) {
    final queueWidth = math.min(
      320.0,
      math.max(280.0, constraints.maxWidth * 0.27),
    );
    final contentHeight = (constraints.maxHeight * 0.33).clamp(176.0, 232.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _NowPlayingStage(
                    track: track,
                    contentView: _contentView,
                    visualizerStyle: _visualizerStyle,
                    playlistExpanded: _playlistExpanded,
                    onContentViewChanged: (view) {
                      setState(() => _contentView = view);
                    },
                    onVisualizerStyleChanged: (style) {
                      setState(() => _visualizerStyle = style);
                    },
                    onTogglePlaylist: () {
                      setState(() => _playlistExpanded = !_playlistExpanded);
                    },
                    onOpenFullscreen: _openFullscreenVisualizer,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: contentHeight,
                  child: _buildContentPanel(context),
                ),
              ],
            ),
          ),
          if (_playlistExpanded) ...[
            const SizedBox(width: 24),
            SizedBox(
              width: queueWidth,
              child: const AppPanel(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: PlaylistPanel(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context, Track? track) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 350,
            child: _NowPlayingStage(
              track: track,
              contentView: _contentView,
              visualizerStyle: _visualizerStyle,
              playlistExpanded: _playlistExpanded,
              onContentViewChanged: (view) {
                setState(() => _contentView = view);
              },
              onVisualizerStyleChanged: (style) {
                setState(() => _visualizerStyle = style);
              },
              onTogglePlaylist: () {
                setState(() => _playlistExpanded = !_playlistExpanded);
              },
              onOpenFullscreen: _openFullscreenVisualizer,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 240, child: _buildContentPanel(context)),
          if (_playlistExpanded) ...[
            const SizedBox(height: 12),
            const SizedBox(
              height: 460,
              child: AppPanel(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: PlaylistPanel(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentPanel(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(10),
      child: _contentView == _PlayerContentView.visualizer
          ? VisualizerView(
              showStyleSelector: false,
              fixedStyle: _visualizerStyle,
              maxFps: 24,
            )
          : const LyricView(),
    );
  }

  void _openFullscreenVisualizer() {
    final playerProvider = context.read<PlayerProvider>();
    final playlistProvider = context.read<PlaylistProvider>();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: playerProvider),
            ChangeNotifierProvider.value(value: playlistProvider),
          ],
          child: const VisualizerFullscreenPage(),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }
}

class _NowPlayingStage extends StatelessWidget {
  const _NowPlayingStage({
    required this.track,
    required this.contentView,
    required this.visualizerStyle,
    required this.playlistExpanded,
    required this.onContentViewChanged,
    required this.onVisualizerStyleChanged,
    required this.onTogglePlaylist,
    required this.onOpenFullscreen,
  });

  final Track? track;
  final _PlayerContentView contentView;
  final VisualizerStyle visualizerStyle;
  final bool playlistExpanded;
  final ValueChanged<_PlayerContentView> onContentViewChanged;
  final ValueChanged<VisualizerStyle> onVisualizerStyleChanged;
  final VoidCallback onTogglePlaylist;
  final VoidCallback onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final artSize = compact
            ? 128.0
            : math
                  .min(constraints.maxHeight - 52, constraints.maxWidth * 0.36)
                  .clamp(164.0, 300.0);

        return Padding(
          padding: EdgeInsets.all(compact ? 18 : 24),
          child: compact
              ? _buildCompactStage(context, scheme, artSize)
              : _buildWideStage(context, scheme, artSize),
        );
      },
    );
  }

  Widget _buildWideStage(
    BuildContext context,
    ColorScheme scheme,
    double artSize,
  ) {
    final player = context.watch<PlayerProvider>();
    final playlist = context.read<PlaylistProvider>();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AlbumArtwork(track: track, size: artSize),
        const SizedBox(width: 28),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StageHeader(
                track: track,
                contentView: contentView,
                visualizerStyle: visualizerStyle,
                playlistExpanded: playlistExpanded,
                onContentViewChanged: onContentViewChanged,
                onVisualizerStyleChanged: onVisualizerStyleChanged,
                onTogglePlaylist: onTogglePlaylist,
                onOpenFullscreen: onOpenFullscreen,
              ),
              const Spacer(),
              Text(
                track?.title ?? '未选择曲目',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 24,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _artistText(track),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              PlaybackTimeline(player: player),
              const SizedBox(height: 10),
              Row(
                children: [
                  PlaybackControls(player: player, playlist: playlist),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStage(
    BuildContext context,
    ColorScheme scheme,
    double artSize,
  ) {
    final player = context.watch<PlayerProvider>();
    final playlist = context.read<PlaylistProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _AlbumArtwork(track: track, size: artSize),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlaybackState(track: track),
                  const SizedBox(height: 8),
                  Text(
                    track?.title ?? '未选择曲目',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 21,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _artistText(track),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onTogglePlaylist,
              tooltip: playlistExpanded ? '收起播放队列' : '展开播放队列',
              icon: Icon(
                playlistExpanded
                    ? Icons.view_sidebar_rounded
                    : Icons.view_sidebar_outlined,
              ),
            ),
          ],
        ),
        const Spacer(),
        PlaybackTimeline(player: player, compact: true),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            PlaybackControls(player: player, playlist: playlist, compact: true),
            _ContentViewToggle(
              value: contentView,
              onChanged: onContentViewChanged,
              compact: true,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _VisualizerStyleButton(
              style: visualizerStyle,
              onChanged: onVisualizerStyleChanged,
              compact: true,
            ),
            const Spacer(),
            IconButton(
              onPressed: onOpenFullscreen,
              tooltip: '全屏频谱',
              icon: const Icon(Icons.fullscreen_rounded),
            ),
          ],
        ),
      ],
    );
  }

  String _artistText(Track? track) {
    if (track == null) return 'Music Player';
    if (track.artist != null && track.artist!.isNotEmpty) {
      return track.artist!;
    }
    return track.isRemote ? '在线音乐' : '本地音乐';
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({
    required this.track,
    required this.contentView,
    required this.visualizerStyle,
    required this.playlistExpanded,
    required this.onContentViewChanged,
    required this.onVisualizerStyleChanged,
    required this.onTogglePlaylist,
    required this.onOpenFullscreen,
  });

  final Track? track;
  final _PlayerContentView contentView;
  final VisualizerStyle visualizerStyle;
  final bool playlistExpanded;
  final ValueChanged<_PlayerContentView> onContentViewChanged;
  final ValueChanged<VisualizerStyle> onVisualizerStyleChanged;
  final VoidCallback onTogglePlaylist;
  final VoidCallback onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PlaybackState(track: track),
        _ContentViewToggle(value: contentView, onChanged: onContentViewChanged),
        const SizedBox(width: 6),
        _VisualizerStyleButton(
          style: visualizerStyle,
          onChanged: onVisualizerStyleChanged,
        ),
        IconButton(
          onPressed: onOpenFullscreen,
          tooltip: '全屏频谱',
          icon: const Icon(Icons.fullscreen_rounded, size: 19),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: onTogglePlaylist,
          tooltip: playlistExpanded ? '收起播放队列' : '展开播放队列',
          icon: Icon(
            playlistExpanded
                ? Icons.view_sidebar_rounded
                : Icons.view_sidebar_outlined,
            size: 19,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _PlaybackState extends StatelessWidget {
  const _PlaybackState({required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPlaying = context.select<PlayerProvider, bool>(
      (provider) => provider.isPlaying,
    );
    final source = track?.remoteSource?.toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPlaying ? scheme.primary : scheme.outline,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isPlaying ? '正在播放' : (track == null ? '等待播放' : '已暂停'),
          style: TextStyle(
            color: isPlaying ? scheme.primary : scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (source != null && source.isNotEmpty) ...[
          const SizedBox(width: 9),
          Container(width: 1, height: 11, color: scheme.outlineVariant),
          const SizedBox(width: 9),
          Text(
            source,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _AlbumArtwork extends StatelessWidget {
  const _AlbumArtwork({required this.track, required this.size});

  final Track? track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.album_rounded,
          size: size * 0.32,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: track?.artUri == null
            ? placeholder
            : Image(
                image: coverImageProvider(track!.artUri!, size: size.round()),
                width: size,
                height: size,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, _) =>
                    frame == null ? placeholder : child,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}

class _ContentViewToggle extends StatelessWidget {
  const _ContentViewToggle({
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final _PlayerContentView value;
  final ValueChanged<_PlayerContentView> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget item(String label, IconData icon, _PlayerContentView itemValue) {
      final selected = value == itemValue;
      return Tooltip(
        message: label,
        child: InkWell(
          onTap: () => onChanged(itemValue),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 7 : 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: compact ? 16 : 17,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item('频谱', Icons.graphic_eq_rounded, _PlayerContentView.visualizer),
          item('歌词', Icons.lyrics_outlined, _PlayerContentView.lyrics),
        ],
      ),
    );
  }
}

class _VisualizerStyleButton extends StatelessWidget {
  const _VisualizerStyleButton({
    required this.style,
    required this.onChanged,
    this.compact = false,
  });

  final VisualizerStyle style;
  final ValueChanged<VisualizerStyle> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<VisualizerStyle>(
      tooltip: '频谱样式',
      initialValue: style,
      onSelected: onChanged,
      icon: Icon(
        style.icon,
        size: compact ? 19 : 20,
        color: scheme.onSurfaceVariant,
      ),
      itemBuilder: (context) => VisualizerStyle.values
          .map(
            (item) => PopupMenuItem(
              value: item,
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 18,
                    color: item == style ? scheme.primary : null,
                  ),
                  const SizedBox(width: 10),
                  Text(item.displayName),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
