import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/visualizer_settings_provider.dart';
import '../theme/app_design.dart';
import 'visualizer/particle.dart';
import 'visualizer/spectrum_painter.dart';
import 'visualizer/visualizer_style.dart';
import 'visualizer/visualizer_frame.dart';

export 'visualizer/visualizer_style.dart'
    show VisualizerStyle, VisualizerStyleExtension;

/// 频谱可视化主组件
class VisualizerView extends StatefulWidget {
  const VisualizerView({
    super.key,
    this.showStyleSelector = true,
    this.showStyleLabel = true,
    this.fixedStyle,
    this.enableGlow = true,
    this.showGuides = true,
    this.onStyleChanged,
    this.enabled = true,
    this.maxFps = 30,
  });
  final bool showStyleSelector;

  /// 面板标题已显示样式时，底部只保留运行状态。
  final bool showStyleLabel;
  final VisualizerStyle? fixedStyle;
  final bool enableGlow;
  final bool showGuides;
  final ValueChanged<VisualizerStyle>? onStyleChanged;

  /// 是否启用渲染（不可见时应设为 false 以节省 CPU/内存）
  final bool enabled;

  /// 常规/重型效果的目标刷新率上限。全屏可传更低值减少 GPU 内存压力。
  final int maxFps;

  @override
  State<VisualizerView> createState() => _VisualizerViewState();
}

class _VisualizerViewState extends State<VisualizerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // 固定的紧凑缓冲区。Float32List 比 List<double> 显著减少堆对象与内存占用。
  static const int maxBars = 72;
  static const int maxParticles = 42;
  static const int historyLength = 64;

  final VisualizerFrame _frame = VisualizerFrame(
    maxBars: maxBars,
    historyLength: historyLength,
  );

  int _currentBarCount = 0;
  VisualizerStyle _style = VisualizerStyle.bars;
  bool _isPlaying = false;
  bool _tickerEnabled = true;

  // 优化的粒子系统
  final List<Particle> _particles = [];
  final math.Random _rng = math.Random();
  final _VisualizerRepaintSignal _repaintSignal = _VisualizerRepaintSignal();
  double _waveOffset = 0.0;
  final Stopwatch _frameClock = Stopwatch()..start();
  int _lastFrameMicros = 0;

  @override
  void initState() {
    super.initState();
    // Controller 只提供受 TickerMode 管理的 VSYNC；真正刷新频率在 _tick 中节流。
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _controller.addListener(_tick);
  }

  /// 缓存 PlayerProvider 引用，避免在 _tick 中频繁查找
  PlayerProvider? _playerProvider;

  @override
  void didUpdateWidget(covariant VisualizerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // enabled 状态变化时启停动画
    if (widget.enabled != oldWidget.enabled) {
      _syncAnimation();
    }
  }

  @override
  void deactivate() {
    // widget 从树上移除时暂停动画，防止后台空转
    _setVisualizationConsumer(false);
    _controller.stop();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _syncAnimation();
  }

  @override
  void dispose() {
    _setVisualizationConsumer(false);
    _controller.removeListener(_tick);
    _controller.dispose();
    _repaintSignal.dispose();
    _particles.clear();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final player = _playerProvider ??= context.read<PlayerProvider>();
    final isPlaying = player.isPlaying;
    if (!widget.enabled || !isPlaying || _currentBarCount == 0) {
      if (_controller.isAnimating) _controller.stop();
      return;
    }

    final elapsedMicros = _frameClock.elapsedMicroseconds;
    final currentStyle = widget.fixedStyle ?? _style;
    final settings = context.read<VisualizerSettingsProvider?>();
    final targetFps = settings?.maxFps ?? widget.maxFps;
    final regularInterval = (1000000 / targetFps.clamp(12, 60)).round();
    final heavyInterval = math.max(regularInterval, 33333);
    final intervalMicros = currentStyle.isHeavy
        ? heavyInterval
        : regularInterval;
    if (_lastFrameMicros != 0 &&
        elapsedMicros - _lastFrameMicros < intervalMicros) {
      return;
    }
    final elapsedDelta = _lastFrameMicros == 0
        ? intervalMicros
        : elapsedMicros - _lastFrameMicros;
    _lastFrameMicros = elapsedMicros;
    final dt = (elapsedDelta / 1000000.0).clamp(0.016, 0.1);

    player.sampleVisualizationFrame();
    _frame.signal.process(
      player.fftData,
      isPlaying,
      dt,
      sensitivity: settings?.sensitivity ?? 1,
      smoothing: settings?.smoothing ?? 0.5,
    );
    _frame.processWaveform(
      player.waveformData,
      dt,
      sensitivity: settings?.sensitivity ?? 1,
    );
    _waveOffset += dt * 2.0;
    _frame.phase = _waveOffset;

    if (currentStyle == VisualizerStyle.particles) {
      _updateParticles(dt, _frame.signal.beatIntensity > 0.55);
    } else if (_particles.isNotEmpty) {
      _particles.clear();
    }

    if (_isPlaying && currentStyle == VisualizerStyle.waterfall) {
      _frame.captureHistory(dt, 1);
    }

    _repaintSignal.repaint();
  }

  void _updateParticles(double dt, bool isStrongBeat) {
    // 清理超出范围的粒子
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      if (p.life <= 0 ||
          p.x < -0.15 ||
          p.x > 1.15 ||
          p.y < -0.15 ||
          p.y > 1.15) {
        _particles.removeAt(i);
      }
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
    final bassLevel = _frame.signal.bassEnergy;
    final midLevel = _frame.signal.midEnergy;
    final highLevel = _frame.signal.highEnergy;

    final totalEnergy = bassLevel * 0.4 + midLevel * 0.4 + highLevel * 0.2;

    // 智能粒子生成 — 根据频段生成不同类型的粒子
    if (totalEnergy > 0.12 || isStrongBeat) {
      final spawnCount = isStrongBeat
          ? (totalEnergy * 3).toInt().clamp(1, 3)
          : (totalEnergy * 1.5).toInt().clamp(0, 2);

      final availableSlots = maxParticles - _particles.length;
      final actualSpawnCount = math.min(spawnCount, availableSlots);
      for (var i = 0; i < actualSpawnCount; i++) {
        // 从有能量的频段生成粒子
        final band = _rng.nextDouble();
        int targetIdx;
        double energy;
        double baseHue;

        if (band < 0.3 && bassLevel > 0.15) {
          // 低频 — 大粒子，暖色
          targetIdx = _rng.nextInt(
            (_currentBarCount * 0.2).toInt().clamp(1, _currentBarCount),
          );
          energy = bassLevel;
          baseHue = 0.0; // 红/橙
        } else if (band < 0.7 && midLevel > 0.1) {
          // 中频 — 中粒子，主题色
          final start = (_currentBarCount * 0.2).toInt();
          final range = (_currentBarCount * 0.4).toInt().clamp(
            1,
            _currentBarCount,
          );
          targetIdx = start + _rng.nextInt(range);
          energy = midLevel;
          baseHue = 0.55; // 蓝/紫
        } else if (highLevel > 0.08) {
          // 高频 — 小粒子，冷色
          final start = (_currentBarCount * 0.6).toInt();
          final range = (_currentBarCount * 0.4).toInt().clamp(
            1,
            _currentBarCount,
          );
          targetIdx = start + _rng.nextInt(range);
          energy = highLevel;
          baseHue = 0.75; // 青/绿
        } else {
          continue;
        }

        targetIdx = targetIdx.clamp(0, _currentBarCount - 1);
        final level = _frame.signal.levels[targetIdx];
        if (level < 0.1) continue;

        final spawnX = targetIdx / _currentBarCount;
        final spawnY = 0.85 - level * 0.3; // 从柱顶附近生成
        final sizeBase = band < 0.3 ? 3.5 : (band < 0.7 ? 2.5 : 1.5);
        final energyBoost = isStrongBeat ? 1.6 : 1.0;

        _particles.add(
          Particle(
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
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<VisualizerSettingsProvider?>();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled != tickerEnabled) {
      _tickerEnabled = tickerEnabled;
      _syncAnimation();
    }
    final isPlaying = context.select<PlayerProvider, bool>(
      (provider) => provider.isPlaying,
    );
    if (_isPlaying != isPlaying) {
      _isPlaying = isPlaying;
      _syncAnimation();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        // 限制采样密度，避免宽屏/全屏时成倍增加绘制对象。
        final currentStyle = widget.fixedStyle ?? _style;
        final count = currentStyle.recommendedBarCount(width);

        // 只在数量变化时调整数组
        if (count != _currentBarCount) {
          _currentBarCount = count;
          _frame.signal.setBandCount(count);
          _syncAnimation();
        }

        return SizedBox(
          height: constraints.maxHeight.isFinite ? constraints.maxHeight : 180,
          child: RepaintBoundary(
            child: Stack(
              children: [
                if (isPlaying)
                  Positioned.fill(
                    bottom: 28,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        willChange: true,
                        size: Size.infinite,
                        painter: SpectrumPainter(
                          frame: _frame,
                          repaint: _repaintSignal,
                          levels: _frame.signal.levels,
                          peaks: _frame.signal.peaks,
                          barCount: _currentBarCount,
                          style: currentStyle,
                          color: scheme.primary,
                          secondaryColor: scheme.secondary,
                          tertiaryColor: scheme.tertiary,
                          surfaceColor: scheme.surface,
                          faintColor: scheme.primary.withValues(alpha: 0.18),
                          waveform: _frame.waveform,
                          particles: currentStyle == VisualizerStyle.particles
                              ? _particles
                              : const [],
                          history: currentStyle == VisualizerStyle.waterfall
                              ? _frame.history
                              : const [],
                          historyHead: _frame.historyHead,
                          historyCount: _frame.historyCount,
                          beatIntensity: _frame.signal.beatIntensity,
                          bassEnergy: _frame.signal.bassEnergy,
                          midEnergy: _frame.signal.midEnergy,
                          highEnergy: _frame.signal.highEnergy,
                          phase: _frame.phase,
                          enableGlow: widget.enableGlow,
                          showGuides: widget.showGuides,
                          glowStrength: settings?.glowStrength ?? 1,
                          backgroundOpacity: settings?.backgroundOpacity ?? 0,
                        ),
                      ),
                    ),
                  ),
                if (!isPlaying)
                  Positioned.fill(
                    bottom: 28,
                    child: IgnorePointer(
                      child: _VisualizerIdleState(scheme: scheme),
                    ),
                  ),
                Positioned(
                  left: 2,
                  bottom: 2,
                  child: _VisualizerStatus(
                    style: currentStyle,
                    isPlaying: isPlaying,
                    showStyleLabel: widget.showStyleLabel,
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
                                    Icon(
                                      style == currentStyle
                                          ? Icons.check_rounded
                                          : style.icon,
                                      size: 18,
                                      color: style == currentStyle
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : null,
                                    ),
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

  void _syncAnimation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shouldAnimate =
          widget.enabled &&
          _tickerEnabled &&
          _isPlaying &&
          _currentBarCount > 0;
      _setVisualizationConsumer(shouldAnimate);
      if (shouldAnimate) {
        if (!_controller.isAnimating) _controller.repeat();
      } else {
        if (_controller.isAnimating) _controller.stop();
        _lastFrameMicros = 0;
        _frame.signal.reset();
        _frame.resetHistory();
        _frame.clearWaveform();
        _particles.clear();
        _repaintSignal.repaint();
      }
    });
  }

  void _setVisualizationConsumer(bool active) {
    final player = _playerProvider ??= context.read<PlayerProvider>();
    player.setVisualizationConsumerActive(this, active);
  }
}

class _VisualizerIdleState extends StatelessWidget {
  const _VisualizerIdleState({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final showHeading = constraints.maxHeight >= 170;
      final diameter = math.min(
        112.0,
        math.max(36.0, constraints.maxHeight - (showHeading ? 84 : 44)),
      );
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: diameter,
              child: CustomPaint(
                painter: _IdleRecordPainter(scheme.primary, scheme.surface),
                child: Center(
                  child: Icon(
                    Icons.music_note_rounded,
                    size: diameter * 0.24,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (showHeading) ...[
              Text(
                '让旋律跃动',
                style: context.textStyles.titleLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              '播放音乐后显示频谱',
              style: context.textStyles.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// 静态唱片插画：待机时不伪造音频，也不持续驱动动画。
class _IdleRecordPainter extends CustomPainter {
  _IdleRecordPainter(this.color, this.surface);
  final Color color;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.43;
    final accent = HSLColor.fromColor(color);
    final companion = accent.withHue((accent.hue + 65) % 360).toColor();
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.24),
          surface.withValues(alpha: 0.75),
          companion.withValues(alpha: 0.16),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius, paint);
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final ratio in const [0.38, 0.57, 0.72, 0.85, 1.0]) {
      paint.color = color.withValues(alpha: ratio == 1.0 ? 0.36 : 0.15);
      canvas.drawCircle(center, radius * ratio, paint);
    }
    paint
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color, companion, color],
      ).createShader(Offset.zero & size);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 1.12),
      -math.pi * 0.85,
      math.pi * 0.55,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 1.12),
      math.pi * 0.15,
      math.pi * 0.55,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _IdleRecordPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.surface != surface;
}

class _VisualizerStatus extends StatelessWidget {
  const _VisualizerStatus({
    required this.style,
    required this.isPlaying,
    required this.showStyleLabel,
  });

  final VisualizerStyle style;
  final bool isPlaying;
  final bool showStyleLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final visual = context.visual;
    final active = isPlaying && TickerMode.valuesOf(context).enabled;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: visual.panelMuted.withValues(alpha: context.isDark ? 0.45 : 0.6),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: visual.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showStyleLabel) ...[
            Icon(style.icon, size: 14, color: scheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              style.displayName,
              style: context.textStyles.labelSmall?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? scheme.primary : scheme.outline,
              boxShadow: active
                  ? AppShadows.glow(scheme.primary, alpha: 0.5)
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            active ? '实时' : '待机',
            style: context.textStyles.labelSmall?.copyWith(
              fontSize: AppTypeScale.micro,
              color: active ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualizerRepaintSignal extends ChangeNotifier {
  void repaint() => notifyListeners();
}
