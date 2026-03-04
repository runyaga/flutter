import 'package:flutter/material.dart';

/// Staggered scale+bounce animation for rivets on server connect.
///
/// Each child is animated with a staggered delay, creating a
/// "popping" effect along a row.
class RivetPopAnimation extends StatefulWidget {
  const RivetPopAnimation({
    required this.child,
    required this.index,
    required this.isConnected,
    this.totalCount = 5,
    super.key,
  });

  final Widget child;
  final int index;
  final bool isConnected;
  final int totalCount;

  @override
  State<RivetPopAnimation> createState() => _RivetPopAnimationState();
}

class _RivetPopAnimationState extends State<RivetPopAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final delay = widget.index / widget.totalCount;
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(delay, 1.0),
      ),
    );

    if (widget.isConnected) _controller.forward();
  }

  @override
  void didUpdateWidget(RivetPopAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected && !oldWidget.isConnected) {
      _controller.forward(from: 0);
    } else if (!widget.isConnected && oldWidget.isConnected) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: widget.child,
    );
  }
}
