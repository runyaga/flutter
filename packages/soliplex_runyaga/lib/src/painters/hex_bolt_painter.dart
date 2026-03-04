import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hexagonal bolt head with 3D bevel — used in panel corners.
class HexBoltPainter extends CustomPainter {
  HexBoltPainter({
    required this.color,
    required this.highlightColor,
  });

  final Color color;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Outer hex
    _drawHex(canvas, center, radius, Paint()..color = color);

    // Inner highlight (top-left bias for 3D effect)
    _drawHex(
      canvas,
      center - const Offset(0.5, 0.5),
      radius * 0.7,
      Paint()..color = highlightColor,
    );

    // Center socket (dark)
    _drawHex(
      canvas,
      center,
      radius * 0.35,
      Paint()..color = color.withAlpha(200),
    );
  }

  void _drawHex(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(HexBoltPainter oldDelegate) =>
      color != oldDelegate.color ||
      highlightColor != oldDelegate.highlightColor;
}
