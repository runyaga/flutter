import 'package:flutter/material.dart';

import '../design/tokens/colors.dart';

/// Furnace pulse heartbeat — bottom glow that oscillates.
///
/// Normal: 2s period. During streaming: quickens to 0.5s.
class FurnacePulse extends StatefulWidget {
  const FurnacePulse({
    required this.isStreaming,
    this.height = 4.0,
    super.key,
  });

  final bool isStreaming;
  final double height;

  @override
  State<FurnacePulse> createState() => _FurnacePulseState();
}

class _FurnacePulseState extends State<FurnacePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.isStreaming
          ? const Duration(milliseconds: 500)
          : const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(FurnacePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStreaming != oldWidget.isStreaming) {
      _controller.duration = widget.isStreaming
          ? const Duration(milliseconds: 500)
          : const Duration(seconds: 2);
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                BoilerColors.furnaceRed.withAlpha(0),
                BoilerColors.furnaceOrange.withAlpha(
                  (80 * _controller.value).round(),
                ),
                BoilerColors.furnaceRed.withAlpha(
                  (120 * _controller.value).round(),
                ),
                BoilerColors.furnaceOrange.withAlpha(
                  (80 * _controller.value).round(),
                ),
                BoilerColors.furnaceRed.withAlpha(0),
              ],
            ),
          ),
        );
      },
    );
  }
}
