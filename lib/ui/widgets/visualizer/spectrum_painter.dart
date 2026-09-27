import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'particle.dart';
import 'visualizer_style.dart';

/// 低分配频谱绘制器。
///
/// 所有样式复用 Paint/Path；不在单柱、单粒子循环中创建 Shader 或 Blur，
/// 以控制 Windows 桌面端的 Dart 堆和 GPU 资源增长。
class SpectrumPainter extends CustomPainter {
  SpectrumPainter({
    required this.repaint,
    required this.levels,
    required this.peaks,
    required this.barCount,
    required this.style,
    required this.color,
    required this.secondaryColor,
    required this.tertiaryColor,
    required this.surfaceColor,
    required this.faintColor,
    required this.particles,
    required this.history,
    required this.historyHead,
    this.historyCount = 0,
    required this.beatIntensity,
    required this.enableGlow,
    required this.showGuides,
    this.phase = 0,
  }) : super(repaint: repaint);

  final Listenable repaint;
  final List<double> levels;
  final List<double> peaks;
  final int barCount;
  final VisualizerStyle style;
  final Color color;
  final Color secondaryColor;
  final Color tertiaryColor;
  final Color surfaceColor;
  final Color faintColor;
  final List<Particle> particles;
  final List<List<double>> history;
  final int historyHead;
  final int historyCount;
  final double beatIntensity;
  final bool enableGlow;
  final bool showGuides;
  final double phase;

  final Paint _paint = Paint()..isAntiAlias = true;
  final Path _path = Path();
  final Path _secondaryPath = Path();
  List<Color> _palette = const [];
  List<Color> _paletteStops = const [];
  List<Color> _heatPalette = const [];
  int _paletteCount = 0;
  Color? _palettePrimary;
  Color? _paletteSecondary;
  Color? _paletteTertiary;
  Color? _paletteSurface;

  void _resetPaint() {
    _paint
      ..style = PaintingStyle.fill
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..shader = null
      ..maskFilter = null;
    _path.reset();
    _secondaryPath.reset();
  }

  void _ensurePalette(int count) {
    if (_paletteCount == count &&
        _palettePrimary == color &&
        _paletteSecondary == secondaryColor &&
        _paletteTertiary == tertiaryColor &&
        _paletteSurface == surfaceColor) {
      return;
    }
    _paletteCount = count;
    _palettePrimary = color;
    _paletteSecondary = secondaryColor;
    _paletteTertiary = tertiaryColor;
    _paletteSurface = surfaceColor;

    // 主题色可能集中在相近色相，频谱会显得单薄。这里保留主色相，
    // 用两个大跨度色相生成高饱和调色板，让低中高频颜色明显分离。
    final isDark =
        ThemeData.estimateBrightnessForColor(surfaceColor) == Brightness.dark;
    final baseHue = HSLColor.fromColor(color).hue;
    final hues = [baseHue, (baseHue + 78) % 360, (baseHue + 162) % 360];
    final lightness = isDark ? 0.66 : 0.42;
    _paletteStops = List<Color>.generate(
      3,
      (index) => HSLColor.fromAHSL(
        1,
        hues[index],
        0.86,
        index == 2 && isDark ? 0.68 : lightness,
      ).toColor(),
      growable: false,
    );
    _palette = List<Color>.generate(count, (index) {
      final progress = count <= 1 ? 0.0 : index / (count - 1);
      if (progress < 0.5) {
        return Color.lerp(_paletteStops[0], _paletteStops[1], progress / 0.5)!;
      }
      return Color.lerp(
        _paletteStops[1],
        _paletteStops[2],
        (progress - 0.5) / 0.5,
      )!;
    }, growable: false);

    final heatLow = Color.lerp(surfaceColor, Colors.black, 0.22)!;
    final heatMid = Color.lerp(_paletteStops[0], _paletteStops[1], 0.42)!;
    _heatPalette = List<Color>.generate(24, (index) {
      final progress = index / 23;
      if (progress < 0.34) {
        return Color.lerp(heatLow, _paletteStops[0], progress / 0.34)!;
      }
      if (progress < 0.72) {
        return Color.lerp(_paletteStops[0], heatMid, (progress - 0.34) / 0.38)!;
      }
      return Color.lerp(heatMid, Colors.white, (progress - 0.72) / 0.28)!;
    }, growable: false);
  }

  double _level(int index, [double exponent = 0.50]) =>
      math.pow(levels[index].clamp(0.0, 1.0), exponent).toDouble();

  ({double width, double left, double step}) _frequencyLayout(
    Size size, {
    double gap = 2.5,
    double minWidth = 2,
    double maxWidth = 28,
  }) {
    final availableWidth = math.max(
      1.0,
      size.width - gap * math.max(0, barCount - 1),
    );
    final width = (availableWidth / math.max(1, barCount)).clamp(
      minWidth,
      maxWidth,
    );
    final contentWidth = width * barCount + gap * math.max(0, barCount - 1);
    return (
      width: width,
      left: math.max(0.0, (size.width - contentWidth) / 2),
      step: width + gap,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (barCount <= 0 || size.isEmpty) return;
    _resetPaint();
    _ensurePalette(barCount);
    if (showGuides) _paintGuides(canvas, size);

    switch (style) {
      case VisualizerStyle.bars:
        _paintBars(canvas, size, mirrored: false);
      case VisualizerStyle.mirroredBars:
        _paintBars(canvas, size, mirrored: true);
      case VisualizerStyle.dots:
        _paintDots(canvas, size);
      case VisualizerStyle.wave:
        _paintWave(canvas, size);
      case VisualizerStyle.particles:
        _paintParticles(canvas, size);
      case VisualizerStyle.flame:
        _paintFlame(canvas, size);
      case VisualizerStyle.waterfall:
        _paintWaterfall(canvas, size);
      case VisualizerStyle.vinyl:
        _paintVinyl(canvas, size);
    }
  }

  void _paintGuides(Canvas canvas, Size size) {
    final isCentered =
        style == VisualizerStyle.mirroredBars || style == VisualizerStyle.wave;
    final baseline = isCentered ? size.height / 2 : size.height - 1;

    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = faintColor.withValues(alpha: 0.42);

    for (final fraction in const [0.25, 0.5, 0.75]) {
      final y = isCentered
          ? size.height / 2 + (fraction - 0.5) * size.height * 0.72
          : size.height - fraction * size.height * 0.82;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _paint);
    }

    _paint
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.22);
    canvas.drawLine(Offset(0, baseline), Offset(size.width, baseline), _paint);
  }

  void _paintBars(Canvas canvas, Size size, {required bool mirrored}) {
    const gap = 2.5;
    final layout = _frequencyLayout(size, gap: gap);
    final width = layout.width;
    final radius = Radius.circular(math.min(width / 2, 3.2));
    final centerY = size.height / 2;
    final maxHeight = size.height * (mirrored ? 0.30 : 0.68);
    final segmentCount = (maxHeight / 13.5).round().clamp(6, 14).toInt();
    final segmentStep = maxHeight / segmentCount;
    final segmentHeight = math.max(1.7, segmentStep - 1.25);
    final baseline = size.height - 1;

    for (var i = 0; i < barCount; i++) {
      final value = _level(i);
      final peakValue = peaks[i].clamp(0.0, 1.0);
      final peak = math.pow(peakValue, 0.5).toDouble() * maxHeight;
      final x = layout.left + i * layout.step;
      final activeSegments = (value * segmentCount).ceil().clamp(
        0,
        segmentCount,
      );

      for (var segment = 0; segment < segmentCount; segment++) {
        final active = segment < activeSegments;
        final segmentProgress = (segment + 1) / segmentCount;
        final alpha = active
            ? (0.72 + value * 0.24).clamp(0.72, 0.96).toDouble()
            : 0.08 + segmentProgress * 0.035;
        _paint.color = active
            ? Color.lerp(
                _palette[i],
                Colors.white,
                segmentProgress * 0.12 * value,
              )!.withValues(alpha: alpha)
            : _palette[i].withValues(alpha: alpha);

        if (mirrored) {
          final upperY = centerY - (segment + 1) * segmentStep + 1.25;
          final lowerY = centerY + segment * segmentStep;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, upperY, width, segmentHeight),
              radius,
            ),
            _paint,
          );
          if (active) {
            _paint.color = _paint.color.withValues(alpha: alpha * 0.52);
          }
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, lowerY, width, segmentHeight),
              radius,
            ),
            _paint,
          );
        } else {
          final segmentY = baseline - (segment + 1) * segmentStep + 1.25;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, segmentY, width, segmentHeight),
              radius,
            ),
            _paint,
          );
        }
      }

      if (!mirrored && peak > 4) {
        _paint.color = Colors.white.withValues(
          alpha: (0.22 + peakValue * 0.58).clamp(0.0, 0.82).toDouble(),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, baseline - peak - 2.5, width, 2.1),
            Radius.circular(math.min(width / 2, 1.8)),
          ),
          _paint,
        );
      }

      if (enableGlow && value > 0.22) {
        _paint.color = _palette[i].withValues(
          alpha: (0.12 + (value - 0.22) * 0.32).clamp(0.0, 0.32).toDouble(),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x - width * 0.22,
              (mirrored
                      ? centerY - value * maxHeight
                      : baseline - value * maxHeight) -
                  1,
              width * 1.44,
              2.2,
            ),
            Radius.circular(width),
          ),
          _paint,
        );
      }
    }
  }

  void _paintDots(Canvas canvas, Size size) {
    const gap = 3.0;
    final layout = _frequencyLayout(size, gap: gap, minWidth: 3, maxWidth: 24);
    final columnWidth = layout.width;
    final radius = (columnWidth * 0.28).clamp(1.1, 2.8);
    final step = radius * 2.8;
    final rows = (size.height / step).floor().clamp(4, 18);
    final verticalOffset = (size.height - rows * step) / 2;

    for (var i = 0; i < barCount; i++) {
      final value = _level(i, 0.58);
      final active = (value * rows).round();
      final x = layout.left + i * layout.step + columnWidth / 2;
      for (var row = 0; row < active; row++) {
        _paint.color = Color.lerp(
          faintColor,
          _palette[i],
          0.35 + row / rows * 0.65,
        )!;
        canvas.drawCircle(
          Offset(x, size.height - verticalOffset - (row + 0.5) * step),
          radius,
          _paint,
        );
      }
    }
  }

  void _paintWave(Canvas canvas, Size size) {
    if (barCount < 2) return;
    final dx = size.width / (barCount - 1);
    final middle = size.height / 2;
    final amplitude = size.height * 0.38;
    _path.moveTo(0, middle - _level(0, 0.66) * amplitude);
    _secondaryPath.moveTo(0, middle + _level(0, 0.66) * amplitude);
    for (var i = 1; i < barCount; i++) {
      final x = i * dx;
      final value = _level(i, 0.66) * amplitude;
      _path.lineTo(x, middle - value);
      _secondaryPath.lineTo(x, middle + value);
    }

    _paint.shader = LinearGradient(
      colors: _paletteStops,
    ).createShader(Offset.zero & size);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;
    if (enableGlow) {
      _paint
        ..strokeWidth = 7
        ..color = _paletteStops[2].withValues(alpha: 0.22);
      canvas.drawPath(_path, _paint);
      _paint
        ..strokeWidth = 2.8
        ..shader = LinearGradient(
          colors: _paletteStops,
        ).createShader(Offset.zero & size);
    }
    canvas.drawPath(_path, _paint);
    _paint
      ..shader = null
      ..strokeWidth = 1.8
      ..color = _paletteStops[1].withValues(alpha: 0.82);
    canvas.drawPath(_secondaryPath, _paint);
    _paint
      ..strokeWidth = 0.6
      ..color = faintColor.withValues(alpha: 0.58);
    canvas.drawLine(Offset(0, middle), Offset(size.width, middle), _paint);
  }

  void _paintParticles(Canvas canvas, Size size) {
    const gap = 3.0;
    final layout = _frequencyLayout(size, gap: gap, maxWidth: 28);
    final width = layout.width;
    for (var i = 0; i < barCount; i++) {
      final value = _level(i);
      if (value < 0.04) continue;
      final height = value * size.height * 0.42;
      _paint.color = _palette[i].withValues(alpha: 0.14 + value * 0.36);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            layout.left + i * layout.step,
            size.height - height,
            width,
            height,
          ),
          Radius.circular(width / 2),
        ),
        _paint,
      );
    }

    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (var i = 0; i < particles.length; i++) {
      final a = particles[i];
      final ax = a.x * size.width;
      final ay = a.y * size.height;
      for (var j = i + 1; j < particles.length && j < i + 4; j++) {
        final b = particles[j];
        final bx = b.x * size.width;
        final by = b.y * size.height;
        final dx = ax - bx;
        final dy = ay - by;
        final distanceSquared = dx * dx + dy * dy;
        if (distanceSquared < 1800) {
          _paint.color = color.withValues(
            alpha: (1 - distanceSquared / 1800) * 0.12 * a.life.clamp(0, 1),
          );
          canvas.drawLine(Offset(ax, ay), Offset(bx, by), _paint);
        }
      }
    }

    _paint.style = PaintingStyle.fill;
    for (final particle in particles) {
      if (particle.life <= 0) continue;
      final x = particle.x * size.width;
      final y = particle.y * size.height;
      if (x < -8 || x > size.width + 8 || y < -8 || y > size.height + 8) {
        continue;
      }
      final paletteIndex = ((particle.hue % 1.0) * (barCount - 1))
          .round()
          .clamp(0, barCount - 1);
      final alpha = particle.life.clamp(0.0, 1.0);
      _paint.color = _palette[paletteIndex].withValues(alpha: alpha * 0.85);
      canvas.drawCircle(Offset(x, y), particle.size, _paint);
      if (particle.size > 1.5) {
        _paint.color = Colors.white.withValues(alpha: alpha * 0.45);
        canvas.drawCircle(
          Offset(x - particle.size * 0.22, y - particle.size * 0.22),
          particle.size * 0.28,
          _paint,
        );
      }
    }
  }

  void _paintFlame(Canvas canvas, Size size) {
    const gap = 2.5;
    final layout = _frequencyLayout(size, gap: gap, minWidth: 3);
    final width = layout.width;
    final shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xFFFF3D00), Color(0xFFFFA000), Color(0xFFFFF59D)],
      stops: [0, 0.58, 1],
    ).createShader(Offset.zero & size);
    _paint.shader = shader;
    for (var i = 0; i < barCount; i++) {
      final value = _level(i, 0.72);
      if (value < 0.025) continue;
      final height = value * size.height * 0.68;
      final x = layout.left + i * layout.step;
      _path
        ..reset()
        ..moveTo(x, size.height)
        ..quadraticBezierTo(
          x + width * 0.15,
          size.height - height * 0.45,
          x + width * 0.5,
          size.height - height,
        )
        ..quadraticBezierTo(
          x + width * 0.86,
          size.height - height * 0.42,
          x + width,
          size.height,
        )
        ..close();
      canvas.drawPath(_path, _paint);
    }
    _paint.shader = null;
  }

  void _paintWaterfall(Canvas canvas, Size size) {
    if (history.isEmpty || barCount <= 0) return;
    final requestedRows = historyCount == 0 ? history.length : historyCount;
    final visibleRows = requestedRows.clamp(1, history.length).toInt();
    final cellWidth = size.width / barCount;
    final rowHeight = size.height / visibleRows;

    for (var age = 0; age < visibleRows; age++) {
      final historyIndex =
          (historyHead - 1 - age + history.length * 2) % history.length;
      final data = history[historyIndex];
      final y = size.height - (age + 1) * rowHeight;
      for (var i = 0; i < barCount; i++) {
        final value = math.pow(data[i].clamp(0.0, 1.0), 1.05).toDouble();
        final heatIndex = (value * (_heatPalette.length - 1))
            .round()
            .clamp(0, _heatPalette.length - 1)
            .toInt();
        _paint.color = _heatPalette[heatIndex].withValues(
          alpha: (0.08 + math.pow(value, 1.15) * 0.78)
              .clamp(0.0, 0.88)
              .toDouble(),
        );
        canvas.drawRect(
          Rect.fromLTWH(
            i * cellWidth - 0.4,
            y - 0.4,
            cellWidth + 0.8,
            rowHeight + 0.8,
          ),
          _paint,
        );
      }
    }

    _paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, _paletteStops[0].withValues(alpha: 0.65)],
    ).createShader(Rect.fromLTWH(0, size.height - 6, size.width, 6));
    canvas.drawRect(Rect.fromLTWH(0, size.height - 3, size.width, 3), _paint);
    _paint.shader = null;
  }

  void _paintVinyl(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final minSide = math.min(size.width, size.height);
    final discRadius = minSide * 0.40;
    final spectrumRadius = discRadius * 0.82;
    final extension = minSide * 0.18;

    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = faintColor.withValues(alpha: 0.28);
    canvas.drawCircle(center, discRadius, _paint);

    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = faintColor.withValues(alpha: 0.30);
    for (var groove = 1; groove <= 5; groove++) {
      canvas.drawCircle(center, discRadius * groove / 6.2, _paint);
    }

    for (var i = 0; i < barCount; i++) {
      final angle = i / barCount * math.pi * 2 - math.pi / 2;
      final value = _level(i, 0.62);
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final inner = Offset(
        center.dx + cosA * spectrumRadius,
        center.dy + sinA * spectrumRadius,
      );
      final outerRadius = spectrumRadius + value * extension;
      final outer = Offset(
        center.dx + cosA * outerRadius,
        center.dy + sinA * outerRadius,
      );
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + value * 2.8
        ..color = _palette[i].withValues(alpha: 0.62 + value * 0.38);
      canvas.drawLine(inner, outer, _paint);
      if (enableGlow && value > 0.34) {
        _paint
          ..strokeWidth = 4.8
          ..color = _palette[i].withValues(alpha: 0.13 + value * 0.12);
        canvas.drawLine(inner, outer, _paint);
      }
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase * 0.23);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = _paletteStops[1].withValues(alpha: 0.42);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: discRadius * 0.72),
      -math.pi * 0.36,
      math.pi * 0.52,
      false,
      _paint,
    );
    canvas.restore();

    _paint
      ..style = PaintingStyle.fill
      ..color = _paletteStops[0].withValues(alpha: 0.12 + beatIntensity * 0.10);
    canvas.drawCircle(center, discRadius * 0.08, _paint);

    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + beatIntensity * 1.8
      ..color = _paletteStops[0].withValues(alpha: 0.42 + beatIntensity * 0.42);
    canvas.drawCircle(
      center,
      discRadius * (0.30 + beatIntensity * 0.025),
      _paint,
    );
    canvas.drawCircle(center, math.max(2.2, minSide * 0.012), _paint);
  }

  @override
  bool shouldRepaint(covariant SpectrumPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.color != color ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.tertiaryColor != tertiaryColor ||
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.enableGlow != enableGlow ||
      oldDelegate.showGuides != showGuides ||
      oldDelegate.barCount != barCount ||
      oldDelegate.historyCount != historyCount ||
      oldDelegate.phase != phase;
}
