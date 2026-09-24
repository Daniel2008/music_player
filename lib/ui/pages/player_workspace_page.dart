import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/track.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/lyric_view.dart';
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
        if (constraints.maxWidth >= 980) {
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
    final playlistWidth = math.min(
      400.0,
      math.max(320.0, constraints.maxWidth * 0.32),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildNowPlaying(context, track),
                const SizedBox(height: 12),
                Expanded(child: _buildContentPanel(context)),
              ],
            ),
          ),
          if (_playlistExpanded) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: playlistWidth,
              child: const AppPanel(
                padding: EdgeInsets.all(12),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildNowPlaying(context, track),
          const SizedBox(height: 12),
          SizedBox(height: 420, child: _buildContentPanel(context)),
          if (_playlistExpanded) ...[
            const SizedBox(height: 12),
            const SizedBox(
              height: 440,
              child: AppPanel(
                padding: EdgeInsets.all(12),
                child: PlaylistPanel(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNowPlaying(BuildContext context, Track? track) {
    final scheme = Theme.of(context).colorScheme;
    final player = context.read<PlayerProvider>();
    final isPlaying = context.select<PlayerProvider, bool>(
      (provider) => provider.isPlaying,
    );

    return AppPanel(
      padding: const EdgeInsets.all(18),
      elevated: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final artwork = _buildArtwork(track, compact ? 92 : 116);
          final details = _buildTrackDetails(context, track, isPlaying);
          final actions = _buildNowPlayingActions(context, scheme);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            artwork,
                            const SizedBox(width: 16),
                            Expanded(child: details),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Align(alignment: Alignment.centerRight, child: actions),
                      ],
                    )
                  : Row(
                      children: [
                        artwork,
                        const SizedBox(width: 18),
                        Expanded(child: details),
                        const SizedBox(width: 16),
                        actions,
                      ],
                    ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: player.timelineListenable,
                builder: (context, _) {
                  final duration = player.duration.inMilliseconds;
                  final progress = duration <= 0
                      ? 0.0
                      : (player.position.inMilliseconds / duration).clamp(
                          0.0,
                          1.0,
                        );
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Text(
                            _formatDuration(player.position),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDuration(player.duration),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrackDetails(
    BuildContext context,
    Track? track,
    bool isPlaying,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final title = track?.title ?? '未选择曲目';
    final artist = track?.artist ?? (track?.isRemote == true ? '在线音乐' : '本地音乐');
    final source = track?.remoteSource?.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isPlaying ? scheme.primary : scheme.outline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              isPlaying ? '正在播放' : '已暂停',
              style: TextStyle(
                color: isPlaying ? scheme.primary : scheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (source != null && source.isNotEmpty) ...[
              const SizedBox(width: 10),
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
        ),
        const SizedBox(height: 9),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildArtwork(Track? track, double size) {
    final scheme = Theme.of(context).colorScheme;
    final artUri = track?.artUri;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.album_rounded,
          size: size * 0.34,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: artUri == null
            ? placeholder
            : Image(
                image: coverImageProvider(artUri, size: size.round()),
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

  Widget _buildNowPlayingActions(BuildContext context, ColorScheme scheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStyleSelector(context, scheme),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => _openFullscreenVisualizer(context),
          tooltip: '全屏频谱',
          icon: const Icon(Icons.fullscreen_rounded, size: 20),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () =>
              setState(() => _playlistExpanded = !_playlistExpanded),
          tooltip: _playlistExpanded ? '收起播放列表' : '展开播放列表',
          icon: Icon(
            _playlistExpanded
                ? Icons.view_sidebar_rounded
                : Icons.view_sidebar_outlined,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildContentPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: AppSectionTitle(
                    title: _contentView == _PlayerContentView.visualizer
                        ? '音频可视化'
                        : '同步歌词',
                    subtitle: _contentView == _PlayerContentView.visualizer
                        ? '实时频谱与波形'
                        : '点击歌词可跳转播放位置',
                  ),
                ),
                SegmentedButton<_PlayerContentView>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _PlayerContentView.visualizer,
                      icon: Icon(Icons.graphic_eq_rounded, size: 18),
                      label: Text('频谱'),
                    ),
                    ButtonSegment(
                      value: _PlayerContentView.lyrics,
                      icon: Icon(Icons.lyrics_outlined, size: 18),
                      label: Text('歌词'),
                    ),
                  ],
                  selected: {_contentView},
                  onSelectionChanged: (selection) {
                    setState(() => _contentView = selection.first);
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _contentView == _PlayerContentView.visualizer
                  ? VisualizerView(
                      showStyleSelector: false,
                      fixedStyle: _visualizerStyle,
                    )
                  : const LyricView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleSelector(BuildContext context, ColorScheme scheme) {
    return PopupMenuButton<VisualizerStyle>(
      tooltip: '频谱样式',
      initialValue: _visualizerStyle,
      onSelected: (style) => setState(() => _visualizerStyle = style),
      itemBuilder: (context) => VisualizerStyle.values
          .map(
            (style) => PopupMenuItem(
              value: style,
              child: Row(
                children: [
                  Icon(
                    style.icon,
                    size: 18,
                    color: style == _visualizerStyle ? scheme.primary : null,
                  ),
                  const SizedBox(width: 10),
                  Text(style.displayName),
                ],
              ),
            ),
          )
          .toList(),
      icon: Icon(_visualizerStyle.icon, size: 20),
    );
  }

  void _openFullscreenVisualizer(BuildContext context) {
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final hours = duration.inHours;
    final base =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return hours > 0 ? '${hours.toString().padLeft(2, '0')}:$base' : base;
  }
}
