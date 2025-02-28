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
  circularWave,
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
  
  // 添加颜色方案相关变量
  int _colorSchemeIndex = 0;
  final List<List<Color>> _colorSchemes = [
    [Colors.blue.shade400, Colors.blue.shade200],
    [Colors.purple.shade400, Colors.purple.shade200],
    [Colors.green.shade400, Colors.green.shade200],
    [Colors.orange.shade400, Colors.orange.shade200],
  ];
  List<Color> get _currentColorScheme => _colorSchemes[_colorSchemeIndex];

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
              case VisualizerStyle.circularWave:
                _updateCircularWave(); // 使用圆形波浪更新方法
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
  
  // 添加圆形波浪更新方法
  void _updateCircularWave() {
    _phase += 0.1;
    for (int i = 0; i < _spectrumHeights.length; i++) {
      double angle = 2 * pi * i / _spectrumHeights.length;
      double value = 0.5 + 0.3 * sin(angle * 3 + _phase) * (1 + 0.2 * sin(angle * 7 - _phase * 1.2));
      _spectrumHeights[i] = value.clamp(0.0, 1.0);
      
      // 更新峰值
      if (_spectrumHeights[i] > _peakHeights[i]) {
        _peakHeights[i] = _spectrumHeights[i] * 1.1;
      } else {
        _peakHeights[i] = max(0.0, _peakHeights[i] - peakDecayRate * 0.5);
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
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (_currentStyle == VisualizerStyle.waveLine) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: WaveLineVisualizerPainter(
                    heights: _spectrumHeights,
                    peakHeights: _peakHeights,
                    colorScheme: _currentColorScheme,
                  ),
                );
              } else if (_currentStyle == VisualizerStyle.circularWave) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: CircularWaveVisualizerPainter(
                    heights: _spectrumHeights,
                    peakHeights: _peakHeights,
                    colorScheme: _currentColorScheme,
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
                              colors: _currentColorScheme,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.color_lens,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _colorSchemeIndex = (_colorSchemeIndex + 1) % _colorSchemes.length;
                  });
                },
                tooltip: '切换颜色',
              ),
              IconButton(
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
                        _currentStyle = VisualizerStyle.circularWave;
                        break;
                      case VisualizerStyle.circularWave:
                        _currentStyle = VisualizerStyle.bars;
                        break;
                    }
                  });
                },
                tooltip: '切换频谱样式',
              ),
            ],
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
      case VisualizerStyle.circularWave:
        return Icons.radio_button_checked;
    }
    // 默认返回值，虽然在当前枚举处理完整的情况下不会执行到这里
    // 但是添加默认返回值可以避免编译错误
    return Icons.music_note;
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
  final List<Color> colorScheme;

  WaveLineVisualizerPainter({
    required this.heights, 
    required this.peakHeights,
    required this.colorScheme
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // 创建蓝色渐变
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        colorScheme[0],
        colorScheme[1],
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
      ..color = colorScheme[1]
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

class CircularWaveVisualizerPainter extends CustomPainter {
  final List<double> heights;
  final List<double> peakHeights;
  final List<Color> colorScheme;

  CircularWaveVisualizerPainter({
    required this.heights, 
    required this.peakHeights,
    required this.colorScheme
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.4;
    
    // 创建渐变
    final gradient = RadialGradient(
      colors: [
        colorScheme[1],
        colorScheme[0],
      ],
    );
    
    // 绘制圆形波浪
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // 绘制多个波浪圆
    for (int j = 0; j < 3; j++) {
      final path = Path();
      final waveRadius = radius * (0.6 + j * 0.2);
      
      // 设置波浪圆的颜色
      wavePaint.color = Color.lerp(colorScheme[0], colorScheme[1], j / 2) ?? colorScheme[0];
      
      path.moveTo(
        center.dx + waveRadius * cos(0),
        center.dy + waveRadius * sin(0)
      );
      
      for (int i = 1; i <= heights.length; i++) {
        final angle = 2 * pi * i / heights.length;
        final waveHeight = heights[i % heights.length] * radius * 0.2;
        final r = waveRadius + waveHeight;
        
        path.lineTo(
          center.dx + r * cos(angle),
          center.dy + r * sin(angle)
        );
      }
      
      canvas.drawPath(path, wavePaint);
    }
    
    // 绘制中心圆
    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = gradient.createShader(Rect.fromCircle(
        center: center,
        radius: radius * 0.5,
      ));
    
    canvas.drawCircle(center, radius * 0.5, centerPaint);
    
    // 绘制峰值点
    final peakPaint = Paint()
      ..color = colorScheme[1]
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < peakHeights.length; i += 5) {
      final angle = 2 * pi * i / peakHeights.length;
      final peakHeight = peakHeights[i] * radius * 0.3;
      final r = radius + peakHeight;
      
      canvas.drawCircle(
        Offset(
          center.dx + r * cos(angle),
          center.dy + r * sin(angle)
        ),
        2.0,
        peakPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
