import '../generated/task_list.dart' as gen;

/// Task status enum matching backend values.
enum TaskStatus {
  pending,
  inProgress,
  completed,
  blocked,
  skipped;

  static TaskStatus fromString(String value) {
    return switch (value) {
      'pending' => TaskStatus.pending,
      'in_progress' => TaskStatus.inProgress,
      'completed' => TaskStatus.completed,
      'blocked' => TaskStatus.blocked,
      'skipped' => TaskStatus.skipped,
      _ => TaskStatus.pending,
    };
  }
}

/// Domain wrapper for TaskItem.
///
/// Note: Uses the TaskItem class from generated/task_list.dart since
/// quicktype generates duplicate TaskItem classes in different files.
class TaskItem {
  final gen.TaskItem _dto;

  TaskItem(this._dto);

  /// Task identifier.
  String get id => _dto.taskId;

  /// Task title/content.
  String get title => _dto.title;

  /// Task description.
  String get description => _dto.description;

  /// Task status enum.
  TaskStatus get status => TaskStatus.fromString(_dto.status);

  /// Progress percentage (0-100).
  int get progressPct => _dto.progressPct;

  /// When the task was created.
  String get createdAt => _dto.createdAt;

  /// When the task was last updated.
  String get updatedAt => _dto.updatedAt;

  /// Access the underlying DTO.
  gen.TaskItem get dto => _dto;
}
