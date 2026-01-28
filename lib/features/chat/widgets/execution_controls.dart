import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/providers/mission_providers.dart';
import 'package:soliplex_frontend/core/services/steering_service.dart';

/// Controls for pausing, resuming, and cancelling mission execution.
///
/// Only visible when a mission is actively executing or paused.
class ExecutionControls extends ConsumerWidget {
  final String roomId;

  const ExecutionControls({required this.roomId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionStatus = ref.watch(missionStatusProvider(roomId));

    // Hide if no mission or mission is terminal
    if (missionStatus == null ||
        missionStatus == MissionStatus.completed ||
        missionStatus == MissionStatus.failed ||
        missionStatus == MissionStatus.cancelled) {
      return const SizedBox.shrink();
    }

    final isPaused = missionStatus == MissionStatus.paused;
    final isExecuting = missionStatus == MissionStatus.executing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pause/Resume toggle
        if (isExecuting || isPaused)
          IconButton(
            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: isPaused ? 'Resume' : 'Pause',
            onPressed: () async {
              final control = ref.read(missionControlServiceProvider);
              if (isPaused) {
                await control.resume(roomId);
              } else {
                await control.pause(roomId);
              }
            },
          ),

        // Cancel button
        if (isExecuting || isPaused)
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.red),
            tooltip: 'Cancel',
            onPressed: () => _confirmCancel(context, ref),
          ),
      ],
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Mission?'),
        content: const Text(
          'This will stop the agent immediately. Any in-progress work may be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Running'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(missionControlServiceProvider).cancel(roomId);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Mission'),
          ),
        ],
      ),
    );
  }
}
