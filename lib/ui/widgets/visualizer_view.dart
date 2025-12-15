import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';

enum VisualizerStyle { bars, mirroredBars, line, dots }

class VisualizerView extends StatefulWidget {
  const VisualizerView({super.key});

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps 更流畅
    )..repeat();
    _controller.addListener(_tick);
  }

  void _ensureBars(int n) {
    if (_barCount == n) return;
    _barCount = n;
    _levels = List<double>.filled(n, 0.0);
    _targets = List<double>.filled(n, 0.0);
  }

  void _tick() {
    if (!mounted || _barCount == 0) return;

    final isPlaying = context.read<PlayerProvider>().isPlaying;
    final dt = 0.016;

    if (isPlaying) {
      // 更新节拍相位 (模拟 128 BPM)
      _beatPhase += dt * 2.13 * 2 * math.pi;
      if (_beatPhase > 2 * math.pi) {
        _beatPhase -= 2 * math.pi;
        _beatCounter++;
      }

      // 节拍脉冲 - 更强烈
      final beatPulse = math.pow(math.sin(_beatPhase).abs(), 0.5).toDouble();
      _beatIntensity = beatPulse;

      // 强拍
      final isStrongBeat = _beatCounter % 4 == 0;

      for (var i = 0; i < _barCount; i++) {
        // 镜像布局：低频在中间，高频在两边
        // 将位置映射为到中心的距离 (0=中心, 1=边缘)
        final centerDist = (2.0 * i / (_barCount - 1) - 1.0).abs();

        // freqRatio: 0=低频(中间), 1=高频(两边)
        final freqRatio = centerDist;

        // 使用平滑曲线计算各频段权重，实现自然过渡
        // 低频权重：在中间为1，向两边平滑衰减
        final lowWeight = math.pow(1 - freqRatio, 2).toDouble();
        // 中频权重：钟形曲线
        final midWeight = math.exp(-math.pow((freqRatio - 0.4) * 3, 2));
        // 高频权重：在两边为1，向中间平滑衰减
        final highWeight = math.pow(freqRatio, 1.5).toDouble();

        // 低频：跟随节拍，基础很低，节拍时跳高
        final lowEnergy = _beatIntensity * 0.95 + _rng.nextDouble() * 0.05;

        // 中频：波浪 + 随机，基础降低
        final midWave =
            math.sin(_beatPhase * 3 + freqRatio * math.pi * 2) * 0.3;
        final midEnergy = 0.15 + midWave + _rng.nextDouble() * 0.35;

        // 高频：快速随机，基础很低
        final highEnergy = 0.05 + _rng.nextDouble() * 0.4;

        // 混合各频段能量（权重归一化）
        final totalWeight = lowWeight + midWeight + highWeight;
        final freqEnergy =
            (lowEnergy * lowWeight +
                midEnergy * midWeight +
                highEnergy * highWeight) /
            totalWeight;

        // 随机尖峰
        final spike = _rng.nextDouble() < 0.06 ? _rng.nextDouble() * 0.4 : 0.0;

        // 强拍加成 - 主要影响中间的低频
        final strongBoost = isStrongBeat ? 0.25 * lowWeight : 0.0;

        _targets[i] = (freqEnergy + spike + strongBoost).clamp(0.0, 1.0);
      }
    } else {
      // 暂停时
      _beatPhase += dt * 0.8;
      for (var i = 0; i < _barCount; i++) {
        final breath = 0.08 + 0.05 * math.sin(_beatPhase + i * 0.2);
        _targets[i] = breath.clamp(0.0, 1.0);
      }
    }

    // 快速响应的平滑
    for (var i = 0; i < _barCount; i++) {
      final current = _levels[i];
      final target = _targets[i];
      final diff = target - current;
      // 上升非常快，下降较慢
      final factor = diff > 0 ? 0.5 : 0.12;
      _levels[i] = (current + diff * factor).clamp(0.0, 1.0);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        // 增加柱子数量：每 6 像素一个柱子，范围 32-128
        final count = (width / 6).floor().clamp(32, 128);
        _ensureBars(count);

        return SizedBox(
          height: 180,
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _SpectrumPainter(
                      repaint: _controller,
                      levels: _levels,
                      style: _style,
                      color: scheme.primary,
                      faintColor: scheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Material(
                    type: MaterialType.transparency,
                    child: PopupMenuButton<VisualizerStyle>(
                      tooltip: '频谱样式',
                      initialValue: _style,
                      icon: const Icon(Icons.tune, size: 18),
                      onSelected: (v) => setState(() => _style = v),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: VisualizerStyle.bars,
                          child: Text('柱状'),
                        ),
                        PopupMenuItem(
                          value: VisualizerStyle.mirroredBars,
                          child: Text('镜像柱状'),
                        ),
                        PopupMenuItem(
                          value: VisualizerStyle.line,
                          child: Text('曲线'),
                        ),
                        PopupMenuItem(
                          value: VisualizerStyle.dots,
                          child: Text('点阵'),
                        ),
                      ],
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

class _SpectrumPainter extends CustomPainter {
  final Listenable repaint;
  final List<double> levels;
  final VisualizerStyle style;
  final Color color;
  final Color faintColor;

  const _SpectrumPainter({
    required this.repaint,
    required this.levels,
    required this.style,
    required this.color,
    required this.faintColor,
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

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    return oldDelegate.style != style ||
        oldDelegate.color != color ||
        oldDelegate.faintColor != faintColor;
  }
}
