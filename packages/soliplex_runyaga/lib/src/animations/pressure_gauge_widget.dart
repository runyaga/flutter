import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../painters/pressure_gauge_painter.dart';

/// Animated pressure gauge with spring-driven needle.
///
/// The needle slams to [targetValue] using a spring simulation
/// (stiffness 500, damping 0.3) and bounces realistically.
class PressureGaugeWidget extends StatefulWidget {
  const PressureGaugeWidget({
    required this.targetValue,
    this.size = 60.0,
    super.key,
  });

  final double targetValue;
  final double size;

  @override
  State<PressureGaugeWidget> createState() => _PressureGaugeWidgetState();
}

class _PressureGaugeWidgetState extends State<PressureGaugeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _currentValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _animateTo(widget.targetValue);
  }

  @override
  void didUpdateWidget(PressureGaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetValue != oldWidget.targetValue) {
      _animateTo(widget.targetValue);
    }
  }

  void _animateTo(double target) {
    _controller.stop();

    const spring = SpringDescription(
      mass: 1.0,
      stiffness: 500.0,
      damping: 8.0, // Underdamped for bounce
    );

    final simulation = SpringSimulation(spring, _currentValue, target, 0.0);

    _animation = _controller.drive(
      Tween<double>(begin: _currentValue, end: target),
    );

    _controller.animateWith(simulation).whenComplete(() {
      _currentValue = target;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: PressureGaugePainter(
            value: _animation.value.clamp(0.0, 1.0),
          ),
        );
      },
    );
  }
}
