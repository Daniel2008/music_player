import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../theme/app_design.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/lyric_view.dart';
import '../widgets/playlist_panel.dart';
import '../widgets/visualizer_view.dart';
import '../widgets/surface_texture.dart';
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
        if (constraints.maxWidth >= AppBreakpoints.workspaceWide &&
            constraints.maxHeight >= 440) {
          return _buildWideLayout(context, constraints);
        }
        return _buildNarrowLayout(context, constraints);
      },
    );
  }

  Widget _buildWideLayout(BuildContext context, BoxConstraints constraints) {
    final queueWidth = math.min(
      300.0,
      math.max(268.0, constraints.maxWidth * 0.25),
    );
    final lyricsHeight = (constraints.maxHeight * 0.35).clamp(180.0, 260.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildSpectrumPanel(context)),
                const SizedBox(height: AppSpacing.sm + 2),
                SizedBox(
                  height: lyricsHeight,
                  child: _buildLyricsPanel(context),
                ),
              ],
            ),
          ),
          if (_playlistExpanded) ...[
            const SizedBox(width: AppSpacing.gutter),
            SizedBox(
              width: queueWidth,
              child: const AppPanel(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm + 2,
                ),
                child: PlaylistPanel(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final spectrumHeight = (constraints.maxHeight * 0.55).clamp(220.0, 360.0);
    final lyricsHeight = (width * 0.34).clamp(200.0, 260.0);
    final queueHeight = (width * 0.60).clamp(280.0, 420.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: spectrumHeight, child: _buildSpectrumPanel(context)),
          const SizedBox(height: AppSpacing.gutter),
          SizedBox(height: lyricsHeight, child: _buildLyricsPanel(context)),
          if (_playlistExpanded) ...[
            const SizedBox(height: AppSpacing.gutter),
            SizedBox(
              height: queueHeight,
              child: const AppPanel(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm + 2,
                ),
                child: PlaylistPanel(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpectrumPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final accent = HSLColor.fromColor(scheme.primary);
    final companion = accent.withHue((accent.hue + 65) % 360).toColor();
    return AppPanel(
      elevated: true,
      texture: SurfaceTextureKind.grain,
      color: scheme.surfaceContainerLowest,
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: dark ? 0.18 : 0.11),
              scheme.primary.withValues(alpha: 0.02),
              companion.withValues(alpha: dark ? 0.13 : 0.08),
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
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
      ),
    );
  }

  Widget _buildLyricsPanel(BuildContext context) {
    return const AppPanel(
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
          child: VisualizerFullscreenPage(
            initialStyle: _visualizerStyle,
            onStyleChanged: (style) {
              if (mounted) setState(() => _visualizerStyle = style);
            },
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: AppMotion.normal,
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm + 2,
            ),
            child: isVisualizer
                ? VisualizerView(
                    showStyleSelector: false,
                    showStyleLabel: false,
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
    final scheme = context.scheme;
    final visual = context.visual;
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: AppSpacing.titleBarHeight,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.sm, 0),
        decoration: BoxDecoration(
          color: visual.panelMuted.withValues(alpha: 0.16),
          border: Border(bottom: BorderSide(color: visual.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.2),
                    scheme.primaryContainer.withValues(alpha: 0.65),
                  ],
                ),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(
                isVisualizer ? Icons.graphic_eq_rounded : Icons.lyrics_outlined,
                size: 17,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                isVisualizer ? '实时频谱' : '同步歌词',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.titleSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isVisualizer && onVisualizerStyleChanged != null) ...[
              const SizedBox(width: AppSpacing.sm),
              _VisualizerStyleButton(
                style: style,
                onChanged: onVisualizerStyleChanged!,
                compact:
                    constraints.maxWidth < AppBreakpoints.panelHeaderCompact,
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                onPressed: onOpenFullscreen,
                tooltip: '全屏频谱',
                icon: const Icon(Icons.fullscreen_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
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
                  backgroundColor: playlistExpanded
                      ? visual.accentSurface
                      : Colors.transparent,
                  foregroundColor: playlistExpanded ? scheme.primary : null,
                ),
              ),
            ],
          ],
        ),
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
      child: Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: context.visual.accentSurface,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 17, color: scheme.primary),
            if (!compact) ...[
              const SizedBox(width: AppSpacing.sm - 2),
              Text(
                style.displayName,
                style: context.textStyles.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: scheme.primary,
            ),
          ],
        ),
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
