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
    required this.faintColor,
    required this.particles,
    required this.history,
    required this.historyHead,
    required this.beatIntensity,
    required this.enableGlow,
  }) : super(repaint: repaint);

  final Listenable repaint;
  final List<double> levels;
  final List<double> peaks;
  final int barCount;
  final VisualizerStyle style;
  final Color color;
  final Color secondaryColor;
  final Color tertiaryColor;
  final Color faintColor;
  final List<Particle> particles;
  final List<List<double>> history;
  final int historyHead;
  final double beatIntensity;
  final bool enableGlow;

  final Paint _paint = Paint()..isAntiAlias = true;
  final Path _path = Path();
  final Path _secondaryPath = Path();
  List<Color> _palette = const [];
  int _paletteCount = 0;
  Color? _paletteColor;

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
    if (_paletteCount == count && _paletteColor == color) return;
    _paletteCount = count;
    _paletteColor = color;
    final base = HSLColor.fromColor(color);
    _palette = List<Color>.generate(count, (index) {
      final shift = count <= 1 ? 0.0 : index / (count - 1) * 52 - 26;
      return base
          .withHue((base.hue + shift) % 360)
          .withSaturation((base.saturation + 0.08).clamp(0.0, 1.0))
          .toColor();
    }, growable: false);
  }

  double _level(int index, [double exponent = 0.72]) =>
      math.pow(levels[index].clamp(0.0, 1.0), exponent).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    if (barCount <= 0 || size.isEmpty) return;
    _resetPaint();
    _ensurePalette(barCount);

    switch (style) {
      case VisualizerStyle.bars:
        _paintBars(canvas, size, mirrored: false);
      case VisualizerStyle.mirroredBars:
        _paintBars(canvas, size, mirrored: true);
      case VisualizerStyle.line:
        _paintLine(canvas, size);
      case VisualizerStyle.dots:
        _paintDots(canvas, size);
      case VisualizerStyle.circular:
        _paintCircular(canvas, size);
      case VisualizerStyle.wave:
        _paintWave(canvas, size);
      case VisualizerStyle.particles:
        _paintParticles(canvas, size);
      case VisualizerStyle.flame:
        _paintFlame(canvas, size);
      case VisualizerStyle.radar:
        _paintRadar(canvas, size);
      case VisualizerStyle.ring:
        _paintRing(canvas, size);
      case VisualizerStyle.gradient:
        _paintGradientBars(canvas, size);
      case VisualizerStyle.spectrum3D:
        _paintSpectrum3D(canvas, size);
    }
  }

  void _paintBars(Canvas canvas, Size size, {required bool mirrored}) {
    const gap = 2.5;
    final width = ((size.width - gap * (barCount - 1)) / barCount).clamp(
      2.0,
      18.0,
    );
    final radius = Radius.circular(math.min(width / 2, 5));
    final centerY = size.height / 2;
    final maxHeight = size.height * (mirrored ? 0.42 : 0.86);

    for (var i = 0; i < barCount; i++) {
      final value = _level(i);
      if (value < 0.008) continue;
      final x = i * (width + gap);
      final height = (value * maxHeight).clamp(1.5, maxHeight);
      final barColor = Color.lerp(faintColor, _palette[i], value)!;
      _paint.color = barColor;

      if (mirrored) {
        final upper = Rect.fromLTWH(x, centerY - height, width, height);
        final lower = Rect.fromLTWH(x, centerY, width, height);
        canvas.drawRRect(RRect.fromRectAndRadius(upper, radius), _paint);
        _paint.color = barColor.withValues(alpha: 0.28);
        canvas.drawRRect(RRect.fromRectAndRadius(lower, radius), _paint);
      } else {
        final rect = Rect.fromLTWH(x, size.height - height, width, height);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), _paint);
        final peak = math.pow(peaks[i].clamp(0.0, 1.0), 0.72) * maxHeight;
        if (peak > 2) {
          _paint.color = _palette[i].withValues(alpha: 0.7);
          canvas.drawRect(
            Rect.fromLTWH(x, size.height - peak - 2, width, 1.5),
            _paint,
          );
        }
      }

      if (enableGlow && value > 0.72) {
        _paint.color = Colors.white.withValues(alpha: (value - 0.72) * 0.65);
        canvas.drawRect(
          Rect.fromLTWH(
            x + width * 0.18,
            mirrored ? centerY - height : size.height - height,
            width * 0.64,
            2,
          ),
          _paint,
        );
      }
    }
  }

  void _paintLine(Canvas canvas, Size size) {
    if (barCount < 2) return;
    final dx = size.width / (barCount - 1);
    final baseline = size.height * 0.76;
    final amplitude = size.height * 0.58;
    _path.moveTo(0, baseline - _level(0, 0.78) * amplitude);
    for (var i = 1; i < barCount; i++) {
      final x = i * dx;
      final y = baseline - _level(i, 0.78) * amplitude;
      final previousX = (i - 1) * dx;
      final previousY = baseline - _level(i - 1, 0.78) * amplitude;
      final controlX = (previousX + x) / 2;
      _path.cubicTo(controlX, previousY, controlX, y, x, y);
    }

    _secondaryPath
      ..addPath(_path, Offset.zero)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    _paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: 0.28), Colors.transparent],
    ).createShader(Offset.zero & size);
    canvas.drawPath(_secondaryPath, _paint);
    _paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = enableGlow ? 2.6 : 2
      ..color = color;
    canvas.drawPath(_path, _paint);
  }

  void _paintDots(Canvas canvas, Size size) {
    const gap = 3.0;
    final columnWidth = ((size.width - gap * (barCount - 1)) / barCount).clamp(
      3.0,
      14.0,
    );
    final radius = (columnWidth * 0.28).clamp(1.1, 2.8);
    final step = radius * 2.8;
    final rows = (size.height / step).floor().clamp(4, 18);
    final verticalOffset = (size.height - rows * step) / 2;

    for (var i = 0; i < barCount; i++) {
      final value = levels[i].clamp(0.0, 1.0);
      final active = (value * rows).round();
      final x = i * (columnWidth + gap) + columnWidth / 2;
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

  void _paintCircular(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final minSide = math.min(size.width, size.height);
    final baseRadius = minSide * 0.2;
    final extension = minSide * 0.27;
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = faintColor.withValues(alpha: 0.35);
    canvas.drawCircle(center, baseRadius, _paint);

    for (var i = 0; i < barCount; i++) {
      final angle = i / barCount * math.pi * 2 - math.pi / 2;
      final value = _level(i, 0.76);
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final inner = Offset(
        center.dx + cosA * baseRadius,
        center.dy + sinA * baseRadius,
      );
      final outerRadius = baseRadius + value * extension;
      final outer = Offset(
        center.dx + cosA * outerRadius,
        center.dy + sinA * outerRadius,
      );
      _paint
        ..strokeWidth = 1.2 + value * 2.2
        ..color = _palette[i].withValues(alpha: 0.45 + value * 0.55);
      canvas.drawLine(inner, outer, _paint);
    }

    _paint
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.16 + beatIntensity * 0.2);
    canvas.drawCircle(
      center,
      baseRadius * (0.2 + beatIntensity * 0.08),
      _paint,
    );
  }

  void _paintWave(Canvas canvas, Size size) {
    if (barCount < 2) return;
    final dx = size.width / (barCount - 1);
    final middle = size.height / 2;
    final amplitude = size.height * 0.38;
    _path.moveTo(0, middle - _level(0, 0.82) * amplitude);
    _secondaryPath.moveTo(0, middle + _level(0, 0.82) * amplitude);
    for (var i = 1; i < barCount; i++) {
      final x = i * dx;
      final value = _level(i, 0.82) * amplitude;
      _path.lineTo(x, middle - value);
      _secondaryPath.lineTo(x, middle + value);
    }

    _paint.shader = LinearGradient(
      colors: [color, secondaryColor, tertiaryColor],
    ).createShader(Offset.zero & size);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(_path, _paint);
    _paint
      ..shader = null
      ..strokeWidth = 1.4
      ..color = secondaryColor.withValues(alpha: 0.55);
    canvas.drawPath(_secondaryPath, _paint);
    _paint
      ..strokeWidth = 0.6
      ..color = faintColor.withValues(alpha: 0.45);
    canvas.drawLine(Offset(0, middle), Offset(size.width, middle), _paint);
  }

  void _paintParticles(Canvas canvas, Size size) {
    const gap = 3.0;
    final width = ((size.width - gap * (barCount - 1)) / barCount).clamp(
      2.0,
      16.0,
    );
    for (var i = 0; i < barCount; i++) {
      final value = _level(i);
      if (value < 0.04) continue;
      final height = value * size.height * 0.55;
      _paint.color = _palette[i].withValues(alpha: 0.08 + value * 0.24);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (width + gap), size.height - height, width, height),
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
    final width = ((size.width - gap * (barCount - 1)) / barCount).clamp(
      3.0,
      16.0,
    );
    final shader = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0xFFFF3D00), Color(0xFFFFA000), Color(0xFFFFF59D)],
      stops: [0, 0.58, 1],
    ).createShader(Offset.zero & size);
    _paint.shader = shader;
    for (var i = 0; i < barCount; i++) {
      final value = _level(i, 0.76);
      if (value < 0.025) continue;
      final height = value * size.height * 0.9;
      final x = i * (width + gap);
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

  void _paintRadar(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.4;
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = faintColor.withValues(alpha: 0.4);
    for (var ring = 1; ring <= 3; ring++) {
      canvas.drawCircle(center, radius * ring / 3, _paint);
    }
    for (var spoke = 0; spoke < 8; spoke++) {
      final angle = spoke / 8 * math.pi * 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        ),
        _paint,
      );
    }

    _path.reset();
    for (var i = 0; i < barCount; i++) {
      final angle = i / barCount * math.pi * 2 - math.pi / 2;
      final r = radius * (0.12 + _level(i, 0.82) * 0.88);
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        _path.moveTo(point.dx, point.dy);
      } else {
        _path.lineTo(point.dx, point.dy);
      }
    }
    _path.close();
    _paint
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.12);
    canvas.drawPath(_path, _paint);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = color.withValues(alpha: 0.82);
    canvas.drawPath(_path, _paint);

    final scanAngle = beatIntensity * math.pi * 2 - math.pi / 2;
    _paint
      ..strokeWidth = 2
      ..color = tertiaryColor.withValues(alpha: 0.75);
    canvas.drawLine(
      center,
      Offset(
        center.dx + math.cos(scanAngle) * radius,
        center.dy + math.sin(scanAngle) * radius,
      ),
      _paint,
    );
  }

  void _paintRing(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final minSide = math.min(size.width, size.height);
    final baseRadius = minSide * 0.18;
    final extension = minSide * 0.2;
    for (var layer = 0; layer < 3; layer++) {
      _path.reset();
      final layerRadius = baseRadius + layer * extension * 0.32;
      for (var i = 0; i < barCount; i++) {
        final angle = i / barCount * math.pi * 2 - math.pi / 2;
        final value = _level(i, 0.84);
        final radius = layerRadius + value * extension * (0.52 - layer * 0.1);
        final x = center.dx + math.cos(angle) * radius;
        final y = center.dy + math.sin(angle) * radius;
        if (i == 0) {
          _path.moveTo(x, y);
        } else {
          _path.lineTo(x, y);
        }
      }
      _path.close();
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 - layer * 0.55
        ..color = Color.lerp(
          color,
          secondaryColor,
          layer / 3,
        )!.withValues(alpha: 0.65 - layer * 0.14);
      canvas.drawPath(_path, _paint);
    }
    _paint
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.2 + beatIntensity * 0.18);
    canvas.drawCircle(center, baseRadius * 0.12, _paint);
  }

  void _paintGradientBars(Canvas canvas, Size size) {
    const gap = 2.5;
    final width = ((size.width - gap * (barCount - 1)) / barCount).clamp(
      2.0,
      18.0,
    );
    final radius = Radius.circular(math.min(width / 2, 5));
    final shader = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [color, secondaryColor, tertiaryColor],
    ).createShader(Offset.zero & size);
    _paint.shader = shader;
    for (var i = 0; i < barCount; i++) {
      final value = _level(i, 0.76);
      if (value < 0.02) continue;
      final height = value * size.height * 0.88;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (width + gap), size.height - height, width, height),
          radius,
        ),
        _paint,
      );
    }
    _paint.shader = null;
  }

  void _paintSpectrum3D(Canvas canvas, Size size) {
    if (history.isEmpty) {
      _paintBars(canvas, size, mirrored: false);
      return;
    }
    const gap = 3.0;
    final width = ((size.width - gap * (barCount - 1)) / barCount).clamp(
      2.0,
      12.0,
    );
    final maxHeight = size.height * 0.62;
    final layerCount = history.length;

    for (var layer = layerCount - 1; layer >= 0; layer--) {
      final data = history[(historyHead + layer) % layerCount];
      final depth = layer / math.max(1, layerCount - 1);
      final scale = 0.68 + (1 - depth) * 0.32;
      final alpha = 0.1 + (1 - depth) * 0.3;
      final yShift = depth * size.height * 0.08;
      _paint.color = Color.lerp(
        secondaryColor,
        color,
        1 - depth,
      )!.withValues(alpha: alpha);
      for (var i = 0; i < barCount; i++) {
        final value = math.pow(data[i].clamp(0.0, 1.0), 0.8).toDouble();
        if (value < 0.025) continue;
        final scaledWidth = width * scale;
        final x = i * (width + gap) + (width - scaledWidth) / 2;
        final height = value * maxHeight * scale;
        canvas.drawRect(
          Rect.fromLTWH(x, size.height - height + yShift, scaledWidth, height),
          _paint,
        );
      }
    }

    _paint.color = color;
    for (var i = 0; i < barCount; i++) {
      final value = _level(i, 0.76);
      if (value < 0.02) continue;
      final height = value * maxHeight;
      final x = i * (width + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - height, width, height),
          Radius.circular(width / 2),
        ),
        _paint,
      );
      if (enableGlow && value > 0.72) {
        _paint.color = Colors.white.withValues(alpha: (value - 0.72) * 0.55);
        canvas.drawRect(
          Rect.fromLTWH(x, size.height - height, width, 2),
          _paint,
        );
        _paint.color = color;
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpectrumPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.color != color ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.tertiaryColor != tertiaryColor ||
      oldDelegate.enableGlow != enableGlow ||
      oldDelegate.barCount != barCount;
}
