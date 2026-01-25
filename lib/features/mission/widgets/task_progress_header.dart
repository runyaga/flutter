import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart';

/// Header widget for the expanded task progress view.
///
/// Displays the task list title, progress summary, and a collapse button.
class TaskProgressHeader extends StatelessWidget {
  /// The title of the task list.
  final String title;

  /// Summary statistics for the task list.
  final TaskListSummary summary;

  /// Callback when the collapse button is pressed.
  final VoidCallback? onCollapse;

  const TaskProgressHeader({
    required this.title,
    required this.summary,
    this.onCollapse,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Task progress header: $title, '
          '${summary.completed} of ${summary.total} tasks complete, '
          '${summary.progressPercent.toStringAsFixed(0)} percent',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${summary.completed}/${summary.total} complete',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _ProgressBadge(summary: summary),
                    ],
                  ),
                ],
              ),
            ),
            if (onCollapse != null)
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: onCollapse,
                tooltip: 'Collapse task list',
              ),
          ],
        ),
      ),
    );
  }
}

/// A small badge showing the progress percentage with color coding.
class _ProgressBadge extends StatelessWidget {
  final TaskListSummary summary;

  const _ProgressBadge({required this.summary});

  @override
  Widget build(BuildContext context) {
    final percent = summary.progressPercent;
    final color = _getProgressColor(percent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${percent.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _getProgressColor(double percent) {
    if (percent >= 100) {
      return Colors.green;
    } else if (percent >= 50) {
      return Colors.blue;
    } else if (percent > 0) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }
}
