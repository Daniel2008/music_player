import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'particle.dart';
import 'visualizer_frame.dart';
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
    this.waveform = const [],
    this.frame,
    required this.particles,
    required this.history,
    required int historyHead,
    int historyCount = 0,
    required double beatIntensity,
    double bassEnergy = 0,
    double midEnergy = 0,
    double highEnergy = 0,
    required this.enableGlow,
    required this.showGuides,
    double phase = 0,
    this.glowStrength = 1,
    this.backgroundOpacity = 0,
  }) : _historyHead = historyHead,
       _historyCount = historyCount,
       _beatIntensity = beatIntensity,
       _bassEnergy = bassEnergy,
       _midEnergy = midEnergy,
       _highEnergy = highEnergy,
       _phase = phase,
       super(repaint: repaint);

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
  final List<double> waveform;
  final VisualizerFrame? frame;
  final List<Particle> particles;
  final List<List<double>> history;
  final int _historyHead;
  final int _historyCount;
  final double _beatIntensity;
  final double _bassEnergy;
  final double _midEnergy;
  final double _highEnergy;
  int get historyHead => frame?.historyHead ?? _historyHead;
  int get historyCount => frame?.historyCount ?? _historyCount;
  double get beatIntensity => frame?.signal.beatIntensity ?? _beatIntensity;
  double get bassEnergy => frame?.signal.bassEnergy ?? _bassEnergy;
  double get midEnergy => frame?.signal.midEnergy ?? _midEnergy;
  double get highEnergy => frame?.signal.highEnergy ?? _highEnergy;
  final bool enableGlow;
  final bool showGuides;
  final double _phase;
  double get phase => frame?.phase ?? _phase;
  final double glowStrength;
  final double backgroundOpacity;

  final Paint _paint = Paint()..isAntiAlias = true;
  final Path _path = Path();
  final Path _secondaryPath = Path();
  final Path _fillPath = Path();
  List<Color> _palette = const [];
  List<Color> _paletteStops = const [];
  List<Color> _heatPalette = const [];
  int _paletteCount = 0;
  Color? _palettePrimary;
  Color? _paletteSecondary;
  Color? _paletteTertiary;
  Color? _paletteSurface;
  Size? _waterfallSize;
  int _waterfallColumns = 0;
  int _waterfallRows = 0;
  List<RRect> _waterfallCells = const [];
  static final double _waterfallSilenceFloor = math
      .pow(0.035, 1 / 0.82)
      .toDouble();

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

    // 使用相邻色相区分频段，保持与应用主题协调，避免互补色混合发灰。
    final isDark =
        ThemeData.estimateBrightnessForColor(surfaceColor) == Brightness.dark;
    final baseHue = HSLColor.fromColor(color).hue;
    final hues = [baseHue, (baseHue + 38) % 360, (baseHue + 82) % 360];
    final lightness = isDark ? 0.66 : 0.42;
    _paletteStops = List<Color>.generate(
      3,
      (index) => HSLColor.fromAHSL(
        1,
        hues[index],
        0.76,
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
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (backgroundOpacity > 0) {
      _paint.color = surfaceColor.withValues(
        alpha: backgroundOpacity.clamp(0.0, 1.0),
      );
      canvas.drawRect(Offset.zero & size, _paint);
    }
    final hasFrequencyAxis =
        style == VisualizerStyle.bars ||
        style == VisualizerStyle.mirroredBars ||
        style == VisualizerStyle.dots ||
        style == VisualizerStyle.wave;
    if (showGuides && hasFrequencyAxis) {
      _paintGuides(canvas, size);
    }
    _resetPaint();
    if (hasFrequencyAxis) {
      _paintBeatPulse(canvas, size);
      _paintEnergySweep(canvas, size);
    }

    // 扫光可能使用描边画笔；各主体样式必须从干净的填充状态开始。
    _resetPaint();
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
    canvas.restore();
  }

  void _paintBeatPulse(Canvas canvas, Size size) {
    if (beatIntensity <= 0.02) return;

    final intensity = beatIntensity.clamp(0.0, 1.0).toDouble();
    final isCentered =
        style == VisualizerStyle.mirroredBars || style == VisualizerStyle.wave;
    final y = isCentered ? size.height / 2 : size.height - 1;

    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + intensity * 1.6
      ..color = color.withValues(
        alpha: ((0.08 + intensity * 0.18) * glowStrength)
            .clamp(0.0, 0.32)
            .toDouble(),
      );
    canvas.drawLine(Offset(0, y), Offset(size.width, y), _paint);

    if (enableGlow) {
      _paint
        ..style = PaintingStyle.fill
        ..color = color.withValues(
          alpha: ((0.018 + intensity * 0.045) * glowStrength)
              .clamp(0.0, 0.08)
              .toDouble(),
        );
      final pulseHeight = isCentered
          ? size.height * (0.03 + intensity * 0.07)
          : size.height * (0.018 + intensity * 0.05);
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          isCentered ? y - pulseHeight / 2 : y - pulseHeight,
          size.width,
          pulseHeight,
        ),
        _paint,
      );
    }
  }

  /// Adds a restrained moving light beam so otherwise static styles still feel
  /// alive between beats. The low alpha keeps it readable in both themes.
  void _paintEnergySweep(Canvas canvas, Size size) {
    final motion = (math.sin(phase * 0.72) + 1) * 0.5;
    final x = motion * size.width;
    final beamWidth = math.max(12.0, size.width * 0.028);
    final alpha = (0.035 + beatIntensity * 0.075) * glowStrength;
    final beamRect = Rect.fromLTWH(
      x - beamWidth,
      0,
      beamWidth * 2,
      size.height,
    );

    _paint
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withValues(alpha: 0),
          _paletteStops[1].withValues(alpha: alpha.clamp(0.0, 0.16).toDouble()),
          color.withValues(alpha: 0),
        ],
      ).createShader(beamRect);
    canvas.drawRect(beamRect, _paint);
    _paint.shader = null;

    if (enableGlow && beatIntensity > 0.12) {
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + beatIntensity * 1.8
        ..color = _paletteStops[2].withValues(
          alpha: ((0.10 + beatIntensity * 0.16) * glowStrength)
              .clamp(0.0, 0.32)
              .toDouble(),
        );
      canvas.drawLine(
        Offset(x, size.height * 0.08),
        Offset(x, size.height * 0.92),
        _paint,
      );
    }
  }

  void _paintGuides(Canvas canvas, Size size) {
    final isCentered =
        style == VisualizerStyle.mirroredBars || style == VisualizerStyle.wave;
    final baseline = isCentered ? size.height / 2 : size.height - 1;

    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = faintColor.withValues(alpha: faintColor.a * 0.3);

    for (final fraction in const [0.25, 0.5, 0.75]) {
      final y = isCentered
          ? size.height / 2 + (fraction - 0.5) * size.height * 0.72
          : size.height - fraction * size.height * 0.82;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _paint);
    }

    _paint
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.10);
    canvas.drawLine(Offset(0, baseline), Offset(size.width, baseline), _paint);
  }

  void _paintBars(Canvas canvas, Size size, {required bool mirrored}) {
    const gap = 2.5;
    final layout = _frequencyLayout(size, gap: gap);
    final width = layout.width;
    final radius = Radius.circular(math.min(width / 2, 3.2));
    final centerY = size.height / 2;
    final maxHeight = size.height * (mirrored ? 0.43 : 0.88);
    final segmentCount = (maxHeight / 13.5).round().clamp(8, 18).toInt();
    final segmentStep = maxHeight / segmentCount;
    final segmentHeight = math.max(1.7, segmentStep - 1.25);
    final baseline = size.height - 1;
    var strongestLevel = 0.0;

    for (var i = 0; i < barCount; i++) {
      final value = _level(i);
      strongestLevel = math.max(strongestLevel, value);
      final peakValue = peaks[i].clamp(0.0, 1.0);
      final peak = math.pow(peakValue, 0.5).toDouble() * maxHeight;
      final x = layout.left + i * layout.step;
      final activeSegments = (value * segmentCount).ceil().clamp(
        0,
        segmentCount,
      );

      // 只绘制有能量的分段，静音时不再留下整墙未点亮的色块。
      if (activeSegments == 0) {
        _paint.color = _palette[i].withValues(alpha: 0.12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, (mirrored ? centerY : baseline) - 2, width, 2),
            radius,
          ),
          _paint,
        );
      }
      for (var segment = 0; segment < activeSegments; segment++) {
        final segmentProgress = (segment + 1) / segmentCount;
        final alpha = (0.68 + value * 0.26).clamp(0.68, 0.94).toDouble();
        _paint.color = Color.lerp(
          _palette[i],
          Colors.white,
          segmentProgress * 0.12 * value,
        )!.withValues(alpha: alpha);

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
          _paint.color = _paint.color.withValues(alpha: alpha * 0.48);
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
        _paint.color = _paletteStops[2].withValues(
          alpha: (0.22 + peakValue * 0.58).clamp(0.0, 0.82).toDouble(),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, baseline - peak - 2.5, width, 2.1),
            Radius.circular(math.min(width / 2, 1.8)),
          ),
          _paint,
        );
        if (enableGlow && peakValue > 0.42) {
          _paint.color = _paletteStops[2].withValues(
            alpha: ((0.08 + peakValue * 0.18) * glowStrength)
                .clamp(0.0, 0.22)
                .toDouble(),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                x - width * 0.16,
                baseline - peak - 4.2,
                width * 1.32,
                5.0,
              ),
              Radius.circular(math.min(width, 2.6)),
            ),
            _paint,
          );
        }
      }

      if (enableGlow && value > 0.22) {
        _paint.color = _palette[i].withValues(
          alpha: ((0.12 + (value - 0.22) * 0.32) * glowStrength)
              .clamp(0.0, 0.48)
              .toDouble(),
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

    if (strongestLevel < 0.02) return;

    // A continuous contour unifies the segmented bars and makes transients
    // easier to read without adding another visualizer style.
    _path
      ..reset()
      ..moveTo(
        layout.left + width * 0.5,
        mirrored
            ? centerY - _level(0) * maxHeight
            : baseline - _level(0) * maxHeight,
      );
    for (var i = 1; i < barCount; i++) {
      final x = layout.left + i * layout.step + width * 0.5;
      final y = mirrored
          ? centerY - _level(i) * maxHeight
          : baseline - _level(i) * maxHeight;
      _path.lineTo(x, y);
    }
    _paint
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.1 + beatIntensity * 1.3
      ..color = _paletteStops[2].withValues(
        alpha: (0.36 + beatIntensity * 0.28).clamp(0.0, 0.72).toDouble(),
      );
    if (enableGlow) {
      _paint
        ..strokeWidth = 5.0
        ..color = _paletteStops[2].withValues(
          alpha: (0.055 * glowStrength + beatIntensity * 0.06 * glowStrength)
              .clamp(0.0, 0.16)
              .toDouble(),
        );
      canvas.drawPath(_path, _paint);
      _paint
        ..strokeWidth = 1.1 + beatIntensity * 1.3
        ..color = _paletteStops[2].withValues(
          alpha: (0.36 + beatIntensity * 0.28).clamp(0.0, 0.72).toDouble(),
        );
    }
    canvas.drawPath(_path, _paint);

    if (mirrored) {
      _secondaryPath
        ..reset()
        ..moveTo(layout.left + width * 0.5, centerY + _level(0) * maxHeight);
      for (var i = 1; i < barCount; i++) {
        final x = layout.left + i * layout.step + width * 0.5;
        _secondaryPath.lineTo(x, centerY + _level(i) * maxHeight);
      }
      _paint
        ..strokeWidth = 0.8
        ..color = _paletteStops[1].withValues(alpha: 0.42);
      canvas.drawPath(_secondaryPath, _paint);
    }
  }

  void _paintDots(Canvas canvas, Size size) {
    const gap = 3.0;
    final layout = _frequencyLayout(size, gap: gap, minWidth: 3, maxWidth: 24);
    final columnWidth = layout.width;
    final rows = (size.height / 10).floor().clamp(8, 36);
    final step = size.height * 0.88 / rows;
    final radius = math.min(columnWidth * 0.28, step * 0.32).clamp(0.5, 3.2);
    final verticalOffset = size.height * 0.03;

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
    if (waveform.length < 2) return;
    final dx = size.width / (waveform.length - 1);
    final middle = size.height / 2;
    final amplitude = size.height * 0.42;
    double sample(int index) {
      final value = waveform[index];
      return value.isFinite ? value.clamp(-1.0, 1.0).toDouble() : 0;
    }

    _path.moveTo(0, middle - sample(0) * amplitude);
    _secondaryPath.moveTo(0, middle + sample(0) * amplitude * 0.62);
    _fillPath
      ..reset()
      ..moveTo(0, middle);
    for (var i = 0; i < waveform.length; i++) {
      final x = i * dx;
      final value = sample(i) * amplitude;
      _path.lineTo(x, middle - value);
      _secondaryPath.lineTo(x, middle + value * 0.62);
      _fillPath.lineTo(x, middle - value);
    }
    _fillPath
      ..lineTo(size.width, middle)
      ..close();

    _paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _paletteStops[2].withValues(alpha: 0.28),
        _paletteStops[0].withValues(alpha: 0.04),
      ],
    ).createShader(Offset.zero & size);
    _paint.style = PaintingStyle.fill;
    canvas.drawPath(_fillPath, _paint);
    _paint.shader = null;
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    if (enableGlow) {
      _paint
        ..strokeWidth = 8
        ..color = _paletteStops[2].withValues(
          alpha: (0.16 * glowStrength).clamp(0.0, 0.3),
        );
      canvas.drawPath(_path, _paint);
    }
    _paint
      ..strokeWidth = 2.4
      ..color = Colors.white
      ..shader = LinearGradient(
        colors: _paletteStops,
      ).createShader(Offset.zero & size);
    canvas.drawPath(_path, _paint);
    _paint
      ..shader = null
      ..strokeWidth = 1.8
      ..color = _paletteStops[1].withValues(alpha: 0.82);
    canvas.drawPath(_secondaryPath, _paint);
    _paint
      ..strokeWidth = 0.6
      ..color = faintColor.withValues(alpha: faintColor.a * 0.5);
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
      if (enableGlow) {
        _paint.color = _palette[paletteIndex].withValues(
          alpha: (alpha * 0.12 * glowStrength).clamp(0.0, 0.3),
        );
        canvas.drawCircle(Offset(x, y), particle.size * 1.8, _paint);
      }
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
    final layout = _frequencyLayout(size, gap: gap, minWidth: 3, maxWidth: 80);
    final width = layout.width;
    final baseline = size.height;
    final pulse = 1 + beatIntensity * 0.16;
    var strongestLevel = 0.0;
    for (var i = 0; i < barCount; i++) {
      strongestLevel = math.max(strongestLevel, _level(i, 0.66));
    }
    if (strongestLevel < 0.025) return;

    // Fade the warm base upward instead of drawing a flat colored strip.
    final baseHeight = size.height * (0.06 + bassEnergy * 0.05);
    final baseRect = Rect.fromLTWH(
      0,
      baseline - baseHeight,
      size.width,
      baseHeight,
    );
    _paint
      ..style = PaintingStyle.fill
      ..color = Colors.white
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(
            0xFFFF6D00,
          ).withValues(alpha: strongestLevel * (0.18 + bassEnergy * 0.16)),
          const Color(0xFFFF6D00).withValues(alpha: 0),
        ],
      ).createShader(baseRect);
    canvas.drawRect(baseRect, _paint);

    final outerShader =
        LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFE53900).withValues(alpha: 0.96),
            const Color(0xFFFF6D00).withValues(alpha: 0.94),
            const Color(0xFFFFC107).withValues(alpha: 0.90),
          ],
          stops: const [0, 0.58, 1],
        ).createShader(
          Rect.fromLTWH(
            0,
            baseline - size.height * 0.9,
            size.width,
            size.height * 0.9,
          ),
        );

    final innerShader =
        LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFFF8F00).withValues(alpha: 0.98),
            const Color(0xFFFFD54F).withValues(alpha: 0.96),
            const Color(0xFFFFF8C6).withValues(alpha: 0.92),
          ],
          stops: const [0, 0.56, 1],
        ).createShader(
          Rect.fromLTWH(
            0,
            baseline - size.height * 0.48,
            size.width,
            size.height * 0.48,
          ),
        );

    // Paint.color alpha also modulates shaders; keep it opaque after the base.
    _paint.color = Colors.white;
    _paint.shader = outerShader;
    for (var i = 0; i < barCount; i++) {
      final progress = barCount <= 1 ? 0.0 : i / (barCount - 1);
      final bandEnergy = progress < 0.2
          ? bassEnergy
          : progress < 0.6
          ? midEnergy
          : highEnergy;
      final value = (_level(i, 0.66) * 0.74 + bandEnergy * 0.26)
          .clamp(0.0, 1.0)
          .toDouble();
      if (value < 0.025) continue;
      final height =
          value *
          size.height *
          (0.62 + bandEnergy * 0.28) *
          pulse *
          (0.94 + 0.06 * math.sin(phase * 4.1 + i * 1.13));
      final x = layout.left + i * layout.step;
      final motion = phase * (2.7 + highEnergy * 1.8) + i * 0.73;
      final sway = math.sin(motion) * width * 0.34 * value;
      final lobe = math.sin(motion * 1.7 + 0.8) * width * 0.18 * value;

      _path
        ..reset()
        ..moveTo(x - width * 0.22, baseline)
        ..cubicTo(
          x - width * 0.18,
          baseline - height * 0.26,
          x + width * 0.08 - lobe,
          baseline - height * 0.48,
          x + width * 0.38 + sway,
          baseline - height * 0.72,
        )
        ..quadraticBezierTo(
          x + width * 0.48 + lobe,
          baseline - height * 0.91,
          x + width * 0.62 + sway * 0.48,
          baseline - height,
        )
        ..cubicTo(
          x + width * 0.58 + sway,
          baseline - height * 0.65,
          x + width * 1.18 + lobe,
          baseline - height * 0.32,
          x + width * 1.22,
          baseline,
        )
        ..close();
      canvas.drawPath(_path, _paint);

      // Inner flame separates the bright core from the darker outer flame.
      final innerHeight = height * (0.42 + bandEnergy * 0.12);
      final innerX = x + width * 0.22;
      _secondaryPath
        ..reset()
        ..moveTo(innerX, baseline)
        ..quadraticBezierTo(
          innerX + width * 0.12,
          baseline - innerHeight * 0.42,
          innerX + width * 0.31 + sway * 0.42,
          baseline - innerHeight,
        )
        ..quadraticBezierTo(
          innerX + width * 0.54 + lobe * 0.32,
          baseline - innerHeight * 0.72,
          innerX + width * 0.66,
          baseline,
        )
        ..close();
      _paint.shader = innerShader;
      canvas.drawPath(_secondaryPath, _paint);
      _paint.shader = outerShader;
    }
    _paint.shader = null;

    if (enableGlow && glowStrength > 0) {
      final emberCount = math.min(16, barCount);
      for (var i = 0; i < emberCount; i++) {
        final band = i * barCount ~/ emberCount;
        final energy = _level(band, 0.66);
        if (energy < 0.18) continue;
        final rise = (phase * (0.22 + energy * 0.12) + i * 0.618) % 1;
        final x =
            layout.left +
            (band + 0.5) * layout.step +
            math.sin(phase * 2 + i) * width * 0.45;
        final y = baseline - size.height * energy * (0.15 + rise * 0.64);
        _paint
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFF8F00).withValues(
            alpha: ((1 - rise) * energy * 0.8 * glowStrength).clamp(0.0, 0.9),
          );
        canvas.drawCircle(
          Offset(x, y),
          (1 + energy * 1.5) * (1 - rise * 0.55),
          _paint,
        );
      }
    }

    // A thin hot line at the base reinforces the rhythm without adding
    // per-bar blur objects.
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + beatIntensity * 1.8
      ..color = const Color(0xFFFFD54F).withValues(
        alpha: (0.32 + beatIntensity * 0.34).clamp(0.32, 0.68).toDouble(),
      );
    canvas.drawLine(
      Offset(0, baseline - 1),
      Offset(size.width, baseline - 1),
      _paint,
    );
  }

  void _paintWaterfall(Canvas canvas, Size size) {
    if (history.isEmpty || barCount <= 0 || historyCount == 0) return;
    final visibleRows = historyCount.clamp(1, history.length).toInt();
    final cellWidth = size.width / barCount;
    final rowHeight = size.height / history.length;
    final columnGap = (cellWidth * 0.08).clamp(0.35, 1.4).toDouble();
    final rowGap = (rowHeight * 0.10).clamp(0.35, 1.2).toDouble();
    final cellRadius = Radius.circular(
      math.min(3.5, math.min(cellWidth, rowHeight) * 0.24),
    );
    if (_waterfallSize != size ||
        _waterfallColumns != barCount ||
        _waterfallRows != history.length) {
      _waterfallSize = size;
      _waterfallColumns = barCount;
      _waterfallRows = history.length;
      _waterfallCells = List.generate(history.length * barCount, (index) {
        final age = index ~/ barCount;
        final column = index % barCount;
        return RRect.fromRectAndRadius(
          Rect.fromLTWH(
            column * cellWidth + columnGap / 2,
            size.height - (age + 1) * rowHeight + rowGap / 2,
            math.max(1.0, cellWidth - columnGap),
            math.max(1.0, rowHeight - rowGap),
          ),
          cellRadius,
        );
      });
    }

    double smoothedValue(List<double> data, int index) {
      final current = data[index].clamp(0.0, 1.0).toDouble();
      final previous = index > 0
          ? data[index - 1].clamp(0.0, 1.0).toDouble()
          : current;
      final next = index + 1 < data.length
          ? data[index + 1].clamp(0.0, 1.0).toDouble()
          : current;
      return (previous * 0.18 + current * 0.64 + next * 0.18)
          .clamp(0.0, 1.0)
          .toDouble();
    }

    for (var age = 0; age < visibleRows; age++) {
      final historyIndex =
          (historyHead - 1 - age + history.length * 2) % history.length;
      final data = history[historyIndex];
      final ageProgress = history.length <= 1
          ? 0.0
          : age / (history.length - 1);
      final ageAlpha = math.pow(1.0 - ageProgress, 0.72).clamp(0.16, 1.0);
      for (var i = 0; i < barCount; i++) {
        final value = smoothedValue(data, i);
        final heatIndex = (value * (_heatPalette.length - 1))
            .round()
            .clamp(0, _heatPalette.length - 1)
            .toInt();
        final alpha =
            (value < _waterfallSilenceFloor
                    ? 0.0
                    : 0.06 + math.pow(value, 0.82 * 0.78) * 0.90)
                .clamp(0.0, 0.96)
                .toDouble() *
            ageAlpha;
        if (alpha <= 0.01) continue;
        _paint.color = _heatPalette[heatIndex].withValues(alpha: alpha);
        canvas.drawRRect(_waterfallCells[age * barCount + i], _paint);
      }
    }

    // Highlight the newest spectrum as a smooth contour so the waterfall has
    // a clear present-time edge instead of ending as a flat row of blocks.
    final latest = history[(historyHead - 1 + history.length) % history.length];
    final latestY = size.height - rowHeight * 0.86;
    _path
      ..reset()
      ..moveTo(0, latestY);
    for (var i = 0; i < barCount; i++) {
      final value = math.pow(smoothedValue(latest, i), 0.72).toDouble();
      final x = (i + 0.5) * cellWidth;
      _path.lineTo(x, latestY - value * rowHeight * 0.72);
    }
    _path.lineTo(size.width, latestY);
    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15 + beatIntensity * 1.2
      ..strokeJoin = StrokeJoin.round
      ..color = _paletteStops[2].withValues(
        alpha: (0.36 + beatIntensity * 0.34).clamp(0.36, 0.72).toDouble(),
      );
    canvas.drawPath(_path, _paint);

    if (enableGlow) {
      _paint
        ..strokeWidth = 4.5
        ..color = _paletteStops[2].withValues(
          alpha: (0.07 * glowStrength).clamp(0.0, 0.14),
        );
      canvas.drawPath(_path, _paint);
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
    final discRadius = minSide * (0.38 + bassEnergy * 0.014);
    final spectrumRadius = discRadius * 0.82;
    final extension = minSide * 0.16;

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
          ..color = _palette[i].withValues(
            alpha: ((0.13 + value * 0.12) * glowStrength).clamp(0.0, 0.45),
          );
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
    _paint.color = _paletteStops[2].withValues(alpha: 0.28);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: discRadius * 0.58),
      math.pi * 0.72,
      math.pi * 0.36,
      false,
      _paint,
    );
    canvas.restore();

    if (beatIntensity > 0.04) {
      _paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + beatIntensity * 1.8
        ..color = _paletteStops[2].withValues(
          alpha: (0.18 + beatIntensity * 0.30).clamp(0.0, 0.56).toDouble(),
        );
      canvas.drawCircle(
        center,
        discRadius * (1.06 + beatIntensity * 0.16),
        _paint,
      );
      if (enableGlow) {
        _paint
          ..strokeWidth = 5.0
          ..color = _paletteStops[2].withValues(
            alpha: (0.045 * glowStrength + beatIntensity * 0.05 * glowStrength)
                .clamp(0.0, 0.13)
                .toDouble(),
          );
        canvas.drawCircle(
          center,
          discRadius * (1.06 + beatIntensity * 0.16),
          _paint,
        );
      }
    }

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
      oldDelegate.glowStrength != glowStrength ||
      oldDelegate.backgroundOpacity != backgroundOpacity ||
      oldDelegate.showGuides != showGuides ||
      oldDelegate.barCount != barCount ||
      oldDelegate.historyCount != historyCount ||
      oldDelegate.phase != phase ||
      oldDelegate.beatIntensity != beatIntensity ||
      oldDelegate.bassEnergy != bassEnergy ||
      oldDelegate.midEnergy != midEnergy ||
      oldDelegate.highEnergy != highEnergy;
}
