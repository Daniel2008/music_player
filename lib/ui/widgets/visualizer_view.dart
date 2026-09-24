import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import 'visualizer/particle.dart';
import 'visualizer/spectrum_painter.dart';
import 'visualizer/visualizer_style.dart';

export 'visualizer/visualizer_style.dart'
    show VisualizerStyle, VisualizerStyleExtension;

/// 频谱可视化主组件
class VisualizerView extends StatefulWidget {
  const VisualizerView({
    super.key,
    this.showStyleSelector = true,
    this.fixedStyle,
    this.enableGlow = true,
    this.onStyleChanged,
    this.enabled = true,
    this.maxFps = 30,
  });
  final bool showStyleSelector;
  final VisualizerStyle? fixedStyle;
  final bool enableGlow;
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
  static const int historyLength = 5;

  final Float32List _levels = Float32List(maxBars);
  final Float32List _targets = Float32List(maxBars);
  final Float32List _peaks = Float32List(maxBars);
  final List<List<double>> _history = List.generate(
    historyLength,
    (_) => Float32List(maxBars),
  );
  final Int32List _bandStarts = Int32List(maxBars);
  final Int32List _bandEnds = Int32List(maxBars);
  int _mappedFftLength = 0;
  int _mappedBarCount = 0;
  int _historyHead = 0; // 环形缓冲区头指针

  int _currentBarCount = 0;
  VisualizerStyle _style = VisualizerStyle.bars;
  bool _isPlaying = false;
  bool _tickerEnabled = true;
  double _beatIntensity = 0.0;

  // 优化的粒子系统
  final List<Particle> _particles = [];
  final math.Random _rng = math.Random();
  final _VisualizerRepaintSignal _repaintSignal = _VisualizerRepaintSignal();
  double _waveOffset = 0.0;
  final Stopwatch _frameClock = Stopwatch()..start();
  int _lastFrameMicros = 0;
  int _historyFrame = 0;

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

  void _ensureBandMapping(int fftLength) {
    if (_mappedFftLength == fftLength && _mappedBarCount == _currentBarCount) {
      return;
    }
    _mappedFftLength = fftLength;
    _mappedBarCount = _currentBarCount;
    final usableLength = math.max(1, fftLength);
    for (var i = 0; i < _currentBarCount; i++) {
      final start = (math.pow(i / _currentBarCount, 1.5) * usableLength)
          .toInt()
          .clamp(0, fftLength - 1);
      final end = (math.pow((i + 1) / _currentBarCount, 1.5) * usableLength)
          .toInt()
          .clamp(start + 1, fftLength);
      _bandStarts[i] = start;
      _bandEnds[i] = end;
    }
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
    _ensureBandMapping(fftLength);
    // 频段边界仅在尺寸变化时计算，热循环中不再执行 pow/toInt。
    for (var i = 0; i < _currentBarCount; i++) {
      final start = _bandStarts[i];
      final end = _bandEnds[i];

      // 计算区间峰值（比均值更灵敏）
      double peak = 0.0;
      for (var j = start; j < end && j < fftLength; j++) {
        if (fftData[j] > peak) peak = fftData[j];
      }

      // 使用曲线压缩：低音量敏感，高音量压缩
      // pow(x, 0.6) 比 sqrt 更激进，让小信号也可见
      final compressed = math
          .pow(peak.clamp(0.0, 2.0) / 2.0, 0.55)
          .clamp(0.0, 1.0);

      // 频率补偿：高频自然衰减，给低频柱稍微衰减以避免低音压制
      final freqWeight = 0.7 + 0.3 * (i / _currentBarCount);
      _targets[i] = compressed * freqWeight * 0.95;
    }

    // 改进的节拍检测 — 使用低频能量突变
    double bassEnergy = 0.0;
    final bassEnd = math.min(
      (_currentBarCount * 0.15).toInt().clamp(1, 20),
      _currentBarCount,
    );
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
    if (!mounted || !widget.enabled || !_isPlaying || _currentBarCount == 0) {
      if (_controller.isAnimating) _controller.stop();
      return;
    }

    final elapsedMicros = _frameClock.elapsedMicroseconds;
    final currentStyle = widget.fixedStyle ?? _style;
    final player = _playerProvider ??= context.read<PlayerProvider>();
    final isPlaying = player.isPlaying;
    final regularInterval = (1000000 / widget.maxFps.clamp(12, 60)).round();
    final heavyInterval = math.max(regularInterval, 41667);
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

    _updateFromFFT(player.fftData, isPlaying);
    _waveOffset += dt * 2.0;

    if (currentStyle == VisualizerStyle.particles) {
      _updateParticles(dt, _beatIntensity > 0.55);
    } else if (_particles.isNotEmpty) {
      _particles.clear();
    }

    const fallSpeed = 0.18;
    const riseSpeed = 0.7;
    final needsPeaks =
        currentStyle == VisualizerStyle.bars ||
        currentStyle == VisualizerStyle.mirroredBars;

    for (var i = 0; i < _currentBarCount; i++) {
      final diff = _targets[i] - _levels[i];
      _levels[i] = (_levels[i] + diff * (diff > 0 ? riseSpeed : fallSpeed))
          .clamp(0.0, 1.0);
      if (needsPeaks) {
        if (_levels[i] > _peaks[i]) {
          _peaks[i] = _levels[i];
        } else {
          _peaks[i] *= 0.965;
        }
      } else {
        _peaks[i] = 0;
      }
    }

    // 只有 3D 样式需要历史帧，并降为隔帧写入。
    if (_isPlaying && currentStyle == VisualizerStyle.spectrum3D) {
      _historyFrame++;
      if (_historyFrame.isEven) {
        _history[_historyHead].setRange(0, _currentBarCount, _levels);
        _historyHead = (_historyHead + 1) % historyLength;
      }
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
    double bassLevel = 0, midLevel = 0, highLevel = 0;
    if (_currentBarCount > 0) {
      final bassEnd = (_currentBarCount * 0.2).toInt().clamp(
        1,
        _currentBarCount,
      );
      final midEnd = (_currentBarCount * 0.6).toInt().clamp(
        1,
        _currentBarCount,
      );
      for (var i = 0; i < bassEnd; i++) {
        bassLevel += _levels[i];
      }
      bassLevel /= bassEnd;
      for (var i = bassEnd; i < midEnd; i++) {
        midLevel += _levels[i];
      }
      midLevel /= (midEnd - bassEnd).clamp(1, 999);
      for (var i = midEnd; i < _currentBarCount; i++) {
        highLevel += _levels[i];
      }
      highLevel /= (_currentBarCount - midEnd).clamp(1, 999);
    }

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
        final level = _levels[targetIdx];
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
        }

        return SizedBox(
          height: constraints.maxHeight.isFinite ? constraints.maxHeight : 180,
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: SpectrumPainter(
                      repaint: _repaintSignal,
                      levels: _levels,
                      peaks: _peaks,
                      barCount: _currentBarCount,
                      style: currentStyle,
                      color: scheme.primary,
                      secondaryColor: scheme.secondary,
                      tertiaryColor: scheme.tertiary,
                      faintColor: scheme.primary.withValues(alpha: 0.18),
                      particles: currentStyle == VisualizerStyle.particles
                          ? _particles
                          : const [],
                      history: currentStyle == VisualizerStyle.spectrum3D
                          ? _history
                          : const [],
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
        _repaintSignal.repaint();
      }
    });
  }

  void _setVisualizationConsumer(bool active) {
    final player = _playerProvider ??= context.read<PlayerProvider>();
    player.setVisualizationConsumerActive(this, active);
  }
}

class _VisualizerRepaintSignal extends ChangeNotifier {
  void repaint() => notifyListeners();
}
