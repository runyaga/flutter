import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens/colors.dart';

/// Full circular pressure gauge with tick marks, colored zones,
/// and animated needle.
///
/// [value] ranges from 0.0 (minimum) to 1.0 (maximum/redline).
class PressureGaugePainter extends CustomPainter {
  PressureGaugePainter({
    required this.value,
    this.backgroundColor = BoilerColors.codeBackground,
    this.rimColor = BoilerColors.iron,
    this.needleColor = BoilerColors.furnaceRed,
    this.tickColor = BoilerColors.steamMuted,
  });

  final double value;
  final Color backgroundColor;
  final Color rimColor;
  final Color needleColor;
  final Color tickColor;

  static const _startAngle = math.pi * 0.75; // 135 degrees
  static const _sweepAngle = math.pi * 1.5; // 270 degrees
  static const _tickCount = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // ── Background circle ──
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = backgroundColor,
    );

    // ── Rim ──
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = rimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // ── Colored arc zones ──
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Green zone (0-60%)
    arcPaint.color = BoilerColors.pipeGreen;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      _startAngle,
      _sweepAngle * 0.6,
      false,
      arcPaint,
    );

    // Amber zone (60-80%)
    arcPaint.color = BoilerColors.gaugeAmber;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      _startAngle + _sweepAngle * 0.6,
      _sweepAngle * 0.2,
      false,
      arcPaint,
    );

    // Red zone (80-100%)
    arcPaint.color = BoilerColors.furnaceRed;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      _startAngle + _sweepAngle * 0.8,
      _sweepAngle * 0.2,
      false,
      arcPaint,
    );

    // ── Tick marks ──
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1;

    for (var i = 0; i <= _tickCount; i++) {
      final angle = _startAngle + (_sweepAngle * i / _tickCount);
      final isMajor = i % 5 == 0;
      final innerRadius = radius - (isMajor ? 14 : 10);
      final outerRadius = radius - 3;

      canvas.drawLine(
        Offset(
          center.dx + innerRadius * math.cos(angle),
          center.dy + innerRadius * math.sin(angle),
        ),
        Offset(
          center.dx + outerRadius * math.cos(angle),
          center.dy + outerRadius * math.sin(angle),
        ),
        tickPaint..strokeWidth = (isMajor ? 1.5 : 0.8),
      );
    }

    // ── Needle ──
    final needleAngle = _startAngle + (_sweepAngle * value.clamp(0.0, 1.0));
    final needleLength = radius * 0.7;

    canvas.drawLine(
      center,
      Offset(
        center.dx + needleLength * math.cos(needleAngle),
        center.dy + needleLength * math.sin(needleAngle),
      ),
      Paint()
        ..color = needleColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // ── Center cap ──
    canvas.drawCircle(center, 3, Paint()..color = needleColor);
    canvas.drawCircle(
      center,
      2,
      Paint()..color = BoilerColors.steamWhite,
    );
  }

  @override
  bool shouldRepaint(PressureGaugePainter oldDelegate) =>
      value != oldDelegate.value;
}
