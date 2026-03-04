import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brushed steel texture — horizontal lines with random opacity.
///
/// Creates the industrial steel plate background effect used across
/// panels and the title bar.
class SteelPlatePainter extends CustomPainter {
  SteelPlatePainter({
    required this.color,
    this.lineSpacing = 3.0,
    this.lineOpacityRange = 0.08,
  });

  final Color color;
  final double lineSpacing;
  final double lineOpacityRange;

  @override
  void paint(Canvas canvas, Size size) {
    // Base fill
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color,
    );

    // Brushed steel lines
    final rng = math.Random(42); // Deterministic for consistency
    final linePaint = Paint()..strokeWidth = 0.5;

    for (double y = 0; y < size.height; y += lineSpacing) {
      final opacity = rng.nextDouble() * lineOpacityRange;
      linePaint.color = Colors.white.withAlpha((opacity * 255).round());
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(SteelPlatePainter oldDelegate) =>
      color != oldDelegate.color;
}
