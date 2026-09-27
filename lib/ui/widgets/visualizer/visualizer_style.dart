import 'package:flutter/material.dart';

/// 频谱可视化样式
enum VisualizerStyle {
  bars,
  mirroredBars,
  dots,
  wave,
  particles,
  flame,
  waterfall,
  vinyl,
}

extension VisualizerStyleExtension on VisualizerStyle {
  String get displayName {
    switch (this) {
      case VisualizerStyle.bars:
        return '霓虹柱';
      case VisualizerStyle.mirroredBars:
        return '镜像霓虹';
      case VisualizerStyle.dots:
        return '点阵';
      case VisualizerStyle.wave:
        return '波浪';
      case VisualizerStyle.particles:
        return '粒子';
      case VisualizerStyle.flame:
        return '火焰';
      case VisualizerStyle.waterfall:
        return '瀑布谱';
      case VisualizerStyle.vinyl:
        return '唱片环';
    }
  }

  IconData get icon {
    switch (this) {
      case VisualizerStyle.bars:
        return Icons.bar_chart;
      case VisualizerStyle.mirroredBars:
        return Icons.align_vertical_center;
      case VisualizerStyle.dots:
        return Icons.grain;
      case VisualizerStyle.wave:
        return Icons.waves;
      case VisualizerStyle.particles:
        return Icons.bubble_chart;
      case VisualizerStyle.flame:
        return Icons.local_fire_department;
      case VisualizerStyle.waterfall:
        return Icons.waterfall_chart_rounded;
      case VisualizerStyle.vinyl:
        return Icons.album_rounded;
    }
  }

  bool get isHeavy => switch (this) {
    VisualizerStyle.particles ||
    VisualizerStyle.flame ||
    VisualizerStyle.waterfall => true,
    _ => false,
  };

  bool get isFeatured => switch (this) {
    VisualizerStyle.bars ||
    VisualizerStyle.mirroredBars ||
    VisualizerStyle.wave ||
    VisualizerStyle.vinyl => true,
    _ => false,
  };

  int recommendedBarCount(double width) {
    final divisor = switch (this) {
      VisualizerStyle.dots => 13.0,
      VisualizerStyle.particles => 16.0,
      VisualizerStyle.flame => 12.0,
      VisualizerStyle.waterfall => 15.0,
      VisualizerStyle.vinyl => 12.0,
      _ => 10.0,
    };
    final maxCount = isHeavy ? 48 : 64;
    return (width / divisor).floor().clamp(20, maxCount);
  }
}
