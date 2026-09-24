import 'package:flutter/material.dart';

/// 频谱可视化样式
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

  bool get isHeavy => switch (this) {
    VisualizerStyle.particles ||
    VisualizerStyle.flame ||
    VisualizerStyle.gradient ||
    VisualizerStyle.spectrum3D => true,
    _ => false,
  };

  int recommendedBarCount(double width) {
    final divisor = switch (this) {
      VisualizerStyle.dots => 13.0,
      VisualizerStyle.circular || VisualizerStyle.ring => 12.0,
      VisualizerStyle.particles => 16.0,
      VisualizerStyle.flame => 12.0,
      VisualizerStyle.radar => 16.0,
      VisualizerStyle.gradient => 11.0,
      VisualizerStyle.spectrum3D => 14.0,
      _ => 10.0,
    };
    final maxCount = isHeavy ? 48 : 64;
    return (width / divisor).floor().clamp(20, maxCount);
  }
}
