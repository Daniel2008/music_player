import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/controls.dart';
import '../widgets/playlist_view.dart';
import '../widgets/visualizer_view.dart';
import '../widgets/lyric_view.dart';
import '../widgets/theme_skin_bar.dart';
import '../widgets/hotkey_binder.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => PlayerProvider())],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('桌面音乐播放器'),
          actions: const [ThemeSkinBar()],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1100;
            final theme = context.watch<ThemeProvider>();
            final dividerColor =
                (theme.mode == ThemeMode.dark ? Colors.white : Colors.black87)
                    .withOpacity(0.08);

            Widget section({required Widget child, double elevation = 1}) {
              return Card(
                elevation: elevation,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(padding: const EdgeInsets.all(14), child: child),
              );
            }

            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                section(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('频谱'),
                      SizedBox(height: 6),
                      VisualizerView(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                section(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('歌词'),
                      SizedBox(height: 8),
                      LyricView(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                section(child: const Controls()),
              ],
            );

            final right = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: section(child: const PlaylistView())),
                const SizedBox(height: 12),
              ],
            );

            return Stack(
              children: [
                const HotkeyBinder(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: SingleChildScrollView(child: left),
                            ),
                            Container(width: 1, color: dividerColor),
                            const SizedBox(width: 12),
                            Expanded(flex: 1, child: right),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              left,
                              const SizedBox(height: 12),
                              Container(height: 1, color: dividerColor),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: math.max(
                                  420,
                                  constraints.maxHeight * 0.75,
                                ),
                                child: right,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
