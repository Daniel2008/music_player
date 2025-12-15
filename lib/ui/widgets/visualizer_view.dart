import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';

enum VisualizerStyle {
  bars,
  mirroredBars,
  line,
  dots,
  circular,
  wave,
  particles,
  flame,
  radar,
  ring,
  gradient,
  spectrum3D,
}

extension VisualizerStyleExtension on VisualizerStyle {
  String get displayName {
    switch (this) {
      case VisualizerStyle.bars:
        return '柱状';
      case VisualizerStyle.mirroredBars:
        return '镜像柱状';
      case VisualizerStyle.line:
        return '曲线';
      case VisualizerStyle.dots:
        return '点阵';
      case VisualizerStyle.circular:
        return '圆形';
      case VisualizerStyle.wave:
        return '波浪';
      case VisualizerStyle.particles:
        return '粒子';
      case VisualizerStyle.flame:
        return '火焰';
      case VisualizerStyle.radar:
        return '雷达';
      case VisualizerStyle.ring:
        return '环形';
      case VisualizerStyle.gradient:
        return '渐变柱';
      case VisualizerStyle.spectrum3D:
        return '3D频谱';
    }
  }

  IconData get icon {
    switch (this) {
      case VisualizerStyle.bars:
        return Icons.bar_chart;
      case VisualizerStyle.mirroredBars:
        return Icons.align_vertical_center;
      case VisualizerStyle.line:
        return Icons.show_chart;
      case VisualizerStyle.dots:
        return Icons.grain;
      case VisualizerStyle.circular:
        return Icons.radio_button_unchecked;
      case VisualizerStyle.wave:
        return Icons.waves;
      case VisualizerStyle.particles:
        return Icons.bubble_chart;
      case VisualizerStyle.flame:
        return Icons.local_fire_department;
      case VisualizerStyle.radar:
        return Icons.radar;
      case VisualizerStyle.ring:
        return Icons.trip_origin;
      case VisualizerStyle.gradient:
        return Icons.gradient;
      case VisualizerStyle.spectrum3D:
        return Icons.view_in_ar;
    }
  }
}

class VisualizerView extends StatefulWidget {
  final bool showStyleSelector;
  final VisualizerStyle? fixedStyle;
  final bool enableGlow;
  final ValueChanged<VisualizerStyle>? onStyleChanged;

  const VisualizerView({
    super.key,
    this.showStyleSelector = true,
    this.fixedStyle,
    this.enableGlow = true,
    this.onStyleChanged,
  });

  @override
  State<VisualizerView> createState() => _VisualizerViewState();
}

class _VisualizerViewState extends State<VisualizerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final math.Random _rng = math.Random();

  List<double> _levels = const [];
  List<double> _targets = const [];
  int _barCount = 0;

  VisualizerStyle _style = VisualizerStyle.bars;

  // 节拍模拟
  double _beatPhase = 0.0;
  double _beatIntensity = 0.0;
  int _beatCounter = 0;

  // 粒子系统
  final List<_Particle> _particles = [];

  // 历史数据（用于3D效果）
  List<List<double>> _history = [];
  static const int _historyLength = 12;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();
    _controller.addListener(_tick);
  }

  void _ensureBars(int n) {
    if (_barCount == n) return;
    _barCount = n;
    _levels = List<double>.filled(n, 0.0);
    _targets = List<double>.filled(n, 0.0);
    _history = List.generate(
      _historyLength,
      (_) => List<double>.filled(n, 0.0),
    );
  }

  void _tick() {
    if (!mounted || _barCount == 0) return;

    final isPlaying = context.read<PlayerProvider>().isPlaying;
    final dt = 0.016;

    if (isPlaying) {
      _beatPhase += dt * 2.13 * 2 * math.pi;
      if (_beatPhase > 2 * math.pi) {
        _beatPhase -= 2 * math.pi;
        _beatCounter++;
      }

      final beatPulse = math.pow(math.sin(_beatPhase).abs(), 0.5).toDouble();
      _beatIntensity = beatPulse;

      final isStrongBeat = _beatCounter % 4 == 0;

      for (var i = 0; i < _barCount; i++) {
        final centerDist = (2.0 * i / (_barCount - 1) - 1.0).abs();
        final freqRatio = centerDist;

        final lowWeight = math.pow(1 - freqRatio, 2).toDouble();
        final midWeight = math.exp(-math.pow((freqRatio - 0.4) * 3, 2));
        final highWeight = math.pow(freqRatio, 1.5).toDouble();

        final lowEnergy = _beatIntensity * 0.95 + _rng.nextDouble() * 0.05;
        final midWave =
            math.sin(_beatPhase * 3 + freqRatio * math.pi * 2) * 0.3;
        final midEnergy = 0.15 + midWave + _rng.nextDouble() * 0.35;
        final highEnergy = 0.05 + _rng.nextDouble() * 0.4;

        final totalWeight = lowWeight + midWeight + highWeight;
        final freqEnergy =
            (lowEnergy * lowWeight +
                midEnergy * midWeight +
                highEnergy * highWeight) /
            totalWeight;

        final spike = _rng.nextDouble() < 0.06 ? _rng.nextDouble() * 0.4 : 0.0;
        final strongBoost = isStrongBeat ? 0.25 * lowWeight : 0.0;

        _targets[i] = (freqEnergy + spike + strongBoost).clamp(0.0, 1.0);
      }

      _updateParticles(dt, isStrongBeat);
    } else {
      _beatPhase += dt * 0.8;
      for (var i = 0; i < _barCount; i++) {
        final breath = 0.08 + 0.05 * math.sin(_beatPhase + i * 0.2);
        _targets[i] = breath.clamp(0.0, 1.0);
      }
      _particles.removeWhere((p) => p.life <= 0);
      for (var p in _particles) {
        p.life -= dt * 0.5;
      }
    }

    for (var i = 0; i < _barCount; i++) {
      final current = _levels[i];
      final target = _targets[i];
      final diff = target - current;
      final factor = diff > 0 ? 0.5 : 0.12;
      _levels[i] = (current + diff * factor).clamp(0.0, 1.0);
    }

    // 更新历史记录
    if (_history.isNotEmpty) {
      _history.removeAt(0);
      _history.add(List.from(_levels));
    }
  }

  void _updateParticles(double dt, bool isStrongBeat) {
    _particles.removeWhere((p) => p.life <= 0);

    for (var p in _particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 50 * dt;
      p.life -= dt;
      p.size *= 0.995;
    }

    if (_particles.length < 150) {
      final avgLevel = _levels.isEmpty
          ? 0.0
          : _levels.reduce((a, b) => a + b) / _levels.length;
      final spawnCount = (avgLevel * 5).round() + (isStrongBeat ? 8 : 0);

      for (var i = 0; i < spawnCount; i++) {
        if (_barCount <= 0) break;
        final idx = _rng.nextInt(_barCount);
        final level = _levels[idx];
        if (level > 0.3) {
          _particles.add(
            _Particle(
              x: idx / _barCount,
              y: 1.0 - level,
              vx: (_rng.nextDouble() - 0.5) * 30,
              vy: -_rng.nextDouble() * 80 * level,
              size: 2 + _rng.nextDouble() * 4 * level,
              life: 0.8 + _rng.nextDouble() * 1.2,
              hue: _rng.nextDouble(),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentStyle = widget.fixedStyle ?? _style;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final count = (width / 6).floor().clamp(32, 128);
        _ensureBars(count);

        return SizedBox(
          height: constraints.maxHeight.isFinite ? constraints.maxHeight : 180,
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _SpectrumPainter(
                      repaint: _controller,
                      levels: _levels,
                      style: currentStyle,
                      color: scheme.primary,
                      secondaryColor: scheme.secondary,
                      tertiaryColor: scheme.tertiary,
                      faintColor: scheme.primary.withValues(alpha: 0.18),
                      particles: _particles,
                      history: _history,
                      beatIntensity: _beatIntensity,
                      enableGlow: widget.enableGlow,
                    ),
                  ),
                ),
                if (widget.showStyleSelector)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Material(
                      type: MaterialType.transparency,
                      child: PopupMenuButton<VisualizerStyle>(
                        tooltip: '频谱样式',
                        initialValue: currentStyle,
                        icon: Icon(currentStyle.icon, size: 18),
                        onSelected: (v) {
                          setState(() => _style = v);
                          widget.onStyleChanged?.call(v);
                        },
                        itemBuilder: (context) => VisualizerStyle.values
                            .map(
                              (style) => PopupMenuItem(
                                value: style,
                                child: Row(
                                  children: [
                                    Icon(style.icon, size: 18),
                                    const SizedBox(width: 12),
                                    Text(style.displayName),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Particle {
  double x, y, vx, vy, size, life, hue;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.hue,
  });
}

class _SpectrumPainter extends CustomPainter {
  final Listenable repaint;
  final List<double> levels;
  final VisualizerStyle style;
  final Color color;
  final Color secondaryColor;
  final Color tertiaryColor;
  final Color faintColor;
  final List<_Particle> particles;
  final List<List<double>> history;
  final double beatIntensity;
  final bool enableGlow;

  const _SpectrumPainter({
    required this.repaint,
    required this.levels,
    required this.style,
    required this.color,
    required this.secondaryColor,
    required this.tertiaryColor,
    required this.faintColor,
    required this.particles,
    required this.history,
    required this.beatIntensity,
    required this.enableGlow,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty || size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    switch (style) {
      case VisualizerStyle.bars:
        _paintBars(canvas, size, paint, mirrored: false);
        break;
      case VisualizerStyle.mirroredBars:
        _paintBars(canvas, size, paint, mirrored: true);
        break;
      case VisualizerStyle.line:
        _paintLine(canvas, size, paint);
        break;
      case VisualizerStyle.dots:
        _paintDots(canvas, size, paint);
        break;
      case VisualizerStyle.circular:
        _paintCircular(canvas, size, paint);
        break;
      case VisualizerStyle.wave:
        _paintWave(canvas, size, paint);
        break;
      case VisualizerStyle.particles:
        _paintParticles(canvas, size, paint);
        break;
      case VisualizerStyle.flame:
        _paintFlame(canvas, size, paint);
        break;
      case VisualizerStyle.radar:
        _paintRadar(canvas, size, paint);
        break;
      case VisualizerStyle.ring:
        _paintRing(canvas, size, paint);
        break;
      case VisualizerStyle.gradient:
        _paintGradientBars(canvas, size, paint);
        break;
      case VisualizerStyle.spectrum3D:
        _paintSpectrum3D(canvas, size, paint);
        break;
    }
  }

  void _paintBars(
    Canvas canvas,
    Size size,
    Paint paint, {
    required bool mirrored,
  }) {
    final n = levels.length;
    const gap = 2.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(2.0, 24.0);
    final radius = Radius.circular(barWidth / 2);

    var x = 0.0;
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      paint.color = Color.lerp(faintColor, color, v) ?? color;

      if (!mirrored) {
        final h = (v * size.height).clamp(2.0, size.height);
        final rect = Rect.fromLTWH(x, size.height - h, barWidth, h);
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
          paint,
        );

        if (enableGlow && v > 0.5) {
          paint.color = color.withValues(alpha: 0.3 * (v - 0.5) * 2);
          paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawRRect(
            RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
            paint,
          );
          paint.maskFilter = null;
        }
      } else {
        final half = size.height / 2;
        final h = (v * half).clamp(1.0, half);
        final top = Rect.fromLTWH(x, half - h, barWidth, h);
        final bottom = Rect.fromLTWH(x, half, barWidth, h);
        canvas.drawRRect(
          RRect.fromRectAndCorners(top, topLeft: radius, topRight: radius),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            bottom,
            bottomLeft: radius,
            bottomRight: radius,
          ),
          paint,
        );
      }

      x += barWidth + gap;
    }
  }

  void _paintLine(Canvas canvas, Size size, Paint paint) {
    final n = levels.length;
    if (n < 2) return;

    final dx = size.width / (n - 1);
    final mid = size.height * 0.55;
    final amp = size.height * 0.45;

    final path = Path();
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final x = dx * i;
      final y = mid - v * amp;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    paint
      ..style = PaintingStyle.fill
      ..color = faintColor;
    canvas.drawPath(fill, paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    canvas.drawPath(path, paint);
  }

  void _paintDots(Canvas canvas, Size size, Paint paint) {
    final n = levels.length;
    if (n == 0) return;

    const gapX = 2.0;
    final colWidth = ((size.width - gapX * (n - 1)) / n).clamp(3.0, 18.0);
    final dotRadius = (colWidth / 3).clamp(1.2, 3.5);
    final stepY = dotRadius * 2.6;
    final rows = (size.height / stepY).floor().clamp(6, 32);

    var x = 0.0;
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final active = (v * rows).round().clamp(0, rows);

      for (var r = 0; r < rows; r++) {
        final isOn = r < active;
        final t = isOn ? (r / (rows - 1)).clamp(0.0, 1.0) : 0.0;
        paint.color = isOn
            ? (Color.lerp(faintColor, color, 0.35 + 0.65 * t) ?? color)
            : faintColor.withValues(alpha: 0.10);

        final cx = x + colWidth / 2;
        final cy = size.height - (r + 0.5) * stepY;
        canvas.drawCircle(Offset(cx, cy), dotRadius, paint);
      }

      x += colWidth + gapX;
    }
  }

  void _paintCircular(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.25;
    final maxRadius = math.min(size.width, size.height) * 0.45;
    final n = levels.length;

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = faintColor;
    canvas.drawCircle(center, baseRadius, paint);

    for (var i = 0; i < n; i++) {
      final angle = (i / n) * 2 * math.pi - math.pi / 2;
      final v = levels[i].clamp(0.0, 1.0);
      final r = baseRadius + v * (maxRadius - baseRadius);

      final x1 = center.dx + baseRadius * math.cos(angle);
      final y1 = center.dy + baseRadius * math.sin(angle);
      final x2 = center.dx + r * math.cos(angle);
      final y2 = center.dy + r * math.sin(angle);

      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size.width / n * 0.8).clamp(1.0, 4.0)
        ..color = Color.lerp(faintColor, color, v) ?? color;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);

      if (enableGlow && v > 0.6) {
        paint
          ..color = color.withValues(alpha: 0.4 * (v - 0.6) / 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
        paint.maskFilter = null;
      }
    }

    final breathRadius = baseRadius * 0.3 * (0.8 + 0.2 * beatIntensity);
    paint
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.3 + 0.3 * beatIntensity);
    canvas.drawCircle(center, breathRadius, paint);
  }

  void _paintWave(Canvas canvas, Size size, Paint paint) {
    final n = levels.length;
    if (n < 2) return;

    final dx = size.width / (n - 1);
    final mid = size.height / 2;
    final amp = size.height * 0.4;

    final pathTop = Path();
    final pathBottom = Path();

    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final x = dx * i;
      final yTop = mid - v * amp;
      final yBottom = mid + v * amp;

      if (i == 0) {
        pathTop.moveTo(x, yTop);
        pathBottom.moveTo(x, yBottom);
      } else {
        final prevX = dx * (i - 1);
        final ctrlX = (prevX + x) / 2;
        final prevV = levels[i - 1].clamp(0.0, 1.0);
        pathTop.quadraticBezierTo(ctrlX, mid - prevV * amp, x, yTop);
        pathBottom.quadraticBezierTo(ctrlX, mid + prevV * amp, x, yBottom);
      }
    }

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.6),
        color.withValues(alpha: 0.1),
        color.withValues(alpha: 0.1),
        color.withValues(alpha: 0.6),
      ],
      stops: const [0.0, 0.45, 0.55, 1.0],
    );

    final fillPath = Path()
      ..addPath(pathTop, Offset.zero)
      ..lineTo(size.width, mid)
      ..lineTo(0, mid)
      ..close();

    final fillPath2 = Path()
      ..moveTo(0, mid)
      ..addPath(pathBottom, Offset.zero)
      ..lineTo(size.width, mid)
      ..close();

    paint
      ..style = PaintingStyle.fill
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawPath(fillPath, paint);
    canvas.drawPath(fillPath2, paint);
    paint.shader = null;

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    canvas.drawPath(pathTop, paint);
    canvas.drawPath(pathBottom, paint);
  }

  void _paintParticles(Canvas canvas, Size size, Paint paint) {
    final n = levels.length;
    const gap = 3.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(2.0, 20.0);

    var x = 0.0;
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final h = (v * size.height * 0.6).clamp(2.0, size.height);
      paint.color = faintColor.withValues(alpha: 0.3);
      canvas.drawRect(Rect.fromLTWH(x, size.height - h, barWidth, h), paint);
      x += barWidth + gap;
    }

    for (final p in particles) {
      if (p.life <= 0) continue;

      final px = p.x * size.width;
      final py = p.y * size.height;

      if (px < 0 || px > size.width || py < 0 || py > size.height) continue;

      final alpha = (p.life.clamp(0.0, 1.0) * 0.8);
      final particleColor = HSLColor.fromAHSL(
        1.0,
        p.hue * 60 + 200,
        0.7,
        0.6,
      ).toColor();

      paint
        ..style = PaintingStyle.fill
        ..color = particleColor.withValues(alpha: alpha);

      canvas.drawCircle(Offset(px, py), p.size, paint);

      if (enableGlow) {
        paint
          ..color = particleColor.withValues(alpha: alpha * 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2);
        canvas.drawCircle(Offset(px, py), p.size * 1.5, paint);
        paint.maskFilter = null;
      }
    }
  }

  void _paintFlame(Canvas canvas, Size size, Paint paint) {
    final n = levels.length;
    const gap = 1.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(2.0, 16.0);

    var x = 0.0;
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final h = (v * size.height).clamp(4.0, size.height);

      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFF4500),
          const Color(0xFFFF6B00),
          const Color(0xFFFFD700),
          const Color(0xFFFFFF00).withValues(alpha: 0.8),
          const Color(0xFFFFFFFF).withValues(alpha: 0.3),
        ],
        stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
      );

      final rect = Rect.fromLTWH(x, size.height - h, barWidth, h);

      paint
        ..style = PaintingStyle.fill
        ..shader = gradient.createShader(rect);

      final flamePath = Path();
      flamePath.moveTo(x, size.height);
      flamePath.lineTo(x, size.height - h * 0.7);

      final waveOffset =
          math.sin(i * 0.5 + beatIntensity * math.pi * 2) * barWidth * 0.3;
      flamePath.quadraticBezierTo(
        x + barWidth / 2 + waveOffset,
        size.height - h - 4,
        x + barWidth,
        size.height - h * 0.7,
      );

      flamePath.lineTo(x + barWidth, size.height);
      flamePath.close();

      canvas.drawPath(flamePath, paint);

      if (enableGlow && v > 0.4) {
        paint
          ..shader = null
          ..color = const Color(0xFFFF6B00).withValues(alpha: 0.4 * v)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawPath(flamePath, paint);
        paint.maskFilter = null;
      }

      x += barWidth + gap;
    }
    paint.shader = null;
  }

  void _paintRadar(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.45;
    final n = levels.length;

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = faintColor.withValues(alpha: 0.3);

    for (var r = 1; r <= 4; r++) {
      canvas.drawCircle(center, maxRadius * r / 4, paint);
    }

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final x = center.dx + maxRadius * math.cos(angle);
      final y = center.dy + maxRadius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), paint);
    }

    final path = Path();
    for (var i = 0; i < n; i++) {
      final angle = (i / n) * 2 * math.pi - math.pi / 2;
      final v = levels[i].clamp(0.0, 1.0);
      final r = maxRadius * (0.1 + 0.9 * v);

      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    paint
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.3);
    canvas.drawPath(path, paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    canvas.drawPath(path, paint);

    // 扫描线效果
    final scanAngle = beatIntensity * 2 * math.pi;
    final scanX = center.dx + maxRadius * math.cos(scanAngle - math.pi / 2);
    final scanY = center.dy + maxRadius * math.sin(scanAngle - math.pi / 2);
    paint
      ..strokeWidth = 3
      ..color = color.withValues(alpha: 0.8);
    canvas.drawLine(center, Offset(scanX, scanY), paint);
  }

  void _paintRing(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.2;
    final maxRadius = math.min(size.width, size.height) * 0.45;
    final n = levels.length;

    // 多层环形
    for (var layer = 0; layer < 3; layer++) {
      final layerRadius = baseRadius + (maxRadius - baseRadius) * layer / 2;
      final path = Path();

      for (var i = 0; i < n; i++) {
        final angle = (i / n) * 2 * math.pi - math.pi / 2;
        final v = levels[i].clamp(0.0, 1.0);
        final offset = v * (maxRadius - baseRadius) * 0.3 * (1 - layer * 0.3);
        final r = layerRadius + offset;

        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      final alpha = 0.6 - layer * 0.15;
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 - layer * 0.8
        ..color = Color.lerp(
          color,
          secondaryColor,
          layer / 3,
        )!.withValues(alpha: alpha);
      canvas.drawPath(path, paint);

      if (enableGlow && layer == 0) {
        paint
          ..color = color.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawPath(path, paint);
        paint.maskFilter = null;
      }
    }

    // 中心点
    paint
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.5 + 0.3 * beatIntensity);
    canvas.drawCircle(
      center,
      baseRadius * 0.15 * (1 + 0.3 * beatIntensity),
      paint,
    );
  }

  void _paintGradientBars(Canvas canvas, Size size, Paint paint) {
    final n = levels.length;
    const gap = 2.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(2.0, 24.0);
    final radius = Radius.circular(barWidth / 2);

    var x = 0.0;
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final h = (v * size.height).clamp(2.0, size.height);

      // 彩虹渐变
      final hue = (i / n) * 360;
      final barColor = HSLColor.fromAHSL(
        1.0,
        hue,
        0.7,
        0.5 + 0.2 * v,
      ).toColor();

      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          barColor.withValues(alpha: 0.8),
          barColor,
          HSLColor.fromAHSL(1.0, (hue + 30) % 360, 0.8, 0.7).toColor(),
        ],
      );

      final rect = Rect.fromLTWH(x, size.height - h, barWidth, h);

      paint
        ..style = PaintingStyle.fill
        ..shader = gradient.createShader(rect);

      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
        paint,
      );

      // 发光效果
      if (enableGlow && v > 0.5) {
        paint
          ..shader = null
          ..color = barColor.withValues(alpha: 0.3 * (v - 0.5) * 2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
          paint,
        );
        paint.maskFilter = null;
      }

      x += barWidth + gap;
    }
    paint.shader = null;
  }

  void _paintSpectrum3D(Canvas canvas, Size size, Paint paint) {
    if (history.isEmpty) return;

    final n = levels.length;
    final layerCount = history.length;
    const gap = 2.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(2.0, 16.0);
    final layerOffset = 3.0;
    final maxHeight = size.height * 0.7;

    // 从后往前绘制
    for (var layer = 0; layer < layerCount; layer++) {
      final layerData = history[layer];
      if (layerData.length != n) continue;

      final depth = layer / layerCount;
      final yOffset = -layer * layerOffset;
      final alpha = 0.3 + 0.7 * (1 - depth);
      final scale = 0.7 + 0.3 * (1 - depth);

      var x = size.width * (1 - scale) / 2;
      final scaledBarWidth = barWidth * scale;
      final scaledGap = gap * scale;

      for (var i = 0; i < n; i++) {
        final v = layerData[i].clamp(0.0, 1.0);
        final h = (v * maxHeight * scale).clamp(1.0, maxHeight);

        final layerColor = Color.lerp(
          color.withValues(alpha: alpha),
          faintColor.withValues(alpha: alpha * 0.5),
          depth,
        )!;

        paint
          ..style = PaintingStyle.fill
          ..color = layerColor;

        final rect = Rect.fromLTWH(
          x,
          size.height - h + yOffset,
          scaledBarWidth,
          h,
        );

        canvas.drawRect(rect, paint);

        x += scaledBarWidth + scaledGap;
      }
    }

    // 最前面一层（当前数据）带发光
    var x = 0.0;
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final h = (v * maxHeight).clamp(2.0, maxHeight);

      paint
        ..style = PaintingStyle.fill
        ..color = color;

      final rect = Rect.fromLTWH(x, size.height - h, barWidth, h);
      canvas.drawRect(rect, paint);

      if (enableGlow && v > 0.5) {
        paint
          ..color = color.withValues(alpha: 0.4 * (v - 0.5) * 2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawRect(rect, paint);
        paint.maskFilter = null;
      }

      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    return oldDelegate.style != style ||
        oldDelegate.color != color ||
        oldDelegate.faintColor != faintColor ||
        oldDelegate.enableGlow != enableGlow;
  }
}
