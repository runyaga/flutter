import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Rivet rows along edges with highlight offset toward light source.
///
/// Used for horizontal dividers between panels.
class RivetRowPainter extends CustomPainter {
  RivetRowPainter({
    required this.color,
    required this.rivetColor,
    this.rivetSpacing = 24.0,
    this.rivetRadius = 2.5,
  });

  final Color color;
  final Color rivetColor;
  final double rivetSpacing;
  final double rivetRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // Base line
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color,
    );

    // Rivets along the line
    final rivetCount = (size.width / rivetSpacing).ceil();
    final startOffset = (size.width - (rivetCount - 1) * rivetSpacing) / 2;

    for (var i = 0; i < rivetCount; i++) {
      final x = startOffset + i * rivetSpacing;
      final y = size.height / 2;
      final center = Offset(x, y);

      // Rivet body (dark)
      canvas.drawCircle(
        center,
        rivetRadius,
        Paint()..color = rivetColor,
      );

      // Highlight (top-left, simulating light from upper-left)
      canvas.drawCircle(
        center - const Offset(0.5, 0.5),
        rivetRadius * 0.5,
        Paint()
          ..color = rivetColor.withAlpha(
            math.min((rivetColor.a * 255).round() + 60, 255),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(RivetRowPainter oldDelegate) =>
      color != oldDelegate.color || rivetColor != oldDelegate.rivetColor;
}
