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
  List<double> _peaks = const []; // 峰值记录
  int _barCount = 0;

  VisualizerStyle _style = VisualizerStyle.bars;

  // 缓存播放状态，避免每帧访问 Provider
  bool _isPlaying = false;
  // 缓存是否真正在播放音频（位置在持续变化）
  bool _hasAudio = false;
  // 缓存上一次的播放位置
  Duration _lastPosition = Duration.zero;
  // 上次位置变化的时间
  DateTime _lastPositionChangeTime = DateTime.now();

  // 节拍模拟 - 多层节奏
  double _beatPhase = 0.0;
  double _beatIntensity = 0.0;
  int _beatCounter = 0;
  double _subBeatPhase = 0.0; // 副节拍
  double _measurePhase = 0.0; // 小节相位

  // 动态 BPM 模拟（80-160 BPM 范围内变化）
  double _currentBPM = 128.0;
  double _targetBPM = 128.0;
  double _bpmChangeTimer = 0.0;

  // 能量累积
  double _globalEnergy = 0.0;

  // 粒子系统
  final List<_Particle> _particles = [];

  // 历史数据（用于3D效果）
  List<List<double>> _history = [];
  static const int _historyLength = 12;

  // 波浪偏移
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 监听播放状态变化
    _isPlaying = context.read<PlayerProvider>().isPlaying;
  }

  void _ensureBars(int n) {
    if (_barCount == n) return;
    _barCount = n;
    _levels = List<double>.filled(n, 0.0);
    _targets = List<double>.filled(n, 0.0);
    _peaks = List<double>.filled(n, 0.0);
    _history = List.generate(
      _historyLength,
      (_) => List<double>.filled(n, 0.0),
    );
  }

  void _updatePlayingState(
    bool isPlaying,
    Duration position,
    Duration duration,
  ) {
    _isPlaying = isPlaying;

    final now = DateTime.now();

    // 检测位置是否在变化（真正在播放）
    if (position != _lastPosition && position > Duration.zero) {
      _lastPosition = position;
      _lastPositionChangeTime = now;
    }

    // 判断是否真正在播放：
    // 1. isPlaying 为 true
    // 2. 有时长（已加载音频）
    // 3. 位置在最近 500ms 内有变化（说明音频正在播放）
    final timeSinceLastChange = now.difference(_lastPositionChangeTime);
    _hasAudio =
        isPlaying &&
        duration > Duration.zero &&
        position > Duration.zero &&
        timeSinceLastChange.inMilliseconds < 500;
  }

  void _tick() {
    if (!mounted || _barCount == 0) return;

    final dt = 0.016;

    // 只有在真正播放且有音频时才跳动
    if (_isPlaying && _hasAudio) {
      // 快速 BPM (240-320)，极快节奏
      _bpmChangeTimer += dt;
      if (_bpmChangeTimer > 1.0) {
        _bpmChangeTimer = 0;
        _targetBPM = 240 + _rng.nextDouble() * 80;
      }
      _currentBPM += (_targetBPM - _currentBPM) * dt * 5.0;

      // 主节拍
      final beatSpeed = _currentBPM / 60.0 * 2 * math.pi;
      _beatPhase += dt * beatSpeed;
      if (_beatPhase > 2 * math.pi) {
        _beatPhase -= 2 * math.pi;
        _beatCounter++;
        // 基础能量设为0，只依赖节拍
      }

      // 副节拍（极快）
      _subBeatPhase += dt * beatSpeed * 4.0;
      if (_subBeatPhase > 2 * math.pi) _subBeatPhase -= 2 * math.pi;

      // 小节相位
      _measurePhase += dt * beatSpeed / 4;
      if (_measurePhase > 2 * math.pi) _measurePhase -= 2 * math.pi;

      // 波浪偏移（极快）
      _waveOffset += dt * 12.0;

      // 节拍脉冲（更尖锐，响应更快）
      final beatPulse = math
          .pow((math.sin(_beatPhase) * 0.5 + 0.5), 0.4)
          .toDouble();
      final subBeatPulse =
          math.pow((math.sin(_subBeatPhase) * 0.5 + 0.5), 0.4).toDouble() *
          0.35;
      _beatIntensity = (beatPulse * 0.6 + subBeatPulse).clamp(0.0, 1.0);

      // 节拍类型
      final beatInMeasure = _beatCounter % 4;
      final isDownbeat = beatInMeasure == 0;

      for (var i = 0; i < _barCount; i++) {
        final pos = i / (_barCount - 1);

        // 基础能量为0，完全由节拍驱动（大幅降低）
        double energy = _beatIntensity * 0.6;

        // 波浪效果（降低幅度）
        final wave1 = math.sin(_waveOffset + pos * math.pi * 6) * 0.12;
        final wave2 = math.sin(_waveOffset * 2.0 + pos * math.pi * 3) * 0.08;
        energy += wave1 + wave2;

        // 强拍时全体提升（降低）
        if (isDownbeat) {
          energy += 0.1;
        }

        // 副节拍脉冲（降低）
        energy += subBeatPulse * 0.08;

        // 相邻柱子的关联（产生波动感）
        if (i > 0 && i < _barCount - 1) {
          final neighborEffect =
              (_targets[i - 1] + _targets[math.min(i + 1, _barCount - 1)]) *
              0.05;
          energy += neighborEffect;
        }

        _targets[i] = energy.clamp(0.0, 1.0);
      }

      _updateParticles(dt, isDownbeat);
    } else {
      // 暂停时的呼吸效果
      _beatPhase += dt * 0.8;
      _waveOffset += dt * 0.5;

      for (var i = 0; i < _barCount; i++) {
        final pos = i / (_barCount - 1);
        final breath =
            0.08 +
            0.05 * math.sin(_beatPhase + pos * math.pi * 2) +
            0.03 * math.sin(_waveOffset * 2 + pos * math.pi * 4);
        _targets[i] = breath.clamp(0.0, 1.0);
      }

      _particles.removeWhere((p) => p.life <= 0);
      for (var p in _particles) {
        p.life -= dt * 0.5;
      }
    }

    // === 快速响应的跟随 ===
    for (var i = 0; i < _barCount; i++) {
      final current = _levels[i];
      final target = _targets[i];
      final diff = target - current;

      // 上升瞬间，下降快速，极度灵敏
      final factor = diff > 0 ? 0.95 : 0.6;
      _levels[i] = (current + diff * factor).clamp(0.0, 1.0);

      // 更新峰值
      if (_levels[i] > _peaks[i]) {
        _peaks[i] = _levels[i];
      } else {
        _peaks[i] = math.max(0, _peaks[i] - dt * 1.2);
      }
    }

    // 更新历史记录
    if (_history.isNotEmpty) {
      _history.removeAt(0);
      _history.add(List.from(_levels));
    }
  }

  void _updateParticles(double dt, bool isStrongBeat) {
    _particles.removeWhere((p) => p.life <= 0);

    // 更新现有粒子
    for (var p in _particles) {
      // 添加一些水平漂移
      p.vx += (_rng.nextDouble() - 0.5) * 20 * dt;
      p.vx *= 0.98; // 水平阻尼

      p.x += p.vx * dt;
      p.y += p.vy * dt;

      // 重力效果，但强拍时减弱（粒子上升）
      final gravity = isStrongBeat ? 20.0 : 60.0;
      p.vy += gravity * dt;

      // 生命衰减
      p.life -= dt * (isStrongBeat ? 0.6 : 1.0);

      // 大小随生命值变化
      p.size *= (0.99 - (1 - p.life) * 0.02);
    }

    // 计算能量指标
    final avgLevel = _levels.isEmpty
        ? 0.0
        : _levels.reduce((a, b) => a + b) / _levels.length;

    // 计算低频能量（中间区域）
    final midStart = (_barCount * 0.3).round();
    final midEnd = (_barCount * 0.7).round();
    double bassLevel = 0;
    if (midEnd > midStart) {
      for (var i = midStart; i < midEnd; i++) {
        bassLevel += _levels[i];
      }
      bassLevel /= (midEnd - midStart);
    }

    // 根据能量和节拍动态计算生成数量
    int spawnCount = (avgLevel * 3).round();
    if (isStrongBeat) {
      spawnCount += (bassLevel * 12).round(); // 强拍时根据低频能量爆发
    }
    if (_globalEnergy > 0.5) {
      spawnCount += (_globalEnergy * 6).round();
    }

    // 限制粒子总数
    final maxParticles = 200;
    spawnCount = math.min(spawnCount, maxParticles - _particles.length);

    for (var i = 0; i < spawnCount; i++) {
      if (_barCount <= 0) break;

      // 优先从高能量区域生成粒子
      int idx;
      if (isStrongBeat && _rng.nextDouble() < 0.7) {
        // 强拍时从中间（低频区）生成
        idx = midStart + _rng.nextInt(math.max(1, midEnd - midStart));
      } else {
        // 随机位置，但偏向高能量区域
        idx = _rng.nextInt(_barCount);
        // 尝试找到更高能量的位置
        for (var attempt = 0; attempt < 3; attempt++) {
          final newIdx = _rng.nextInt(_barCount);
          if (_levels[newIdx] > _levels[idx]) {
            idx = newIdx;
          }
        }
      }

      final level = _levels[idx];
      final threshold = isStrongBeat ? 0.2 : 0.35;

      if (level > threshold) {
        // 根据节拍强度调整粒子属性
        final energyBoost = isStrongBeat ? 1.5 : 1.0;
        final sizeBoost = isStrongBeat ? 1.3 : 1.0;

        _particles.add(
          _Particle(
            x: idx / _barCount,
            y: 1.0 - level * 0.9,
            vx: (_rng.nextDouble() - 0.5) * 40 * energyBoost,
            vy: -_rng.nextDouble() * 120 * level * energyBoost,
            size: (2 + _rng.nextDouble() * 5 * level) * sizeBoost,
            life: 0.6 + _rng.nextDouble() * 1.0 + (isStrongBeat ? 0.4 : 0),
            hue: _rng.nextDouble(),
          ),
        );
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
    // 在 build 中更新播放状态，而不是在 _tick 中
    final playerProvider = context.watch<PlayerProvider>();
    // 检查是否真正在播放：isPlaying 且有时长且位置在变化
    _updatePlayingState(
      playerProvider.isPlaying,
      playerProvider.position,
      playerProvider.duration,
    );

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
    // 计算能够填满整个高度的行数
    final rows = (size.height / stepY).floor();
    if (rows <= 0) return;

    // 计算垂直偏移，使点阵居中
    final totalHeight = rows * stepY;
    final offsetY = (size.height - totalHeight) / 2;

    var x = 0.0;
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final active = (v * rows).round().clamp(0, rows);

      for (var r = 0; r < rows; r++) {
        final isOn = r < active;
        final t = isOn ? (r / (rows - 1).clamp(1, rows)).clamp(0.0, 1.0) : 0.0;
        paint.color = isOn
            ? (Color.lerp(faintColor, color, 0.35 + 0.65 * t) ?? color)
            : faintColor.withValues(alpha: 0.08);

        final cx = x + colWidth / 2;
        // 从底部开始绘制，填满整个高度
        final cy = size.height - offsetY - (r + 0.5) * stepY;
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
    final amp = size.height * 0.45; // 增大振幅

    final pathTop = Path();
    final pathBottom = Path();

    // 使用三次贝塞尔曲线实现更平滑的波浪
    final points = <Offset>[];
    final pointsBottom = <Offset>[];

    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      final x = dx * i;
      points.add(Offset(x, mid - v * amp));
      pointsBottom.add(Offset(x, mid + v * amp));
    }

    // 绘制上半部分波浪
    pathTop.moveTo(points[0].dx, points[0].dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[0];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2
          ? points[i + 2]
          : points[points.length - 1];

      // Catmull-Rom 样条转三次贝塞尔
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

      pathTop.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    // 绘制下半部分波浪
    pathBottom.moveTo(pointsBottom[0].dx, pointsBottom[0].dy);
    for (var i = 0; i < pointsBottom.length - 1; i++) {
      final p0 = i > 0 ? pointsBottom[i - 1] : pointsBottom[0];
      final p1 = pointsBottom[i];
      final p2 = pointsBottom[i + 1];
      final p3 = i < pointsBottom.length - 2
          ? pointsBottom[i + 2]
          : pointsBottom[pointsBottom.length - 1];

      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

      pathBottom.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    // 渐变填充
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

    // 上半部分填充
    final fillPath = Path()
      ..addPath(pathTop, Offset.zero)
      ..lineTo(size.width, mid)
      ..lineTo(0, mid)
      ..close();

    // 下半部分填充
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

    // 绘制波浪轮廓线
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(pathTop, paint);
    canvas.drawPath(pathBottom, paint);

    // 添加发光效果
    if (enableGlow) {
      paint
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(pathTop, paint);
      canvas.drawPath(pathBottom, paint);
      paint.maskFilter = null;
    }

    // 绘制中线
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.3);
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), paint);
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
    const gap = 2.0;
    final barWidth = ((size.width - gap * (n - 1)) / n).clamp(3.0, 18.0);

    var x = 0.0;
    for (var i = 0; i < n; i++) {
      final v = levels[i].clamp(0.0, 1.0);
      // 限制最大高度，避免遮挡
      final maxH = size.height * 0.85;
      final h = (v * maxH).clamp(4.0, maxH);

      final rect = Rect.fromLTWH(x, size.height - h, barWidth, h);

      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFF4500),
          const Color(0xFFFF6B00),
          const Color(0xFFFFD700),
          const Color(0xFFFFFF00).withValues(alpha: 0.7),
          const Color(0xFFFFFFFF).withValues(alpha: 0.2),
        ],
        stops: const [0.0, 0.35, 0.65, 0.88, 1.0],
      );

      paint
        ..style = PaintingStyle.fill
        ..shader = gradient.createShader(rect);

      final flamePath = Path();
      flamePath.moveTo(x, size.height);
      flamePath.lineTo(x, size.height - h * 0.75);

      final waveOffset =
          math.sin(i * 0.6 + beatIntensity * math.pi * 2) * barWidth * 0.25;
      flamePath.quadraticBezierTo(
        x + barWidth / 2 + waveOffset,
        size.height - h - 2,
        x + barWidth,
        size.height - h * 0.75,
      );

      flamePath.lineTo(x + barWidth, size.height);
      flamePath.close();

      canvas.drawPath(flamePath, paint);
      paint.shader = null;

      x += barWidth + gap;
    }
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
      // 限制最大高度，避免遮挡
      final maxH = size.height * 0.9;
      final h = (v * maxH).clamp(2.0, maxH);

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
          barColor.withValues(alpha: 0.7),
          barColor,
          HSLColor.fromAHSL(1.0, (hue + 30) % 360, 0.8, 0.65).toColor(),
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
