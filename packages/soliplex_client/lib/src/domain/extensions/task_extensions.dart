import '../task_item.dart';
import '../task_list.dart';

/// Extension methods for TaskItem domain logic.
extension TaskItemExtensions on TaskItem {
  /// Whether this task can be started (pending status).
  bool get isActionable => status == TaskStatus.pending;

  /// Unicode icon for status display.
  String get statusIcon => switch (status) {
        TaskStatus.pending => '[ ]',
        TaskStatus.inProgress => '[*]',
        TaskStatus.completed => '[x]',
        TaskStatus.blocked => '[!]',
        TaskStatus.skipped => '[-]',
      };

  /// Whether task is in a terminal state.
  bool get isTerminal =>
      status == TaskStatus.completed || status == TaskStatus.skipped;

  /// Human-readable status text.
  String get statusText => switch (status) {
        TaskStatus.pending => 'Pending',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.completed => 'Completed',
        TaskStatus.blocked => 'Blocked',
        TaskStatus.skipped => 'Skipped',
      };

  /// Whether the task is fully complete (100%).
  bool get isFullyComplete => progressPct >= 100;
}

/// Extension methods for TaskList domain logic.
extension TaskListExtensions on TaskList {
  /// Compute summary statistics.
  TaskListSummary get summary => TaskListSummary.fromTasks(tasks);

  /// Get all tasks that can be started now.
  List<TaskItem> get actionableTasks =>
      tasks.where((t) => t.isActionable).toList();

  /// Get the currently executing task (first in_progress).
  TaskItem? get currentTask => tasks.cast<TaskItem?>().firstWhere(
        (t) => t?.status == TaskStatus.inProgress,
        orElse: () => null,
      );
}

/// Extension methods for TaskListSummary computed properties.
extension TaskListSummaryExtensions on TaskListSummary {
  /// Progress percentage (0.0 to 100.0).
  double get progressPercent =>
      total == 0 ? 0.0 : ((completed + skipped) / total) * 100;

  /// Fraction complete for progress bars (0.0 to 1.0).
  double get progressFraction =>
      total == 0 ? 0.0 : (completed + skipped) / total;
}
