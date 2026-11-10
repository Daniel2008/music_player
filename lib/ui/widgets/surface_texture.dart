import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum SurfaceTextureKind { grain, woven, brushed }

/// 独立重绘的静态材质层，不监听播放进度或频谱帧。
class TexturedSurface extends StatelessWidget {
  const TexturedSurface({super.key, required this.child, required this.kind});

  final Widget child;
  final SurfaceTextureKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                painter: _SurfaceTexturePainter(
                  kind: kind,
                  color: scheme.onSurface.withValues(
                    alpha: dark ? 0.055 : 0.04,
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _SurfaceTexturePainter extends CustomPainter {
  _SurfaceTexturePainter({required this.kind, required this.color});

  final SurfaceTextureKind kind;
  final Color color;
  Size? _cachedSize;
  Float32List? _grain;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.7;
    switch (kind) {
      case SurfaceTextureKind.grain:
        if (_cachedSize != size) {
          _cachedSize = size;
          final columns = (size.width / 7).ceil();
          final rows = (size.height / 7).ceil();
          _grain = Float32List(columns * rows * 2);
          var seed = 37;
          for (var y = 0; y < rows; y++) {
            for (var x = 0; x < columns; x++) {
              seed = (seed * 1664525 + 1013904223) & 0x7fffffff;
              final index = (y * columns + x) * 2;
              _grain![index] = x * 7 + (seed % 61) / 10;
              _grain![index + 1] = y * 7 + ((seed ~/ 61) % 61) / 10;
            }
          }
        }
        paint
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawRawPoints(ui.PointMode.points, _grain!, paint);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6;
        for (var i = 0; i < 7; i++) {
          canvas.drawCircle(
            Offset(size.width * 0.93, -size.height * 0.12),
            size.width * 0.20 + i * 18,
            paint,
          );
        }
      case SurfaceTextureKind.woven:
        final path = Path();
        for (var x = -size.height; x < size.width; x += 12) {
          path
            ..moveTo(x, 0)
            ..lineTo(x + size.height, size.height);
        }
        for (var x = 0.0; x < size.width + size.height; x += 12) {
          path
            ..moveTo(x, 0)
            ..lineTo(x - size.height, size.height);
        }
        paint
          ..style = PaintingStyle.stroke
          ..color = color.withValues(alpha: color.a * 0.6);
        canvas.drawPath(path, paint);
      case SurfaceTextureKind.brushed:
        final path = Path();
        for (var y = 2.0; y < size.height; y += 4) {
          final inset = (y * 13) % 37;
          path
            ..moveTo(inset, y)
            ..lineTo(size.width - inset, y);
        }
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;
        canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SurfaceTexturePainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
