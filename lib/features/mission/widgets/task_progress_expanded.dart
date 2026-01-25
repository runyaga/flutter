import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/mission_providers.dart';
import 'task_item_tile.dart';
import 'task_progress_header.dart';

/// Expanded task progress widget for sidebar/panel display.
///
/// Shows the full task list with status icons, blocking info,
/// timestamps, and results. Supports scrolling for long lists.
///
/// **Usage**:
/// ```dart
/// TaskProgressExpanded(
///   threadId: threadId,
///   onCollapse: () => collapseToCompact(),
/// )
/// ```
class TaskProgressExpanded extends ConsumerWidget {
  /// The thread ID to watch task progress for.
  final String threadId;

  /// Callback when collapse button is pressed.
  final VoidCallback? onCollapse;

  const TaskProgressExpanded({
    required this.threadId,
    this.onCollapse,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskList = ref.watch(taskListProvider(threadId));
    final summary = ref.watch(taskListSummaryProvider(threadId));

    // Empty state handling
    if (taskList == null || taskList.tasks.isEmpty || summary == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No tasks',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with title and collapse button
        TaskProgressHeader(
          title: taskList.title ?? 'Tasks',
          summary: summary,
          onCollapse: onCollapse,
        ),
        const Divider(height: 1),

        // Scrollable task list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: taskList.tasks.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
            itemBuilder: (context, index) {
              return TaskItemTile(task: taskList.tasks[index]);
            },
          ),
        ),
      ],
    );
  }
}
