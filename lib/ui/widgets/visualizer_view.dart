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
  static const int maxParticles = 100;
  static const int historyLength = 10;

  final List<double> _levels = List.filled(maxBars, 0.0);
  final List<double> _targets = List.filled(maxBars, 0.0);
  final List<double> _peaks = List.filled(maxBars, 0.0);
  final List<List<double>> _history = List.generate(
    historyLength,
    (_) => List.filled(maxBars, 0.0),
  );
  int _historyHead = 0; // 环形缓冲区头指针

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

  /// 缓存 PlayerProvider 引用，避免在 _tick 中频繁查找
  PlayerProvider? _playerProvider;

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
    // 使用对数尺度分配频段 — 低频分配更多柱子，更符合人耳感知
    for (var i = 0; i < _currentBarCount; i++) {
      // 对数映射：低频精度高，高频压缩
      final logStart = math.pow(i / _currentBarCount, 1.5) * fftLength / 2;
      final logEnd = math.pow((i + 1) / _currentBarCount, 1.5) * fftLength / 2;
      final start = logStart.toInt().clamp(0, fftLength - 1);
      final end = logEnd.toInt().clamp(start + 1, fftLength);

      // 计算区间峰值（比均值更灵敏）
      double peak = 0.0;
      for (var j = start; j < end && j < fftLength; j++) {
        if (fftData[j] > peak) peak = fftData[j];
      }

      // 使用曲线压缩：低音量敏感，高音量压缩
      // pow(x, 0.6) 比 sqrt 更激进，让小信号也可见
      final compressed = math.pow(peak.clamp(0.0, 2.0) / 2.0, 0.55).clamp(0.0, 1.0);

      // 频率补偿：高频自然衰减，给低频柱稍微衰减以避免低音压制
      final freqWeight = 0.7 + 0.3 * (i / _currentBarCount);
      _targets[i] = compressed * freqWeight * 0.95;
    }

    // 改进的节拍检测 — 使用低频能量突变
    double bassEnergy = 0.0;
    final bassEnd = math.min((_currentBarCount * 0.15).toInt().clamp(1, 20), _currentBarCount);
    for (var i = 0; i < bassEnd; i++) {
      bassEnergy += _targets[i];
    }
    bassEnergy /= bassEnd;

    // 节拍响应更快
    if (bassEnergy > _beatIntensity * 1.2) {
      _beatIntensity = bassEnergy.clamp(0.0, 0.9);
    } else {
      _beatIntensity = _beatIntensity * 0.88 + bassEnergy * 0.12;
    }
  }

  void _tick() {
    if (!mounted || _currentBarCount == 0) return;

    // 直接从 PlayerProvider 读取 FFT 数据（不依赖 notifyListeners）
    _playerProvider ??= context.read<PlayerProvider>();
    _updateFromFFT(_playerProvider!.fftData, _playerProvider!.isPlaying);

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

    // 平滑跟随优化 — 上升快、下降慢，更有律动感
    final fallSpeed = _isPlaying ? 0.18 : 0.12;
    final riseSpeed = _isPlaying ? 0.7 : 0.35;

    for (var i = 0; i < _currentBarCount; i++) {
      final diff = _targets[i] - _levels[i];
      final factor = diff > 0 ? riseSpeed : fallSpeed;
      _levels[i] += diff * factor;

      // 限制范围
      if (_levels[i] < 0.0) _levels[i] = 0.0;
      if (_levels[i] > 1.0) _levels[i] = 1.0;

      // 峰值衰减 — 峰值指示线缓慢下落
      if (_levels[i] > _peaks[i]) {
        _peaks[i] = _levels[i];
      } else {
        _peaks[i] *= 0.97; // 慢速下落
        if (_peaks[i] < 0.001) _peaks[i] = 0.0;
      }
    }

    // 更新历史记录 — 环形缓冲区（只写一个槽位，不拷贝整个数组）
    if (_isPlaying) {
      _history[_historyHead].setAll(0, _levels);
      _historyHead = (_historyHead + 1) % historyLength;
    }
  }

  void _updateParticles(double dt, bool isStrongBeat) {
    // 清理超出范围的粒子
    _particles.removeWhere(
      (p) => p.life <= 0 || p.x < -0.15 || p.x > 1.15 || p.y < -0.15 || p.y > 1.15,
    );

    // 限制粒子总数
    if (_particles.length > maxParticles) {
      _particles.removeRange(0, _particles.length - (maxParticles - 30));
    }

    // 更新现有粒子 — 增强物理效果
    for (var p in _particles) {
      // 湍流力 — 让粒子运动更自然
      final turbX = math.sin(p.y * 8 + _waveOffset * 3) * 15;
      final turbY = math.cos(p.x * 6 + _waveOffset * 2) * 10;
      p.vx += (turbX + (_rng.nextDouble() - 0.5) * 5) * dt;
      p.vy += (turbY - 20) * dt; // 轻微上升力

      // 阻尼
      p.vx *= 0.96;
      p.vy *= 0.96;

      p.x += p.vx * dt * 0.003; // 缩小位移尺度
      p.y += p.vy * dt * 0.003;

      // 生命衰减
      p.life -= dt * (isStrongBeat ? 0.6 : 0.9);

      // 大小缓慢缩小
      p.size *= (0.995 - (1 - p.life) * 0.005);
      if (p.size < 0.5) p.size = 0.5;

      // 色相缓慢漂移
      p.hue += dt * 0.02;
      if (p.hue > 1.0) p.hue -= 1.0;
    }

    // 能量计算 — 分频段
    double bassLevel = 0, midLevel = 0, highLevel = 0;
    if (_currentBarCount > 0) {
      final bassEnd = (_currentBarCount * 0.2).toInt().clamp(1, _currentBarCount);
      final midEnd = (_currentBarCount * 0.6).toInt().clamp(1, _currentBarCount);
      for (var i = 0; i < bassEnd; i++) { bassLevel += _levels[i]; }
      bassLevel /= bassEnd;
      for (var i = bassEnd; i < midEnd; i++) { midLevel += _levels[i]; }
      midLevel /= (midEnd - bassEnd).clamp(1, 999);
      for (var i = midEnd; i < _currentBarCount; i++) { highLevel += _levels[i]; }
      highLevel /= (_currentBarCount - midEnd).clamp(1, 999);
    }

    final totalEnergy = bassLevel * 0.4 + midLevel * 0.4 + highLevel * 0.2;

    // 智能粒子生成 — 根据频段生成不同类型的粒子
    if (totalEnergy > 0.12 || isStrongBeat) {
      final spawnCount = isStrongBeat
          ? (totalEnergy * 6).toInt().clamp(2, 8)
          : (totalEnergy * 3).toInt().clamp(0, 4);

      for (var i = 0; i < spawnCount; i++) {
        // 从有能量的频段生成粒子
        final band = _rng.nextDouble();
        int targetIdx;
        double energy;
        double baseHue;

        if (band < 0.3 && bassLevel > 0.15) {
          // 低频 — 大粒子，暖色
          targetIdx = _rng.nextInt((_currentBarCount * 0.2).toInt().clamp(1, _currentBarCount));
          energy = bassLevel;
          baseHue = 0.0; // 红/橙
        } else if (band < 0.7 && midLevel > 0.1) {
          // 中频 — 中粒子，主题色
          final start = (_currentBarCount * 0.2).toInt();
          final range = (_currentBarCount * 0.4).toInt().clamp(1, _currentBarCount);
          targetIdx = start + _rng.nextInt(range);
          energy = midLevel;
          baseHue = 0.55; // 蓝/紫
        } else if (highLevel > 0.08) {
          // 高频 — 小粒子，冷色
          final start = (_currentBarCount * 0.6).toInt();
          final range = (_currentBarCount * 0.4).toInt().clamp(1, _currentBarCount);
          targetIdx = start + _rng.nextInt(range);
          energy = highLevel;
          baseHue = 0.75; // 青/绿
        } else {
          continue;
        }

        targetIdx = targetIdx.clamp(0, _currentBarCount - 1);
        final level = _levels[targetIdx];
        if (level < 0.1) continue;

        final spawnX = targetIdx / _currentBarCount;
        final spawnY = 0.85 - level * 0.3; // 从柱顶附近生成
        final sizeBase = band < 0.3 ? 3.5 : (band < 0.7 ? 2.5 : 1.5);
        final energyBoost = isStrongBeat ? 1.6 : 1.0;

        _particles.add(
          _Particle(
            x: spawnX + (_rng.nextDouble() - 0.5) * 0.05,
            y: spawnY,
            vx: (_rng.nextDouble() - 0.5) * 40 * energy * energyBoost,
            vy: -_rng.nextDouble() * 80 * energy * energyBoost - 15,
            size: (sizeBase + _rng.nextDouble() * 2 * energy) * energyBoost,
            life: 0.8 + _rng.nextDouble() * 1.2 + (isStrongBeat ? 0.4 : 0),
            hue: baseHue + (_rng.nextDouble() - 0.5) * 0.15,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 不再 watch PlayerProvider：频谱数据由 _tick() 中的 context.read 直接获取
    // 这样频谱以 60fps 刷新，不受 Provider 通知频率限制
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
                      levels: _levels,
                      peaks: _peaks,
                      barCount: _currentBarCount,
                      style: currentStyle,
                      color: scheme.primary,
                      secondaryColor: scheme.secondary,
                      tertiaryColor: scheme.tertiary,
                      faintColor: scheme.primary.withValues(alpha: 0.18),
                      particles: _particles,
                      history: _isPlaying ? _history : const [],
                      historyHead: _historyHead,
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
  final int barCount;
  final VisualizerStyle style;
  final Color color;
  final Color secondaryColor;
  final Color tertiaryColor;
  final Color faintColor;
  final List<_Particle> particles;
  final List<List<double>> history;
  final int historyHead;
  final double beatIntensity;
  final bool enableGlow;

  // 缓存画笔，避免重复创建
  final Paint _paint = Paint()..isAntiAlias = true;
  final Path _path = Path();

  _SpectrumPainter({
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

  @override
  void paint(Canvas canvas, Size size) {
    if (barCount <= 0 || size.width <= 0 || size.height <= 0) return;

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
    final n = barCount;
    if (n == 0) return;

    const gap = 2.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(2.0, 24.0);
    final radius = barWidth / 2;
    final maxHeight = size.height * 0.88;

    _paint.style = PaintingStyle.fill;

    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      if (v < 0.008) continue;

      // 颜色从主题色到高亮色渐变
      final hueShift = (i / n) * 40 - 20; // ±20度色相偏移
      final hsl = HSLColor.fromColor(color);
      final barColor = hsl.withHue((hsl.hue + hueShift) % 360)
          .withLightness((hsl.lightness + v * 0.15).clamp(0.0, 1.0))
          .toColor();
      _paint.color = Color.lerp(faintColor, barColor, v) ?? barColor;

      final x = i * (barWidth + gap);

      if (!mirrored) {
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

        // 峰值指示线
        final peakV = peaks[i].clamp(0.0, 1.0);
        if (peakV > 0.02) {
          final peakH = math.pow(peakV, 0.7) * maxHeight;
          _paint.color = color.withValues(alpha: 0.7);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, size.height - peakH - 2, barWidth, 2),
              Radius.circular(1),
            ),
            _paint,
          );
        }

        // 发光效果
        if (enableGlow && v > 0.45) {
          final glowAlpha = math.min(0.35, (v - 0.45) * 0.5);
          _paint.color = barColor.withValues(alpha: glowAlpha);
          _paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
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

        // 上半 — 使用渐变
        final gradUp = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [barColor.withValues(alpha: 0.4), barColor],
        );
        _paint.shader = gradUp.createShader(
          Rect.fromLTWH(x, half - h, barWidth, h),
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, half - h, barWidth, h),
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius),
          ),
          _paint,
        );

        // 下半 — 镜像
        final gradDown = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [barColor.withValues(alpha: 0.35), barColor.withValues(alpha: 0.05)],
        );
        _paint.shader = gradDown.createShader(
          Rect.fromLTWH(x, half, barWidth, h),
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, half, barWidth, h),
            bottomLeft: Radius.circular(radius),
            bottomRight: Radius.circular(radius),
          ),
          _paint,
        );
        _paint.shader = null;
      }
    }
  }

  void _paintLine(Canvas canvas, Size size) {
    final n = barCount;
    if (n < 2) return;

    final dx = size.width / (n - 1);
    final mid = size.height * 0.55;
    final amp = size.height * 0.38;

    // 使用贝塞尔曲线让线条更平滑
    _path.moveTo(0, mid - math.pow(levels[0].clamp(0.0, 1.0), 0.8) * amp);
    for (var i = 1; i < n; i++) {
      final v = math.pow(levels[i].clamp(0.0, 1.0), 0.8);
      final prevV = math.pow(levels[i - 1].clamp(0.0, 1.0), 0.8);
      final x = i * dx;
      final prevX = (i - 1) * dx;
      final y = mid - v * amp;
      final prevY = mid - prevV * amp;
      final cx = (prevX + x) / 2;
      _path.cubicTo(cx, prevY, cx, y, x, y);
    }

    // 渐变填充
    _paint.style = PaintingStyle.fill;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.35),
        color.withValues(alpha: 0.08),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    _paint.shader = gradient.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    final fillPath = Path.from(_path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, _paint);
    _paint.shader = null;

    // 主线条 — 2层：底部发光 + 顶部亮线
    if (enableGlow) {
      _paint.style = PaintingStyle.stroke;
      _paint.strokeWidth = 5;
      _paint.strokeCap = StrokeCap.round;
      _paint.strokeJoin = StrokeJoin.round;
      _paint.color = color.withValues(alpha: 0.3);
      _paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(_path, _paint);
      _paint.maskFilter = null;
    }

    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 2.5;
    _paint.strokeCap = StrokeCap.round;
    _paint.strokeJoin = StrokeJoin.round;
    _paint.color = color;
    canvas.drawPath(_path, _paint);
  }

  void _paintDots(Canvas canvas, Size size) {
    final n = barCount;
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
    final baseRadius = math.min(size.width, size.height) * 0.22;
    final maxExtension = math.min(size.width, size.height) * 0.32;
    final n = barCount;

    // 基础圆圈 — 双层
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 1.5;
    _paint.color = faintColor.withValues(alpha: 0.3);
    canvas.drawCircle(center, baseRadius, _paint);
    _paint.color = faintColor.withValues(alpha: 0.15);
    canvas.drawCircle(center, baseRadius * 0.6, _paint);

    // 频谱线 — 带颜色渐变
    _paint.style = PaintingStyle.stroke;
    for (var i = 0; i < n; i++) {
      final angle = (i / n) * 2 * math.pi - math.pi / 2;
      final v = math.pow(levels[i].clamp(0.0, 1.0), 0.75);
      final r = baseRadius + v * maxExtension;

      final x1 = center.dx + baseRadius * math.cos(angle);
      final y1 = center.dy + baseRadius * math.sin(angle);
      final x2 = center.dx + r * math.cos(angle);
      final y2 = center.dy + r * math.sin(angle);

      final widthValue = (size.width / n * 0.7).clamp(1.0, 3.5);
      _paint.strokeWidth = widthValue.toDouble();

      // 颜色随角度渐变
      final hueOffset = (i / n) * 60 - 30;
      final hsl = HSLColor.fromColor(color);
      final lineColor = hsl.withHue((hsl.hue + hueOffset) % 360)
          .withLightness((hsl.lightness + v.toDouble() * 0.2).clamp(0.0, 0.95))
          .toColor();
      _paint.color = Color.lerp(faintColor, lineColor, v.toDouble()) ?? lineColor;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _paint);

      if (enableGlow && v > 0.5) {
        final glowAlpha = math.min(0.35, (v - 0.5) * 0.6);
        _paint.color = lineColor.withValues(alpha: glowAlpha);
        _paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _paint);
        _paint.maskFilter = null;
      }
    }

    // 外圈连接线 — 用贝塞尔曲线连接各个端点
    _path.reset();
    for (var i = 0; i < n; i++) {
      final angle = (i / n) * 2 * math.pi - math.pi / 2;
      final v = math.pow(levels[i].clamp(0.0, 1.0), 0.75);
      final r = baseRadius + v * maxExtension;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        _path.moveTo(x, y);
      } else {
        _path.lineTo(x, y);
      }
    }
    _path.close();
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 1.5;
    _paint.color = color.withValues(alpha: 0.3);
    canvas.drawPath(_path, _paint);

    // 中心呼吸 — 双层发光
    final breathRadius = baseRadius * 0.3 * (0.85 + 0.15 * beatIntensity);
    _paint.style = PaintingStyle.fill;
    if (enableGlow) {
      _paint.color = color.withValues(alpha: 0.15 + 0.15 * beatIntensity);
      _paint.maskFilter = MaskFilter.blur(BlurStyle.normal, breathRadius * 0.6);
      canvas.drawCircle(center, breathRadius * 1.5, _paint);
      _paint.maskFilter = null;
    }
    _paint.color = color.withValues(alpha: 0.3 + 0.3 * beatIntensity);
    canvas.drawCircle(center, breathRadius, _paint);
  }

  void _paintWave(Canvas canvas, Size size) {
    final n = barCount;
    if (n < 2) return;

    final dx = size.width / (n - 1);
    final mid = size.height / 2;
    final amp = size.height * 0.42;

    // 上半波 — 贝塞尔曲线
    _path.moveTo(0, mid - levels[0].clamp(0.0, 1.0) * amp);
    for (var i = 1; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final prevV = levels[i - 1].clamp(0.0, 1.0);
      final x = i * dx;
      final prevX = (i - 1) * dx;
      final y = mid - v * amp;
      final prevY = mid - prevV * amp;
      final cx = (prevX + x) / 2;
      _path.cubicTo(cx, prevY, cx, y, x, y);
    }

    // 下半波（镜像）
    final lowerPath = Path();
    lowerPath.moveTo(0, mid + levels[0].clamp(0.0, 1.0) * amp * 0.6);
    for (var i = 1; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final prevV = levels[i - 1].clamp(0.0, 1.0);
      final x = i * dx;
      final prevX = (i - 1) * dx;
      final y = mid + v * amp * 0.6;
      final prevY = mid + prevV * amp * 0.6;
      final cx = (prevX + x) / 2;
      lowerPath.cubicTo(cx, prevY, cx, y, x, y);
    }

    // 填充上半波
    _paint.style = PaintingStyle.fill;
    final gradUp = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.5),
        color.withValues(alpha: 0.12),
        Colors.transparent,
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    _paint.shader = gradUp.createShader(
      Rect.fromLTWH(0, 0, size.width, mid),
    );
    final fillUp = Path.from(_path)
      ..lineTo(size.width, mid)
      ..lineTo(0, mid)
      ..close();
    canvas.drawPath(fillUp, _paint);

    // 填充下半波
    final gradDown = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        secondaryColor.withValues(alpha: 0.1),
        secondaryColor.withValues(alpha: 0.35),
      ],
      stops: const [0.0, 0.4, 1.0],
    );
    _paint.shader = gradDown.createShader(
      Rect.fromLTWH(0, mid, size.width, mid),
    );
    final fillDown = Path.from(lowerPath)
      ..lineTo(size.width, mid)
      ..lineTo(0, mid)
      ..close();
    canvas.drawPath(fillDown, _paint);
    _paint.shader = null;

    // 主线条
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 2.5;
    _paint.strokeCap = StrokeCap.round;
    _paint.strokeJoin = StrokeJoin.round;
    _paint.color = color;
    canvas.drawPath(_path, _paint);

    // 镜像线条
    _paint.color = secondaryColor.withValues(alpha: 0.5);
    _paint.strokeWidth = 1.5;
    canvas.drawPath(lowerPath, _paint);

    if (enableGlow) {
      _paint.strokeWidth = 5;
      _paint.color = color.withValues(alpha: 0.25);
      _paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(_path, _paint);
      _paint.maskFilter = null;
    }

    // 中线
    _paint.strokeWidth = 0.5;
    _paint.color = color.withValues(alpha: 0.2);
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), _paint);
  }

  void _paintParticles(Canvas canvas, Size size) {
    final n = barCount;
    const gap = 2.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(2.0, 20.0);
    final radius = barWidth / 2;

    // 背景柱 — 带渐变
    _paint.style = PaintingStyle.fill;
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      if (v < 0.03) continue;

      final h = (math.pow(v, 0.7) * size.height * 0.65).clamp(2.0, size.height);
      final x = i * (barWidth + gap);
      final rect = Rect.fromLTWH(x, size.height - h, barWidth, h);

      final barGrad = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          faintColor.withValues(alpha: 0.15),
          faintColor.withValues(alpha: 0.4 * v),
        ],
      );
      _paint.shader = barGrad.createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect,
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
        ),
        _paint,
      );
    }
    _paint.shader = null;

    // 粒子连接线 — 近距离粒子间画线条（星座效果）
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 0.5;
    for (var i = 0; i < particles.length; i++) {
      final a = particles[i];
      if (a.life <= 0.2) continue;
      for (var j = i + 1; j < particles.length && j < i + 8; j++) {
        final b = particles[j];
        if (b.life <= 0.2) continue;
        final dx = (a.x - b.x) * size.width;
        final dy = (a.y - b.y) * size.height;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < 60) {
          final lineAlpha = (1 - dist / 60) * 0.25 * math.min(a.life, b.life);
          _paint.color = color.withValues(alpha: lineAlpha.clamp(0.0, 0.3));
          canvas.drawLine(
            Offset(a.x * size.width, a.y * size.height),
            Offset(b.x * size.width, b.y * size.height),
            _paint,
          );
        }
      }
    }

    // 粒子本体 — 多层渲染
    _paint.style = PaintingStyle.fill;
    for (final p in particles) {
      if (p.life <= 0) continue;

      final px = p.x * size.width;
      final py = p.y * size.height;
      if (px < -10 || px > size.width + 10 || py < -10 || py > size.height + 10) continue;

      final lifeAlpha = p.life.clamp(0.0, 1.0);
      // 颜色根据 hue 映射到主题色谱
      final particleColor = HSLColor.fromAHSL(
        1.0,
        p.hue * 120 + HSLColor.fromColor(color).hue - 30, // 基于主题色偏移
        0.75,
        0.55 + 0.2 * lifeAlpha,
      ).toColor();

      // 外层发光
      if (enableGlow && p.size > 1.5) {
        _paint.color = particleColor.withValues(alpha: lifeAlpha * 0.2);
        _paint.maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2.5);
        canvas.drawCircle(Offset(px, py), p.size * 2, _paint);
        _paint.maskFilter = null;
      }

      // 内层实体
      _paint.color = particleColor.withValues(alpha: lifeAlpha * 0.85);
      canvas.drawCircle(Offset(px, py), p.size, _paint);

      // 高光点
      if (p.size > 1.2) {
        _paint.color = Colors.white.withValues(alpha: lifeAlpha * 0.5);
        canvas.drawCircle(Offset(px - p.size * 0.25, py - p.size * 0.25), p.size * 0.3, _paint);
      }
    }
  }

  void _paintFlame(Canvas canvas, Size size) {
    final n = barCount;
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
    final n = barCount;

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
    final n = barCount;

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
    final n = barCount;
    if (n == 0) return;
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

    final n = barCount;
    if (n == 0) return;
    final layerCount = history.length;
    const gap = 2.5;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(2.0, 14.0);
    final radius = Radius.circular(barWidth / 2);
    final layerSpacing = size.height * 0.025;
    final maxHeight = size.height * 0.65;

    // 缓存主色 HSL — 避免在循环中重复转换
    final baseHue = HSLColor.fromColor(color).hue;

    // 地面反射线
    _paint.style = PaintingStyle.stroke;
    _paint.strokeWidth = 0.5;
    _paint.color = faintColor.withValues(alpha: 0.15);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      _paint,
    );

    // 从后往前绘制历史层 — 环形缓冲区顺序读取
    _paint.style = PaintingStyle.fill;
    for (var layer = layerCount - 1; layer >= 0; layer--) {
      // 环形缓冲区：historyHead 是下一个写入位置，所以最旧的数据在 historyHead
      final ringIdx = (historyHead + layer) % layerCount;
      final layerData = history[ringIdx];
      if (layerData.length < n) continue;

      final depth = layer / layerCount.clamp(1, 999);
      final yShift = -layer * layerSpacing;
      final scale = 1.0 - depth * 0.35;
      final alpha = (1.0 - depth * 0.8).clamp(0.05, 0.6);

      final totalWidth = n * barWidth * scale + (n - 1) * gap * scale;
      var x = (size.width - totalWidth) / 2;
      final scaledBarWidth = barWidth * scale;
      final scaledGap = gap * scale;

      for (var i = 0; i < n; i++) {
        final v = layerData[i].clamp(0.0, 1.0);
        if (v < 0.02) {
          x += scaledBarWidth + scaledGap;
          continue;
        }

        final h = (math.pow(v, 0.8) * maxHeight * scale).clamp(1.0, maxHeight);
        final barTop = size.height - h + yShift;
        final barRect = Rect.fromLTWH(x, barTop, scaledBarWidth, h);
        final rrect = RRect.fromRectAndCorners(
          barRect,
          topLeft: radius,
          topRight: radius,
        );

        // 基于频率的色相偏移
        final hue = baseHue + (i / n) * 30 - 15;
        final barColor = HSLColor.fromAHSL(
          alpha,
          hue % 360,
          0.6 - depth * 0.2, // 远处饱和度降低
          0.5 + v * 0.2,
        ).toColor();

        // 渐变填充
        final grad = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            barColor,
            barColor.withValues(alpha: alpha * 0.3),
          ],
        );
        _paint.shader = grad.createShader(barRect);
        canvas.drawRRect(rrect, _paint);
        _paint.shader = null;

        x += scaledBarWidth + scaledGap;
      }
    }

    // 前景层（当前帧） — 全不透明 + 发光 + 高光
    var x = 0.0;
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      if (v < 0.02) {
        x += barWidth + gap;
        continue;
      }

      final h = (math.pow(v, 0.75) * maxHeight).clamp(2.0, maxHeight);
      final barTop = size.height - h;
      final barRect = Rect.fromLTWH(x, barTop, barWidth, h);
      final rrect = RRect.fromRectAndCorners(
        barRect,
        topLeft: radius,
        topRight: radius,
      );

      // 频率色相
      final hue = baseHue + (i / n) * 40 - 20;
      final barColor = HSLColor.fromAHSL(
        1.0,
        hue % 360,
        0.75,
        0.45 + v * 0.15,
      ).toColor();

      // 渐变填充
      final grad = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          barColor,
          faintColor.withValues(alpha: 0.6),
        ],
        stops: const [0.0, 1.0],
      );
      _paint.shader = grad.createShader(barRect);
      canvas.drawRRect(rrect, _paint);
      _paint.shader = null;

      // 顶部高光
      if (h > 4) {
        final highlightRect = Rect.fromLTWH(
          x + barWidth * 0.15,
          barTop + 1,
          barWidth * 0.7,
          math.min(h * 0.15, 6),
        );
        _paint.color = Colors.white.withValues(alpha: 0.35 * v);
        canvas.drawRRect(
          RRect.fromRectAndRadius(highlightRect, Radius.circular(barWidth * 0.3)),
          _paint,
        );
      }

      // 发光
      if (enableGlow && v > 0.3) {
        final glowAlpha = (v - 0.3) * 0.6;
        _paint.color = barColor.withValues(alpha: glowAlpha.clamp(0.0, 0.5));
        _paint.maskFilter = MaskFilter.blur(BlurStyle.normal, barWidth * 1.5);
        canvas.drawRRect(rrect, _paint);
        _paint.maskFilter = null;
      }

      // 底部反射（倒影）
      if (h > 10) {
        final reflectionHeight = math.min(h * 0.15, 8.0);
        final reflectionRect = Rect.fromLTWH(
          x, size.height, barWidth, reflectionHeight,
        );
        final reflGrad = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            barColor.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        );
        _paint.shader = reflGrad.createShader(reflectionRect);
        canvas.drawRect(reflectionRect, _paint);
        _paint.shader = null;
      }

      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    // repaint Listenable (AnimationController) 已控制重绘频率
    // 仅在配置项变化时强制重绘
    return oldDelegate.style != style ||
        oldDelegate.color != color ||
        oldDelegate.enableGlow != enableGlow ||
        barCount != oldDelegate.barCount;
  }
}
