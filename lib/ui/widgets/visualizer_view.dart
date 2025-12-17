import 'dart:typed_data';
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

  // 优化：使用固定大小的缓冲区，避免频繁分配
  static const int maxBars = 128;
  static const int maxParticles = 150;
  static const int historyLength = 10;

  final List<double> _levels = List.filled(maxBars, 0.0);
  final List<double> _targets = List.filled(maxBars, 0.0);
  final List<double> _peaks = List.filled(maxBars, 0.0);
  final List<List<double>> _history = List.generate(
    historyLength,
    (_) => List.filled(maxBars, 0.0),
  );

  int _currentBarCount = 0;
  VisualizerStyle _style = VisualizerStyle.bars;
  bool _isPlaying = false;
  double _beatIntensity = 0.0;

  // 优化的粒子系统
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random();
  double _waveOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();
    _controller.addListener(_tick);
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    _particles.clear();
    super.dispose();
  }

  // 优化：直接操作固定数组，避免创建新对象
  void _updateFromFFT(Float32List fftData, bool isPlaying) {
    _isPlaying = isPlaying;

    if (fftData.isEmpty || _currentBarCount == 0) return;

    // 快速检查是否有有效数据
    bool hasData = false;
    final checkLength = math.min(fftData.length, 50);
    for (var i = 0; i < checkLength; i++) {
      if (fftData[i] > 0.01) {
        hasData = true;
        break;
      }
    }

    if (!hasData || !isPlaying) {
      // 衰减模式
      for (var i = 0; i < _currentBarCount; i++) {
        _targets[i] = _targets[i] * 0.92;
        if (_targets[i] < 0.001) _targets[i] = 0.0;
      }
      _beatIntensity *= 0.92;
      return;
    }

    final fftLength = fftData.length;
    final step = fftLength / _currentBarCount / 2;

    // 优化的频谱映射 - 平衡动态范围
    for (var i = 0; i < _currentBarCount; i++) {
      final start = (i * step).toInt();
      final end = ((i + 1) * step).toInt();

      // 计算区间平均值
      double sum = 0.0;
      for (var j = start; j <= end && j < fftLength; j++) {
        sum += fftData[j];
      }
      final value = sum / (end - start + 1);

      // 使用对数压缩 + 平方根平衡，防止过高音量占满屏幕
      // value 通常在 0-1 之间，但可能达到 2-3
      // 转换为更平衡的线性范围
      final compressed = math.sqrt(value).clamp(0.0, 1.0);

      // 应用平滑调整：低音量时敏感，高音量时压缩
      final adjusted = compressed * 0.85;

      _targets[i] = adjusted;
    }

    // 优化的节拍检测 - 更保守的强度计算
    double bassSum = 0.0;
    final bassEnd = math.min((fftLength * 0.12).toInt(), fftLength);
    for (var i = 0; i < bassEnd; i++) {
      bassSum += fftData[i];
    }

    // 使用平方根压缩，防止过强的节拍信号
    _beatIntensity = (math.sqrt(bassSum / bassEnd) * 0.8).clamp(0.0, 0.8);
  }

  void _tick() {
    if (!mounted || _currentBarCount == 0) return;

    const dt = 0.016;
    _waveOffset += dt * 2.0;

    if (_isPlaying) {
      final isStrongBeat = _beatIntensity > 0.55;
      _updateParticles(dt, isStrongBeat);
    } else {
      // 呼吸效果优化
      for (var i = 0; i < _currentBarCount; i++) {
        final pos = i / (_currentBarCount - 1);
        final breath =
            0.05 +
            0.02 * math.sin(_waveOffset + pos * math.pi * 2) +
            0.01 * math.sin(_waveOffset * 1.5 + pos * math.pi * 4);
        _targets[i] = breath;
      }

      // 清理死亡粒子
      _particles.removeWhere((p) => p.life <= 0);
      for (var p in _particles) {
        p.life -= dt * 0.5;
      }
    }

    // 平滑跟随优化
    final fallSpeed = _isPlaying ? 0.25 : 0.15;
    final riseSpeed = _isPlaying ? 0.6 : 0.4;

    for (var i = 0; i < _currentBarCount; i++) {
      final diff = _targets[i] - _levels[i];
      final factor = diff > 0 ? riseSpeed : fallSpeed;
      _levels[i] += diff * factor;

      // 限制范围
      if (_levels[i] < 0.0) _levels[i] = 0.0;
      if (_levels[i] > 1.0) _levels[i] = 1.0;

      // 峰值衰减
      if (_levels[i] > _peaks[i]) {
        _peaks[i] = _levels[i];
      } else {
        _peaks[i] *= 0.95;
        if (_peaks[i] < 0.001) _peaks[i] = 0.0;
      }
    }

    // 更新历史记录（优化版本）
    if (_isPlaying) {
      // 避免频繁的列表操作
      for (var i = 0; i < historyLength - 1; i++) {
        _history[i].setAll(0, _history[i + 1]);
      }
      _history[historyLength - 1].setAll(0, _levels);
    }
  }

  void _updateParticles(double dt, bool isStrongBeat) {
    // 清理超出范围的粒子
    _particles.removeWhere(
      (p) => p.life <= 0 || p.x < -0.1 || p.x > 1.1 || p.y < -0.1 || p.y > 1.1,
    );

    // 限制粒子总数（性能保护）
    if (_particles.length > maxParticles) {
      _particles.removeRange(0, _particles.length - (maxParticles - 50));
    }

    // 更新现有粒子 - 降低粒子速度，防止过于混乱
    final gravity = isStrongBeat ? 25.0 : 50.0; // 增加重力，让粒子更快消失
    for (var p in _particles) {
      // 水平漂移优化 - 限制漂移范围
      p.vx += (_rng.nextDouble() - 0.5) * 8 * dt;
      p.vx *= 0.95; // 增加阻尼

      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += gravity * dt;

      // 生命衰减 - 更快衰减
      p.life -= dt * (isStrongBeat ? 1.0 : 1.5);

      // 大小变化 - 限制最小尺寸
      p.size *= (0.97 - (1 - p.life) * 0.03);
      if (p.size < 0.8) p.size = 0.8;
    }

    // 简化的能量计算 - 使用中频能量，避免低频过度贡献
    double midLevel = 0.0;
    if (_currentBarCount > 0) {
      final start = (_currentBarCount * 0.2).toInt();
      final end = (_currentBarCount * 0.7).toInt();
      for (var i = start; i < end; i++) {
        midLevel += _levels[i];
      }
      midLevel /= (end - start);
    }

    // 智能粒子生成 - 更保守的生成策略
    if (midLevel > 0.2 || isStrongBeat) {
      final spawnMultiplier = isStrongBeat ? 2 : 1; // 减少粒子生成数量
      final spawnCount = (midLevel * spawnMultiplier).toInt().clamp(
        0,
        4,
      ); // 最多4个

      for (var i = 0; i < spawnCount; i++) {
        // 优先从中间区域生成（避免底部堆积）
        int targetIndex = _findBalancedEnergyIndex();
        if (targetIndex >= 0 && _levels[targetIndex] > 0.15) {
          _spawnParticle(targetIndex, isStrongBeat);
        }
      }
    }
  }

  int _findBalancedEnergyIndex() {
    if (_currentBarCount == 0) return -1;

    // 选择中间区域（30%-70%），避免底部和顶部的 extreme 区域
    final regionStart = (_currentBarCount * 0.3).toInt();
    final regionEnd = (_currentBarCount * 0.7).toInt();

    double bestValue = 0.0;
    int bestIndex = regionStart;

    for (var i = regionStart; i < regionEnd; i++) {
      if (_levels[i] > bestValue) {
        bestValue = _levels[i];
        bestIndex = i;
      }
    }

    return bestValue > 0.15 ? bestIndex : -1;
  }

  void _spawnParticle(int targetIndex, bool isStrongBeat) {
    final level = _levels[targetIndex];
    final energyBoost = isStrongBeat ? 1.8 : 1.0;

    _particles.add(
      _Particle(
        x: targetIndex / _currentBarCount,
        y: 1.0 - level * 0.9,
        vx: (_rng.nextDouble() - 0.5) * 30 * energyBoost,
        vy: -_rng.nextDouble() * 100 * level * energyBoost,
        size: (1.5 + _rng.nextDouble() * 4 * level) * energyBoost,
        life: 0.7 + _rng.nextDouble() * 0.8 + (isStrongBeat ? 0.3 : 0),
        hue: _rng.nextDouble(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final fftData = playerProvider.fftData;
    _updateFromFFT(fftData, playerProvider.isPlaying);

    final scheme = Theme.of(context).colorScheme;
    final currentStyle = widget.fixedStyle ?? _style;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        // 优化：更合理的柱子数量计算
        final count = (width / 8).floor().clamp(24, 100);

        // 只在数量变化时调整数组
        if (count != _currentBarCount) {
          _currentBarCount = count;
        }

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
                      levels: _levels.take(_currentBarCount).toList(),
                      peaks: _peaks.take(_currentBarCount).toList(),
                      style: currentStyle,
                      color: scheme.primary,
                      secondaryColor: scheme.secondary,
                      tertiaryColor: scheme.tertiary,
                      faintColor: scheme.primary.withValues(alpha: 0.18),
                      particles: _particles,
                      history: _isPlaying ? _history : const [],
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
  final List<double> peaks;
  final VisualizerStyle style;
  final Color color;
  final Color secondaryColor;
  final Color tertiaryColor;
  final Color faintColor;
  final List<_Particle> particles;
  final List<List<double>> history;
  final double beatIntensity;
  final bool enableGlow;

  // 缓存画笔，避免重复创建
  final Paint _paint = Paint()..isAntiAlias = true;
  final Path _path = Path();

  _SpectrumPainter({
    required this.repaint,
    required this.levels,
    required this.peaks,
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

    // 重新设置画笔属性（不使用 reset，因为 Paint 没有 reset 方法）
    _paint
      ..style = PaintingStyle.fill
      ..strokeWidth = 0.0
      ..color = Colors.black
      ..isAntiAlias = true
      ..maskFilter = null
      ..shader = null;

    _path.reset();

    switch (style) {
      case VisualizerStyle.bars:
        _paintBars(canvas, size, false);
        break;
      case VisualizerStyle.mirroredBars:
        _paintBars(canvas, size, true);
        break;
      case VisualizerStyle.line:
        _paintLine(canvas, size);
        break;
      case VisualizerStyle.dots:
        _paintDots(canvas, size);
        break;
      case VisualizerStyle.circular:
        _paintCircular(canvas, size);
        break;
      case VisualizerStyle.wave:
        _paintWave(canvas, size);
        break;
      case VisualizerStyle.particles:
        _paintParticles(canvas, size);
        break;
      case VisualizerStyle.flame:
        _paintFlame(canvas, size);
        break;
      case VisualizerStyle.radar:
        _paintRadar(canvas, size);
        break;
      case VisualizerStyle.ring:
        _paintRing(canvas, size);
        break;
      case VisualizerStyle.gradient:
        _paintGradientBars(canvas, size);
        break;
      case VisualizerStyle.spectrum3D:
        _paintSpectrum3D(canvas, size);
        break;
    }
  }

  void _paintBars(Canvas canvas, Size size, bool mirrored) {
    final n = levels.length;
    if (n == 0) return;

    const gap = 2.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(2.0, 24.0);
    final radius = barWidth / 2;

    // 限制最大高度，防止占满全屏
    final maxHeight = size.height * 0.85;

    // 批量绘制，减少状态切换
    _paint.style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      if (v < 0.01) continue;

      final interpColor = Color.lerp(faintColor, color, v);
      _paint.color = interpColor ?? color;
      final x = i * (barWidth + gap);

      if (!mirrored) {
        // 应用高度限制，使用对数曲线平滑高音量显示
        final h = (math.pow(v, 0.7) * maxHeight).clamp(2.0, maxHeight);
        final rect = Rect.fromLTWH(x, size.height - h, barWidth, h);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius),
          ),
          _paint,
        );

        if (enableGlow && v > 0.5) {
          final glowAlpha = math.min(0.3, (v - 0.5) * 0.4); // 限制发光强度
          _paint.color = color.withValues(alpha: glowAlpha);
          _paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              rect,
              topLeft: Radius.circular(radius),
              topRight: Radius.circular(radius),
            ),
            _paint,
          );
          _paint.maskFilter = null;
        }
      } else {
        final half = size.height / 2;
        final h = (math.pow(v, 0.7) * maxHeight / 2).clamp(1.0, maxHeight / 2);

        // 上半部分
        final top = Rect.fromLTWH(x, half - h, barWidth, h);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            top,
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius),
          ),
          _paint,
        );

        // 下半部分
        final bottom = Rect.fromLTWH(x, half, barWidth, h);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            bottom,
            bottomLeft: Radius.circular(radius),
            bottomRight: Radius.circular(radius),
          ),
          _paint,
        );
      }
    }
  }

  void _paintLine(Canvas canvas, Size size) {
    final n = levels.length;
    if (n < 2) return;

    final dx = size.width / (n - 1);
    final mid = size.height * 0.55;
    // 限制振幅，防止超出视口
    final amp = size.height * 0.35;

    _path.moveTo(0, mid);
    for (var i = 0; i < n; i++) {
      final v = math.pow(levels[i].clamp(0.0, 1.0), 0.8);
      _path.lineTo(i * dx, mid - v * amp);
    }

    // 填充区域
    _paint.style = PaintingStyle.fill;
    _paint.color = faintColor;
    final fillPath = Path.from(_path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, _paint);

    // 边缘线
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 2;
    _paint.color = color;
    canvas.drawPath(_path, _paint);
  }

  void _paintDots(Canvas canvas, Size size) {
    final n = levels.length;
    if (n == 0) return;

    const gapX = 2.0;
    final colWidth = ((size.width - gapX * (n - 1)) / n).clamp(3.0, 18.0);
    final dotRadius = (colWidth / 3).clamp(1.2, 3.5);
    final stepY = dotRadius * 2.6;
    final rows = (size.height / stepY).floor();
    if (rows <= 0) return;

    final totalHeight = rows * stepY;
    final offsetY = (size.height - totalHeight) / 2;

    _paint.style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final active = (v * rows).round().clamp(0, rows);
      final x = i * (colWidth + gapX);

      for (var r = 0; r < rows; r++) {
        final isOn = r < active;
        if (!isOn && v < 0.1) continue;

        final cy = size.height - offsetY - (r + 0.5) * stepY;
        final colorValue = 0.35 + 0.65 * (r / rows);
        final interpColor = Color.lerp(faintColor, color, colorValue);
        _paint.color = isOn
            ? (interpColor ?? color)
            : faintColor.withValues(alpha: 0.08);

        canvas.drawCircle(Offset(x + colWidth / 2, cy), dotRadius, _paint);
      }
    }
  }

  void _paintCircular(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.25;
    final maxExtension = math.min(size.width, size.height) * 0.35; // 限制最大扩展
    final n = levels.length;

    // 基础圆圈
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 2;
    _paint.color = faintColor;
    canvas.drawCircle(center, baseRadius, _paint);

    // 频谱线
    _paint.style = PaintingStyle.stroke;
    for (var i = 0; i < n; i++) {
      final angle = (i / n) * 2 * math.pi - math.pi / 2;
      final v = math.pow(levels[i].clamp(0.0, 1.0), 0.8); // 压缩高音量
      final r = baseRadius + v * maxExtension;

      final x1 = center.dx + baseRadius * math.cos(angle);
      final y1 = center.dy + baseRadius * math.sin(angle);
      final x2 = center.dx + r * math.cos(angle);
      final y2 = center.dy + r * math.sin(angle);

      final widthValue = (size.width / n * 0.7).clamp(1.0, 3.0);
      _paint.strokeWidth = widthValue.toDouble();
      final interpColor = Color.lerp(faintColor, color, v.toDouble());
      _paint.color = interpColor ?? color;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _paint);

      if (enableGlow && v > 0.6) {
        final glowAlpha = math.min(0.3, (v - 0.6) * 0.5);
        _paint.color = color.withValues(alpha: glowAlpha);
        _paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _paint);
        _paint.maskFilter = null;
      }
    }

    // 中心呼吸 - 限制大小
    final breathRadius = baseRadius * 0.25 * (0.8 + 0.15 * beatIntensity);
    _paint.style = PaintingStyle.fill;
    _paint.color = color.withValues(alpha: 0.25 + 0.2 * beatIntensity);
    canvas.drawCircle(center, breathRadius, _paint);
  }

  void _paintWave(Canvas canvas, Size size) {
    final n = levels.length;
    if (n < 2) return;

    final dx = size.width / (n - 1);
    final mid = size.height / 2;
    final amp = size.height * 0.45;

    // 优化：直接计算，避免复杂对象
    _path.moveTo(0, mid);
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      _path.lineTo(i * dx, mid - v * amp);
    }

    // 填充
    _paint.style = PaintingStyle.fill;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.7),
        color.withValues(alpha: 0.15),
        color.withValues(alpha: 0.15),
        color.withValues(alpha: 0.7),
      ],
      stops: const [0.0, 0.4, 0.6, 1.0],
    );
    _paint.shader = gradient.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );

    final fillPath = Path.from(_path)
      ..lineTo(size.width, mid)
      ..lineTo(0, mid)
      ..close();
    canvas.drawPath(fillPath, _paint);
    _paint.shader = null;

    // 边缘
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 2.5;
    _paint.strokeCap = StrokeCap.round;
    _paint.color = color;
    canvas.drawPath(_path, _paint);

    if (enableGlow) {
      _paint.strokeWidth = 4;
      _paint.color = color.withValues(alpha: 0.4);
      _paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(_path, _paint);
      _paint.maskFilter = null;
    }

    // 中线
    _paint.strokeWidth = 1;
    _paint.color = color.withValues(alpha: 0.3);
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), _paint);
  }

  void _paintParticles(Canvas canvas, Size size) {
    // 背景柱
    final n = levels.length;
    const gap = 3.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(2.0, 20.0);

    _paint.style = PaintingStyle.fill;
    _paint.color = faintColor.withValues(alpha: 0.3);

    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      if (v < 0.05) continue;

      final h = (v * size.height * 0.6).clamp(2.0, size.height);
      final x = i * (barWidth + gap);
      canvas.drawRect(Rect.fromLTWH(x, size.height - h, barWidth, h), _paint);
    }

    // 粒子
    for (final p in particles) {
      if (p.life <= 0) continue;

      final px = p.x * size.width;
      final py = p.y * size.height;
      if (px < -10 ||
          px > size.width + 10 ||
          py < -10 ||
          py > size.height + 10) {
        continue;
      }

      final alpha = p.life.clamp(0.0, 1.0) * 0.8;
      final particleColor = HSLColor.fromAHSL(
        1.0,
        p.hue * 60 + 200,
        0.7,
        0.6,
      ).toColor();

      _paint.style = PaintingStyle.fill;
      _paint.color = particleColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(px, py), p.size, _paint);

      if (enableGlow) {
        _paint.color = particleColor.withValues(alpha: alpha * 0.5);
        _paint.maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2);
        canvas.drawCircle(Offset(px, py), p.size * 1.5, _paint);
        _paint.maskFilter = null;
      }
    }
  }

  void _paintFlame(Canvas canvas, Size size) {
    final n = levels.length;
    const gap = 2.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(3.0, 18.0);

    _paint.style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final v = math.pow(levels[i].clamp(0.0, 1.0), 0.75); // 压缩火焰高度
      if (v < 0.05) continue;

      final maxH = size.height * 0.65; // 限制最高为65%
      final h = (v * maxH).clamp(4.0, maxH);
      final x = i * (barWidth + gap);

      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: const [
          Color(0xFFFF4500),
          Color(0xFFFF6B00),
          Color(0xFFFFD700),
          Color(0xFFFFFF00),
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
      );

      _paint.shader = gradient.createShader(
        Rect.fromLTWH(x, size.height - h, barWidth, h),
      );

      _path.reset();
      _path.moveTo(x, size.height);
      _path.lineTo(x, size.height - h * 0.75);

      final waveOffset =
          math.sin(i * 0.6 + beatIntensity * math.pi * 2) * barWidth * 0.25;
      _path.quadraticBezierTo(
        x + barWidth / 2 + waveOffset,
        size.height - h - 2,
        x + barWidth,
        size.height - h * 0.75,
      );
      _path.lineTo(x + barWidth, size.height);
      _path.close();

      canvas.drawPath(_path, _paint);
      _paint.shader = null;
    }
  }

  void _paintRadar(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.45;
    final n = levels.length;

    // 网格
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 0.5;
    _paint.color = faintColor.withValues(alpha: 0.3);

    for (var r = 1; r <= 4; r++) {
      canvas.drawCircle(center, maxRadius * r / 4, _paint);
    }

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawLine(
        center,
        Offset(
          center.dx + maxRadius * math.cos(angle),
          center.dy + maxRadius * math.sin(angle),
        ),
        _paint,
      );
    }

    // 频谱形状
    _path.reset();
    for (var i = 0; i < n; i++) {
      final angle = (i / n) * 2 * math.pi - math.pi / 2;
      final v = levels[i].clamp(0.0, 1.0);
      final r = maxRadius * (0.1 + 0.9 * v);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      if (i == 0) {
        _path.moveTo(x, y);
      } else {
        _path.lineTo(x, y);
      }
    }
    _path.close();

    _paint.style = PaintingStyle.fill;
    _paint.color = color.withValues(alpha: 0.3);
    canvas.drawPath(_path, _paint);

    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 2;
    _paint.color = color;
    canvas.drawPath(_path, _paint);

    // 扫描线
    final scanAngle = beatIntensity * 2 * math.pi;
    final scanX = center.dx + maxRadius * math.cos(scanAngle - math.pi / 2);
    final scanY = center.dy + maxRadius * math.sin(scanAngle - math.pi / 2);
    _paint.strokeWidth = 3;
    _paint.color = color.withValues(alpha: 0.8);
    canvas.drawLine(center, Offset(scanX, scanY), _paint);
  }

  void _paintRing(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.18;
    final maxExtension = math.min(size.width, size.height) * 0.25; // 限制扩展距离
    final n = levels.length;

    // 多层环
    for (var layer = 0; layer < 3; layer++) {
      final layerRadius = baseRadius + maxExtension * layer / 3;
      _path.reset();

      for (var i = 0; i < n; i++) {
        final angle = (i / n) * 2 * math.pi - math.pi / 2;
        final v = math.pow(levels[i].clamp(0.0, 1.0), 0.85); // 压缩显示
        final offset = v * maxExtension * 0.4 * (1 - layer * 0.25);
        final r = layerRadius + offset;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);

        if (i == 0) {
          _path.moveTo(x, y);
        } else {
          _path.lineTo(x, y);
        }
      }
      _path.close();

      final alpha = 0.6 - layer * 0.15;
      _paint.style = PaintingStyle.stroke;
      final strokeValue = (3 - layer * 0.8).clamp(1.0, 3.0).toDouble();
      _paint.strokeWidth = strokeValue;
      final layerColor = Color.lerp(color, secondaryColor, layer / 3);
      _paint.color = (layerColor ?? color).withValues(alpha: alpha);
      canvas.drawPath(_path, _paint);

      if (enableGlow && layer == 0) {
        _paint.color = color.withValues(alpha: 0.15);
        _paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawPath(_path, _paint);
        _paint.maskFilter = null;
      }
    }

    // 中心点 - 限制大小
    _paint.style = PaintingStyle.fill;
    _paint.color = color.withValues(alpha: 0.3 + 0.2 * beatIntensity);
    canvas.drawCircle(
      center,
      baseRadius * 0.12 * (1 + 0.2 * beatIntensity),
      _paint,
    );
  }

  void _paintGradientBars(Canvas canvas, Size size) {
    final n = levels.length;
    const gap = 2.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(2.0, 24.0);
    final radius = barWidth / 2;

    _paint.style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      if (v < 0.05) continue;

      final maxH = size.height * 0.9;
      final h = (v * maxH).clamp(2.0, maxH);
      final x = i * (barWidth + gap);

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
          barColor.withValues(alpha: 0.7),
          barColor,
          HSLColor.fromAHSL(1.0, (hue + 30) % 360, 0.8, 0.65).toColor(),
        ],
      );

      _paint.shader = gradient.createShader(
        Rect.fromLTWH(x, size.height - h, barWidth, h),
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, size.height - h, barWidth, h),
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
        ),
        _paint,
      );

      if (enableGlow && v > 0.5) {
        _paint.shader = null;
        _paint.color = barColor.withValues(alpha: 0.3 * (v - 0.5) * 2);
        _paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, size.height - h, barWidth, h),
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius),
          ),
          _paint,
        );
        _paint.maskFilter = null;
      }
    }
    _paint.shader = null;
  }

  void _paintSpectrum3D(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final n = levels.length;
    final layerCount = history.length;
    const gap = 2.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(2.0, 16.0);
    final layerOffset = 3.0;
    final maxHeight = size.height * 0.7;

    // 从后往前绘制
    _paint.style = PaintingStyle.fill;
    for (var layer = 0; layer < layerCount; layer++) {
      final layerData = history[layer];
      if (layerData.length < n) continue;

      final depth = layer / layerCount;
      final yOffset = -layer * layerOffset;
      final alpha = 0.3 + 0.7 * (1 - depth);
      final scale = 0.7 + 0.3 * (1 - depth);

      var x = size.width * (1 - scale) / 2;
      final scaledBarWidth = barWidth * scale;
      final scaledGap = gap * scale;

      for (var i = 0; i < n; i++) {
        final v = layerData[i].clamp(0.0, 1.0);
        if (v < 0.01) continue;

        final h = (v * maxHeight * scale).clamp(1.0, maxHeight);
        _paint.color = Color.lerp(
          color.withValues(alpha: alpha),
          faintColor.withValues(alpha: alpha * 0.5),
          depth,
        )!;

        canvas.drawRect(
          Rect.fromLTWH(x, size.height - h + yOffset, scaledBarWidth, h),
          _paint,
        );
        x += scaledBarWidth + scaledGap;
      }
    }

    // 前景
    var x = 0.0;
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      if (v < 0.01) continue;

      final h = (v * maxHeight).clamp(2.0, maxHeight);
      _paint.color = color;
      canvas.drawRect(Rect.fromLTWH(x, size.height - h, barWidth, h), _paint);

      if (enableGlow && v > 0.5) {
        _paint.color = color.withValues(alpha: 0.4 * (v - 0.5) * 2);
        _paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawRect(Rect.fromLTWH(x, size.height - h, barWidth, h), _paint);
        _paint.maskFilter = null;
      }

      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    // 优化：更精确的重绘判断
    if (oldDelegate.style != style) return true;
    if (oldDelegate.color != color) return true;
    if (oldDelegate.faintColor != faintColor) return true;
    if (oldDelegate.enableGlow != enableGlow) return true;

    // 检查数据是否有显著变化
    if (levels.length != oldDelegate.levels.length) return true;

    // 简单的数据差异检查
    for (var i = 0; i < levels.length && i < oldDelegate.levels.length; i++) {
      if ((levels[i] - oldDelegate.levels[i]).abs() > 0.01) return true;
    }

    return false;
  }
}
