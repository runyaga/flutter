import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';

import '../../../core/providers/mission_providers.dart';

/// Compact task progress widget for inline/chat display.
///
/// Shows a progress bar with percentage, task count summary, and the
/// current task's title. Minimal height, high information density.
///
/// **Usage**:
/// ```dart
/// TaskProgressCompact(
///   roomId: roomId,
///   onTap: () => showExpandedView(),
/// )
/// ```
class TaskProgressCompact extends ConsumerWidget {
  /// The room ID to watch task progress for.
  final String roomId;

  /// Callback when the widget is tapped (usually to expand).
  final VoidCallback? onTap;

  const TaskProgressCompact({
    required this.roomId,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(taskListSummaryProvider(roomId));
    final currentTask = ref.watch(currentTaskProvider(roomId));

    // Hide widget when no tasks are available.
    if (summary == null || summary.total == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label:
          'Task progress: ${summary.progressPercent.toStringAsFixed(0)} percent, '
          '${summary.completed} of ${summary.total} complete',
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar with percentage
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: summary.progressFraction,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${summary.progressPercent.toStringAsFixed(0)}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Summary count
                Text(
                  '${summary.completed}/${summary.total} tasks complete',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                // Current task title
                if (currentTask != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentTask.title,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
