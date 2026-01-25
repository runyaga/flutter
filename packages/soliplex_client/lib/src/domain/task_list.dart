import '../generated/task_list.dart' as gen;
import 'task_item.dart';

/// Domain wrapper for TaskList.
class TaskList {
  final gen.TaskList _dto;
  late final List<TaskItem> tasks;

  /// Optional title for display purposes.
  final String? _title;

  TaskList(this._dto, {String? title}) : _title = title {
    tasks = _dto.tasks.map((t) => TaskItem(t)).toList();
  }

  /// Factory constructor to create TaskList from JSON.
  factory TaskList.fromJson(Map<String, dynamic> json) {
    return TaskList(gen.TaskList.fromJson(json));
  }

  /// Mission ID this task list belongs to.
  String get missionId => _dto.missionId;

  /// Display title for the task list.
  String? get title => _title;

  /// Access the underlying DTO.
  gen.TaskList get dto => _dto;
}

/// Summary statistics for a task list.
class TaskListSummary {
  final int total;
  final int pending;
  final int inProgress;
  final int completed;
  final int blocked;
  final int skipped;

  TaskListSummary({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.blocked,
    required this.skipped,
  });

  factory TaskListSummary.fromTasks(List<TaskItem> tasks) {
    int pending = 0, inProgress = 0, completed = 0, blocked = 0, skipped = 0;
    for (final task in tasks) {
      switch (task.status) {
        case TaskStatus.pending:
          pending++;
        case TaskStatus.inProgress:
          inProgress++;
        case TaskStatus.completed:
          completed++;
        case TaskStatus.blocked:
          blocked++;
        case TaskStatus.skipped:
          skipped++;
      }
    }
    return TaskListSummary(
      total: tasks.length,
      pending: pending,
      inProgress: inProgress,
      completed: completed,
      blocked: blocked,
      skipped: skipped,
    );
  }
}
