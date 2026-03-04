import 'package:flutter/material.dart';

/// Pipe-flow channel switch animation.
///
/// Current messages drain down, new ones fill from the bottom.
/// Uses SlideTransition with a 500ms duration.
class PipeFlowTransition extends StatelessWidget {
  const PipeFlowTransition({
    required this.animation,
    required this.child,
    super.key,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1), // Enter from bottom
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}
