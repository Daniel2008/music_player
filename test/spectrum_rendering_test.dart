import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player/ui/widgets/visualizer/particle.dart';
import 'package:music_player/ui/widgets/visualizer/spectrum_painter.dart';
import 'package:music_player/ui/widgets/visualizer/visualizer_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('瀑布谱复用绘制器后仍响应尺寸和历史数据变化', () async {
    final history = List.generate(16, (_) => List<double>.filled(32, 0.8));
    final signal = ValueNotifier(0);
    final painter = SpectrumPainter(
      repaint: signal,
      levels: const [],
      peaks: const [],
      barCount: 32,
      style: VisualizerStyle.waterfall,
      color: Colors.teal,
      secondaryColor: Colors.blue,
      tertiaryColor: Colors.amber,
      surfaceColor: Colors.black,
      faintColor: Colors.white,
      particles: const [],
      history: history,
      historyHead: 0,
      historyCount: 16,
      beatIntensity: 0,
      enableGlow: false,
      showGuides: false,
    );
    Future<ui.Image> draw(int width, int height) async {
      final recorder = ui.PictureRecorder();
      painter.paint(
        Canvas(recorder),
        Size(width.toDouble(), height.toDouble()),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      picture.dispose();
      return image;
    }

    (await draw(640, 240)).dispose();
    final resized = await draw(1280, 480);
    final pixels = (await resized.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    expect(pixels.getUint8((470 * 1280 + 1215) * 4 + 3), greaterThan(40));
    resized.dispose();
    for (final row in history) {
      row.fillRange(0, row.length, 0);
    }
    final silent = await draw(1280, 480);
    final cleared = (await silent.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    expect(cleared.getUint8((470 * 1280 + 1215) * 4 + 3), 0);
    silent.dispose();
    signal.dispose();
  });

  test('strong beat keeps the interior of spectrum bars filled', () async {
    final image = await _render(VisualizerStyle.bars, level: 1, beat: 0.8);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    // 远离扫光与轮廓，检查第一根柱子内部，防止共享画笔泄漏描边模式。
    expect(data.getUint8((180 * 640 + 6) * 4 + 3), greaterThan(150));
    image.dispose();
  });

  test('silent bars do not leave a wall of inactive segments', () async {
    final image = await _render(VisualizerStyle.bars, level: 0, beat: 0);
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    var visiblePixels = 0;
    for (var y = 0; y < 230; y++) {
      for (var x = 0; x < 640; x++) {
        if (bytes[(y * 640 + x) * 4 + 3] > 20) visiblePixels++;
      }
    }
    expect(visiblePixels, 0);
    image.dispose();
  });

  test('dot spectrum uses the height of a tall stage', () async {
    final image = await _render(
      VisualizerStyle.dots,
      level: 1,
      beat: 0,
      height: 500,
    );
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    var firstVisibleRow = 500;
    for (var y = 0; y < 500; y++) {
      if (bytes[(y * 640 + 6) * 4 + 3] > 120) {
        firstVisibleRow = y;
        break;
      }
    }
    expect(firstVisibleRow, lessThan(100));
    image.dispose();
  });

  test('all eight styles render in light and dark themes', () async {
    final captureDir = Platform.environment['UI_CAPTURE_DIR'];
    if (captureDir != null) {
      final fontFile = File(r'C:\Windows\Fonts\msyh.ttc');
      if (await fontFile.exists()) {
        await (FontLoader('PreviewFont')..addFont(
              fontFile.readAsBytes().then(
                (bytes) => ByteData.sublistView(bytes),
              ),
            ))
            .load();
      }
      await Directory(captureDir).create(recursive: true);
    }
    for (final dark in [false, true]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final background = dark
          ? const Color(0xFF101623)
          : const Color(0xFFF7F8FC);
      canvas.drawColor(background, BlendMode.src);
      for (final style in VisualizerStyle.values) {
        final image = await _render(style, dark: dark);
        expect(image.width, 640);
        final x = (style.index % 2) * 680.0 + 20;
        final y = (style.index ~/ 2) * 300.0 + 48;
        canvas.drawImage(image, Offset(x, y), Paint());
        final paragraph =
            (ui.ParagraphBuilder(
                    ui.ParagraphStyle(fontFamily: 'PreviewFont', fontSize: 16),
                  )
                  ..pushStyle(
                    ui.TextStyle(color: dark ? Colors.white : Colors.black87),
                  )
                  ..addText('${style.index + 1}  ${style.displayName}'))
                .build()
              ..layout(const ui.ParagraphConstraints(width: 640));
        canvas.drawParagraph(paragraph, Offset(x, y - 30));
        paragraph.dispose();
        image.dispose();
      }
      final picture = recorder.endRecording();
      if (captureDir != null) {
        final gallery = await picture.toImage(1360, 1200);
        final bytes = (await gallery.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        await File(
          '$captureDir/spectrum-${dark ? 'dark' : 'light'}.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
        gallery.dispose();
      }
      picture.dispose();
    }
  });
}

Future<ui.Image> _render(
  VisualizerStyle style, {
  double? level,
  double beat = 0.65,
  int height = 240,
  bool dark = true,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final repaint = ValueNotifier(0);
  final levels = List<double>.generate(
    48,
    (i) =>
        level ??
        (0.08 + 0.7 * math.pow(math.sin(i * 0.13 + 0.4), 2) * (1 - i / 72)),
  );
  SpectrumPainter(
    repaint: repaint,
    levels: levels,
    peaks: level == 0
        ? List.filled(48, 0)
        : levels.map((v) => math.min(1.0, v + 0.05)).toList(),
    barCount: 48,
    style: style,
    color: dark ? const Color(0xFFBDC2FF) : const Color(0xFF5964A6),
    secondaryColor: const Color(0xFF759BE9),
    tertiaryColor: const Color(0xFFC778D9),
    surfaceColor: dark ? const Color(0xFF101623) : const Color(0xFFF7F8FC),
    faintColor: const Color(0x335964A6),
    waveform: List.generate(
      256,
      (i) => math.sin(i * 0.12) * 0.4 + math.sin(i * 0.31) * 0.16,
    ),
    particles: List.generate(
      18,
      (i) => Particle(
        x: (i * 0.137) % 1,
        y: 0.1 + (i * 0.091) % 0.75,
        vx: 0,
        vy: 0,
        size: 2 + i % 4,
        life: 0.8,
        hue: i / 18,
      ),
    ),
    history: List.generate(
      48,
      (row) => List.generate(
        48,
        (i) => (0.08 + 0.72 * math.pow(math.sin(i * 0.13 + row * 0.08), 2))
            .toDouble(),
      ),
    ),
    historyHead: 0,
    historyCount: 48,
    beatIntensity: beat,
    bassEnergy: level == 0 ? 0 : 0.55,
    midEnergy: level == 0 ? 0 : 0.4,
    highEnergy: level == 0 ? 0 : 0.3,
    phase: 1.1,
    enableGlow: true,
    showGuides: false,
  ).paint(canvas, Size(640, height.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(640, height);
  picture.dispose();
  repaint.dispose();
  return image;
}
