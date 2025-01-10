import 'dart:math';
import 'package:flutter/material.dart';

class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;

  const AudioVisualizer({
    Key? key,
    required this.isPlaying,
  }) : super(key: key);

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

enum VisualizerStyle {
  bars,
  wave,
  waveLine,
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _barHeights = List.filled(60, 0.0);
  final List<double> _targetHeights = List.filled(60, 0.0);
  final Random _random = Random();
  static const double decayRate = 0.15;
  VisualizerStyle _currentStyle = VisualizerStyle.waveLine;
  double _phase = 0.0;
  final List<double> _spectrumHeights = List.filled(100, 0.0);
  final List<double> _peakHeights = List.filled(100, 0.0);
  static const double spectrumDecayRate = 0.05;
  static const double peakDecayRate = 0.01;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(() {
        if (widget.isPlaying) {
          setState(() {
            switch (_currentStyle) {
              case VisualizerStyle.bars:
                _updateBars();
                break;
              case VisualizerStyle.wave:
                _updateWave();
                break;
              case VisualizerStyle.waveLine:
                _updateSpectrum();
                break;
            }
          });
        }
      });
    _controller.repeat();
  }

  void _updateBars() {
    for (int i = 0; i < _barHeights.length; i++) {
      if (_random.nextBool()) {
        _targetHeights[i] = _random.nextDouble() * 0.5;
      }
      _barHeights[i] += (_targetHeights[i] - _barHeights[i]) * decayRate;
    }
  }

  void _updateWave() {
    _phase += 0.1;
    for (int i = 0; i < _barHeights.length; i++) {
      double x = i / _barHeights.length;
      _barHeights[i] = 0.3 +
          0.2 *
              sin(x * 2 * pi + _phase) *
              (1 + 0.3 * sin(x * 4 * pi - _phase * 1.5));
    }
  }

  void _updateSpectrum() {
    for (int i = 0; i < _spectrumHeights.length; i++) {
      if (_random.nextDouble() < 0.2) {
        // 基础随机高度范围
        double targetHeight = _random.nextDouble() * 1.4 + 0.2;

        // 根据位置调整频率响应
        double multiplier = 1.0;
        double position = i / _spectrumHeights.length;

        // 低频段 (0-30%)
        if (position < 0.3) {
          multiplier = 1.2 + position * 0.9;
        }
        // 中频段 (30-70%)
        else if (position < 0.7) {
          multiplier = 1.5;
        }
        // 高频段 (70-100%)
        else {
          multiplier = 1.5 - (position - 0.7) * 0.6;
        }

        // 安全的值计算
        double currentHeight = _spectrumHeights[i].clamp(0.0, 2.0);
        double targetValue = (targetHeight * multiplier).clamp(0.0, 2.0);
        double diff = (targetValue - currentHeight).clamp(-1.0, 1.0);

        // 使用更安全的线性插值
        double change = diff * spectrumDecayRate;
        double newHeight = (currentHeight + change).clamp(0.0, 2.0);

        // 确保结果是有效数字
        _spectrumHeights[i] = newHeight.isFinite ? newHeight : 0.0;
      } else {
        // 安全的衰减计算
        double currentHeight = _spectrumHeights[i].clamp(0.0, 2.0);
        double newHeight = max(0.0, currentHeight - spectrumDecayRate * 0.3);
        _spectrumHeights[i] = newHeight.isFinite ? newHeight : 0.0;
      }

      // 安全的峰值更新
      if (_spectrumHeights[i] > _peakHeights[i]) {
        double peakMultiplier = 1.1 + _random.nextDouble() * 0.25;
        double newPeakHeight =
            (_spectrumHeights[i] * peakMultiplier).clamp(0.0, 2.0);
        _peakHeights[i] =
            newPeakHeight.isFinite ? newPeakHeight : _spectrumHeights[i];
      } else {
        double currentPeakHeight = _peakHeights[i].clamp(0.0, 2.0);
        double newPeakHeight =
            max(0.0, currentPeakHeight - peakDecayRate * 0.8);
        _peakHeights[i] = newPeakHeight.isFinite ? newPeakHeight : 0.0;
      }
    }
  }

  double sign(double x) {
    if (x > 0) return 1;
    if (x < 0) return -1;
    return 0;
  }

  double abs(double x) {
    return x < 0 ? -x : x;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (_currentStyle == VisualizerStyle.waveLine) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: WaveLineVisualizerPainter(
                    heights: _spectrumHeights,
                    peakHeights: _peakHeights,
                  ),
                );
              }

              final barWidth =
                  (constraints.maxWidth - (_barHeights.length - 1) * 4) /
                      _barHeights.length;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  _barHeights.length,
                  (index) => Container(
                    width: barWidth,
                    height: constraints.maxHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: (constraints.maxHeight * 0.9) *
                              _barHeights[index] *
                              (widget.isPlaying ? 1 : 0.1),
                          width: barWidth,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade200,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(barWidth / 2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: Icon(
              _getVisualizerIcon(),
              color: Colors.white70,
            ),
            onPressed: () {
              setState(() {
                switch (_currentStyle) {
                  case VisualizerStyle.bars:
                    _currentStyle = VisualizerStyle.wave;
                    break;
                  case VisualizerStyle.wave:
                    _currentStyle = VisualizerStyle.waveLine;
                    break;
                  case VisualizerStyle.waveLine:
                    _currentStyle = VisualizerStyle.bars;
                    break;
                }
              });
            },
            tooltip: '切换频谱样式',
          ),
        ),
      ],
    );
  }

  IconData _getVisualizerIcon() {
    switch (_currentStyle) {
      case VisualizerStyle.bars:
        return Icons.bar_chart;
      case VisualizerStyle.wave:
        return Icons.waves;
      case VisualizerStyle.waveLine:
        return Icons.show_chart;
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying) {
      _controller.repeat();
    } else {
      _controller.stop();
      setState(() {
        for (int i = 0; i < _barHeights.length; i++) {
          _targetHeights[i] = 0.0;
          _barHeights[i] = 0.0;
        }
        _spectrumHeights.fillRange(0, _spectrumHeights.length, 0.0);
        _peakHeights.fillRange(0, _peakHeights.length, 0.0);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class WaveLineVisualizerPainter extends CustomPainter {
  final List<double> heights;
  final List<double> peakHeights;

  WaveLineVisualizerPainter({required this.heights, required this.peakHeights});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // 创建蓝色渐变
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.blue.shade300,
        Colors.blue.shade600,
      ],
    );

    // 上半部分频谱
    Path path = Path();
    path.moveTo(0, size.height / 2);

    for (int i = 0; i < heights.length; i++) {
      double x = size.width * i / heights.length;
      double y = size.height / 2 - heights[i] * size.height / 2;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height / 2);
    path.close();

    // 应用渐变到上半部分
    paint.shader = gradient.createShader(Rect.fromLTRB(
      0,
      0,
      size.width,
      size.height / 2,
    ));
    canvas.drawPath(path, paint);

    // 下半部分镜像频谱
    Path mirrorPath = Path();
    mirrorPath.moveTo(0, size.height / 2);

    for (int i = 0; i < heights.length; i++) {
      double x = size.width * i / heights.length;
      double y = size.height / 2 + heights[i] * size.height / 2;
      mirrorPath.lineTo(x, y);
    }
    mirrorPath.lineTo(size.width, size.height / 2);
    mirrorPath.close();

    // 应用渐变到下半部分（颜色顺序相反）
    paint.shader = gradient.createShader(Rect.fromLTRB(
      0,
      size.height / 2,
      size.width,
      size.height,
    ));
    canvas.drawPath(mirrorPath, paint);

    // 绘制峰值线
    final peakPaint = Paint()
      ..color = Colors.blue.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 上半部分峰值线
    Path peakPath = Path();
    peakPath.moveTo(0, size.height / 2 - peakHeights[0] * size.height / 2);

    for (int i = 1; i < peakHeights.length; i++) {
      double x = size.width * i / peakHeights.length;
      double y = size.height / 2 - peakHeights[i] * size.height / 2;
      peakPath.lineTo(x, y);
    }
    canvas.drawPath(peakPath, peakPaint);

    // 下半部分镜像峰值线
    Path mirrorPeakPath = Path();
    mirrorPeakPath.moveTo(
        0, size.height / 2 + peakHeights[0] * size.height / 2);

    for (int i = 1; i < peakHeights.length; i++) {
      double x = size.width * i / peakHeights.length;
      double y = size.height / 2 + peakHeights[i] * size.height / 2;
      mirrorPeakPath.lineTo(x, y);
    }
    canvas.drawPath(mirrorPeakPath, peakPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
