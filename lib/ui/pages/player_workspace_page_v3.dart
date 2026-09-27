import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/lyric_view.dart';
import '../widgets/playlist_panel.dart';
import '../widgets/visualizer_view.dart';
import 'visualizer_fullscreen_page.dart';

class PlayerWorkspacePage extends StatefulWidget {
  const PlayerWorkspacePage({super.key});

  @override
  State<PlayerWorkspacePage> createState() => _PlayerWorkspacePageState();
}

class _PlayerWorkspacePageState extends State<PlayerWorkspacePage> {
  VisualizerStyle _visualizerStyle = VisualizerStyle.bars;
  bool _playlistExpanded = true;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 920 && constraints.maxHeight >= 520) {
          return _buildWideLayout(context, constraints);
        }
        return _buildNarrowLayout(context);
      },
    );
  }

  Widget _buildWideLayout(BuildContext context, BoxConstraints constraints) {
    final queueWidth = math.min(
      300.0,
      math.max(268.0, constraints.maxWidth * 0.25),
    );
    final lyricsHeight = (constraints.maxHeight * 0.33).clamp(204.0, 280.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildSpectrumPanel(context)),
                const SizedBox(height: 10),
                SizedBox(
                  height: lyricsHeight,
                  child: _buildLyricsPanel(context),
                ),
              ],
            ),
          ),
          if (_playlistExpanded) ...[
            const SizedBox(width: 12),
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

  Widget _buildNarrowLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 360, child: _buildSpectrumPanel(context)),
          const SizedBox(height: 12),
          SizedBox(height: 270, child: _buildLyricsPanel(context)),
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

  Widget _buildSpectrumPanel(BuildContext context) {
    return AppPanel(
      elevated: true,
      padding: EdgeInsets.zero,
      child: _MediaPanel(
        isVisualizer: true,
        visualizerStyle: _visualizerStyle,
        playlistExpanded: _playlistExpanded,
        onVisualizerStyleChanged: (style) {
          setState(() => _visualizerStyle = style);
        },
        onTogglePlaylist: () {
          setState(() => _playlistExpanded = !_playlistExpanded);
        },
        onOpenFullscreen: _openFullscreenVisualizer,
      ),
    );
  }

  Widget _buildLyricsPanel(BuildContext context) {
    return const AppPanel(
      elevated: true,
      padding: EdgeInsets.zero,
      child: _MediaPanel(isVisualizer: false),
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

class _MediaPanel extends StatelessWidget {
  const _MediaPanel({
    required this.isVisualizer,
    this.visualizerStyle = VisualizerStyle.bars,
    this.playlistExpanded = false,
    this.onVisualizerStyleChanged,
    this.onTogglePlaylist,
    this.onOpenFullscreen,
  });

  final bool isVisualizer;
  final VisualizerStyle visualizerStyle;
  final bool playlistExpanded;
  final ValueChanged<VisualizerStyle>? onVisualizerStyleChanged;
  final VoidCallback? onTogglePlaylist;
  final VoidCallback? onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ContentPanelHeader(
          isVisualizer: isVisualizer,
          style: visualizerStyle,
          playlistExpanded: playlistExpanded,
          onVisualizerStyleChanged: onVisualizerStyleChanged,
          onTogglePlaylist: onTogglePlaylist,
          onOpenFullscreen: onOpenFullscreen,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: isVisualizer
                ? VisualizerView(
                    showStyleSelector: false,
                    fixedStyle: visualizerStyle,
                    maxFps: 30,
                  )
                : const LyricView(),
          ),
        ),
      ],
    );
  }
}

class _ContentPanelHeader extends StatelessWidget {
  const _ContentPanelHeader({
    required this.isVisualizer,
    required this.style,
    required this.playlistExpanded,
    required this.onVisualizerStyleChanged,
    required this.onTogglePlaylist,
    required this.onOpenFullscreen,
  });

  final bool isVisualizer;
  final VisualizerStyle style;
  final bool playlistExpanded;
  final ValueChanged<VisualizerStyle>? onVisualizerStyleChanged;
  final VoidCallback? onTogglePlaylist;
  final VoidCallback? onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visual = Theme.of(context).extension<AppVisualTheme>()!;
    return Container(
      height: 42,
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
      decoration: BoxDecoration(
        color: visual.panelMuted.withValues(alpha: 0.28),
        border: Border(bottom: BorderSide(color: visual.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              isVisualizer ? Icons.graphic_eq_rounded : Icons.lyrics_outlined,
              size: 16,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            isVisualizer ? '实时频谱' : '同步歌词',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (isVisualizer && onVisualizerStyleChanged != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.75),
                ),
              ),
              child: Text(
                style.displayName,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            _VisualizerStyleButton(
              style: style,
              onChanged: onVisualizerStyleChanged!,
              compact: true,
            ),
            IconButton(
              onPressed: onOpenFullscreen,
              tooltip: '全屏频谱',
              icon: const Icon(Icons.fullscreen_rounded, size: 18),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: scheme.surface.withValues(alpha: 0.5),
              ),
            ),
            IconButton(
              onPressed: onTogglePlaylist,
              tooltip: playlistExpanded ? '收起播放队列' : '展开播放队列',
              icon: Icon(
                playlistExpanded
                    ? Icons.view_sidebar_rounded
                    : Icons.view_sidebar_outlined,
                size: 18,
              ),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: scheme.surface.withValues(alpha: 0.5),
              ),
            ),
          ] else
            const Spacer(),
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
                    item == style ? Icons.check_rounded : item.icon,
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
