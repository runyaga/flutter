import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens/colors.dart';
import '../design/tokens/spacing.dart';
import '../design/tokens/typography.dart';
import '../design/theme/steampunk_theme_extension.dart';
import '../painters/steel_plate_painter.dart';
import '../providers/room_providers.dart';
import '../providers/streaming_providers.dart';

/// Bottom status bar — industrial instrument panel.
///
/// ```
/// [!] PRESSURE: NOMINAL │ FLOW: 847 msg/h │ UPTIME: 4d 12h
/// ```
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = SteampunkTheme.of(context);
    final roomId = ref.watch(currentRoomIdProvider);
    final runState = ref.watch(activeRunStateProvider);

    final statusText = switch (runState) {
      IdleState() => 'IDLE',
      StreamingRunState() => 'STREAMING',
      CompletedRunState() => 'COMPLETE',
      FailedRunState(:final error) => 'ERROR: $error',
    };

    final statusColor = switch (runState) {
      IdleState() => sp.pipeGreen,
      StreamingRunState() => sp.furnaceOrange,
      CompletedRunState() => sp.pipeGreen,
      FailedRunState() => sp.furnaceRed,
    };

    return CustomPaint(
      painter: SteelPlatePainter(color: BoilerColors.surface),
      child: Container(
        height: BoilerSpacing.statusBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: BoilerSpacing.s4),
        child: Row(
          children: [
            // Status indicator dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withAlpha(100),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: BoilerSpacing.s2),
            Text(
              'STATUS: $statusText',
              style: BoilerTypography.barlowCondensed(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),

            _StatusDivider(sp: sp),

            Text(
              'CONDUIT: ${roomId ?? "NONE"}',
              style: BoilerTypography.statusBar,
            ),

            _StatusDivider(sp: sp),

            Text(
              'PRESSURE: NOMINAL',
              style: BoilerTypography.statusBar,
            ),

            const Spacer(),

            // Furnace heartbeat indicator
            _FurnaceIndicator(isActive: runState.isRunning, sp: sp),
          ],
        ),
      ),
    );
  }
}

class _StatusDivider extends StatelessWidget {
  const _StatusDivider({required this.sp});
  final SteampunkTheme sp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BoilerSpacing.s3),
      child: Container(
        width: 1,
        height: 16,
        color: sp.borderColor,
      ),
    );
  }
}

/// Glowing indicator that pulses during streaming.
class _FurnaceIndicator extends StatefulWidget {
  const _FurnaceIndicator({required this.isActive, required this.sp});

  final bool isActive;
  final SteampunkTheme sp;

  @override
  State<_FurnaceIndicator> createState() => _FurnaceIndicatorState();
}

class _FurnaceIndicatorState extends State<_FurnaceIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isActive) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_FurnaceIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.duration = const Duration(milliseconds: 500);
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.duration = const Duration(seconds: 2);
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
        final glow = _controller.value;
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color.lerp(
                  BoilerColors.furnaceRed,
                  BoilerColors.furnaceOrange,
                  glow,
                )!,
                BoilerColors.furnaceRed.withAlpha(40),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: BoilerColors.furnaceOrange.withAlpha(
                  (60 * glow).round(),
                ),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
