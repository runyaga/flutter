import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;

/// A single task item tile for the expanded task list view.
///
/// Displays:
/// - Status icon ([ ], [*], [x], [!], [-])
/// - Task title
/// - Description for in-progress or completed tasks
/// - Progress indicator for in-progress tasks
///
/// **Usage**:
/// ```dart
/// TaskItemTile(task: taskItem)
/// ```
class TaskItemTile extends StatelessWidget {
  /// The task item to display.
  final TaskItem task;

  const TaskItemTile({required this.task, super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${task.statusText}: ${task.title}',
      child: ListTile(
        leading: _StatusIcon(status: task.status),
        title: Text(task.title),
        subtitle: _buildSubtitle(context),
        trailing: task.status == TaskStatus.inProgress
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    // Show description for in-progress tasks
    if (task.status == TaskStatus.inProgress && task.description.isNotEmpty) {
      return Text(
        task.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Show relative timestamp for completed tasks
    if (task.status == TaskStatus.completed) {
      final relativeTime = _formatRelativeTime(task.updatedAt);
      final text = task.description.isNotEmpty
          ? '${task.description} • $relativeTime'
          : 'Completed $relativeTime';
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600]),
      );
    }

    // Show blocked indicator
    if (task.status == TaskStatus.blocked) {
      return Text(
        'Blocked',
        style: TextStyle(color: Colors.orange[700]),
      );
    }

    return null;
  }

  /// Format a timestamp as relative time (e.g., "2 min ago").
  String _formatRelativeTime(String isoTimestamp) {
    try {
      final dateTime = DateTime.parse(isoTimestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        final mins = difference.inMinutes;
        return '$mins min${mins == 1 ? '' : 's'} ago';
      } else if (difference.inHours < 24) {
        final hours = difference.inHours;
        return '$hours hour${hours == 1 ? '' : 's'} ago';
      } else {
        final days = difference.inDays;
        return '$days day${days == 1 ? '' : 's'} ago';
      }
    } catch (_) {
      return '';
    }
  }
}

/// Status icon widget that displays the appropriate icon for each task status.
class _StatusIcon extends StatelessWidget {
  final TaskStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      TaskStatus.pending => const Icon(Icons.circle_outlined, color: Colors.grey),
      TaskStatus.inProgress => const _SpinningIcon(),
      TaskStatus.completed => _CompletionAnimation(
          child: const Icon(Icons.check_circle, color: Colors.green),
        ),
      TaskStatus.blocked => const Icon(Icons.block, color: Colors.orange),
      TaskStatus.skipped => const Icon(Icons.skip_next, color: Colors.grey),
    };
  }
}

/// Spinning sync icon for in-progress tasks.
class _SpinningIcon extends StatefulWidget {
  const _SpinningIcon();

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(Icons.sync, color: Colors.blue),
    );
  }
}

/// Scale animation for completion status.
///
/// Animates from 0.8 → 1.1 → 1.0 with 300ms duration and easeInOut curve.
class _CompletionAnimation extends StatefulWidget {
  final Widget child;

  const _CompletionAnimation({required this.child});

  @override
  State<_CompletionAnimation> createState() => _CompletionAnimationState();
}

class _CompletionAnimationState extends State<_CompletionAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.1), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scaleAnimation, child: widget.child);
  }
}
