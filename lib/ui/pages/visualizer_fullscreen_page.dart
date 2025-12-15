import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/visualizer_view.dart';
import '../widgets/lyric_view.dart';

class VisualizerFullscreenPage extends StatelessWidget {
  const VisualizerFullscreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      body: RawKeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKey: (ev) {
          if (ev.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).maybePop();
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    flex: 7,
                    child: Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: VisualizerView(),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 260,
                    child: Material(
                      color: scheme.surface,
                      child: const LyricView(),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 28),
                  color: scheme.onSurface,
                  tooltip: '退出全屏',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
