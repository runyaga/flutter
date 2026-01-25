import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/src/domain/extensions/task_extensions.dart';
import 'package:soliplex_client/src/domain/task_item.dart';
import 'package:soliplex_client/src/domain/task_list.dart';
import 'package:soliplex_client/src/generated/task_list.dart' as gen;

gen.TaskItem _createTask({
  required String id,
  required String status,
  String title = 'Test task',
  String description = 'Test description',
  int progressPct = 0,
}) {
  return gen.TaskItem(
    taskId: id,
    title: title,
    description: description,
    status: status,
    progressPct: progressPct,
    createdAt: '2024-01-01T00:00:00Z',
    updatedAt: '2024-01-01T00:00:00Z',
  );
}

void main() {
  group('TaskStatus', () {
    test('fromString parses backend values correctly', () {
      expect(TaskStatus.fromString('pending'), TaskStatus.pending);
      expect(TaskStatus.fromString('in_progress'), TaskStatus.inProgress);
      expect(TaskStatus.fromString('completed'), TaskStatus.completed);
      expect(TaskStatus.fromString('blocked'), TaskStatus.blocked);
      expect(TaskStatus.fromString('skipped'), TaskStatus.skipped);
    });

    test('fromString defaults to pending for unknown values', () {
      expect(TaskStatus.fromString('unknown'), TaskStatus.pending);
      expect(TaskStatus.fromString(''), TaskStatus.pending);
    });
  });

  group('TaskItem', () {
    test('wraps DTO fields correctly', () {
      final dto = _createTask(
        id: 'task-123',
        status: 'in_progress',
        title: 'My Task',
        description: 'Task description',
        progressPct: 75,
      );
      final task = TaskItem(dto);

      expect(task.id, 'task-123');
      expect(task.title, 'My Task');
      expect(task.description, 'Task description');
      expect(task.status, TaskStatus.inProgress);
      expect(task.progressPct, 75);
    });
  });

  group('TaskItemExtensions', () {
    test('isActionable returns true for pending task', () {
      final task = TaskItem(_createTask(id: '1', status: 'pending'));
      expect(task.isActionable, isTrue);
    });

    test('isActionable returns false for non-pending task', () {
      expect(
        TaskItem(_createTask(id: '1', status: 'in_progress')).isActionable,
        isFalse,
      );
      expect(
        TaskItem(_createTask(id: '2', status: 'completed')).isActionable,
        isFalse,
      );
      expect(
        TaskItem(_createTask(id: '3', status: 'blocked')).isActionable,
        isFalse,
      );
      expect(
        TaskItem(_createTask(id: '4', status: 'skipped')).isActionable,
        isFalse,
      );
    });

    test('statusIcon returns correct icons', () {
      expect(
        TaskItem(_createTask(id: '1', status: 'pending')).statusIcon,
        '[ ]',
      );
      expect(
        TaskItem(_createTask(id: '2', status: 'in_progress')).statusIcon,
        '[*]',
      );
      expect(
        TaskItem(_createTask(id: '3', status: 'completed')).statusIcon,
        '[x]',
      );
      expect(
        TaskItem(_createTask(id: '4', status: 'blocked')).statusIcon,
        '[!]',
      );
      expect(
        TaskItem(_createTask(id: '5', status: 'skipped')).statusIcon,
        '[-]',
      );
    });

    test('isTerminal returns true for completed and skipped', () {
      expect(
        TaskItem(_createTask(id: '1', status: 'completed')).isTerminal,
        isTrue,
      );
      expect(
        TaskItem(_createTask(id: '2', status: 'skipped')).isTerminal,
        isTrue,
      );
    });

    test('isTerminal returns false for non-terminal statuses', () {
      expect(
        TaskItem(_createTask(id: '1', status: 'pending')).isTerminal,
        isFalse,
      );
      expect(
        TaskItem(_createTask(id: '2', status: 'in_progress')).isTerminal,
        isFalse,
      );
      expect(
        TaskItem(_createTask(id: '3', status: 'blocked')).isTerminal,
        isFalse,
      );
    });

    test('statusText returns human-readable text', () {
      expect(
        TaskItem(_createTask(id: '1', status: 'pending')).statusText,
        'Pending',
      );
      expect(
        TaskItem(_createTask(id: '2', status: 'in_progress')).statusText,
        'In Progress',
      );
      expect(
        TaskItem(_createTask(id: '3', status: 'completed')).statusText,
        'Completed',
      );
      expect(
        TaskItem(_createTask(id: '4', status: 'blocked')).statusText,
        'Blocked',
      );
      expect(
        TaskItem(_createTask(id: '5', status: 'skipped')).statusText,
        'Skipped',
      );
    });

    test('isFullyComplete returns true when progressPct >= 100', () {
      expect(
        TaskItem(_createTask(id: '1', status: 'completed', progressPct: 100))
            .isFullyComplete,
        isTrue,
      );
      expect(
        TaskItem(_createTask(id: '2', status: 'completed', progressPct: 150))
            .isFullyComplete,
        isTrue,
      );
    });

    test('isFullyComplete returns false when progressPct < 100', () {
      expect(
        TaskItem(_createTask(id: '1', status: 'in_progress', progressPct: 99))
            .isFullyComplete,
        isFalse,
      );
      expect(
        TaskItem(_createTask(id: '2', status: 'pending', progressPct: 0))
            .isFullyComplete,
        isFalse,
      );
    });
  });

  group('TaskListSummary', () {
    test('fromTasks computes counts correctly', () {
      final tasks = [
        TaskItem(_createTask(id: '1', status: 'pending')),
        TaskItem(_createTask(id: '2', status: 'pending')),
        TaskItem(_createTask(id: '3', status: 'in_progress')),
        TaskItem(_createTask(id: '4', status: 'completed')),
        TaskItem(_createTask(id: '5', status: 'completed')),
        TaskItem(_createTask(id: '6', status: 'completed')),
        TaskItem(_createTask(id: '7', status: 'blocked')),
        TaskItem(_createTask(id: '8', status: 'skipped')),
      ];

      final summary = TaskListSummary.fromTasks(tasks);

      expect(summary.total, 8);
      expect(summary.pending, 2);
      expect(summary.inProgress, 1);
      expect(summary.completed, 3);
      expect(summary.blocked, 1);
      expect(summary.skipped, 1);
    });

    test('fromTasks handles empty list', () {
      final summary = TaskListSummary.fromTasks([]);

      expect(summary.total, 0);
      expect(summary.pending, 0);
      expect(summary.inProgress, 0);
      expect(summary.completed, 0);
      expect(summary.blocked, 0);
      expect(summary.skipped, 0);
    });
  });

  group('TaskListSummaryExtensions', () {
    test('progressPercent calculates correctly', () {
      final summary = TaskListSummary(
        total: 10,
        pending: 3,
        inProgress: 2,
        completed: 4,
        blocked: 0,
        skipped: 1,
      );
      // (4 completed + 1 skipped) / 10 total * 100 = 50%
      expect(summary.progressPercent, equals(50.0));
    });

    test('progressPercent returns 0 for empty list', () {
      final summary = TaskListSummary(
        total: 0,
        pending: 0,
        inProgress: 0,
        completed: 0,
        blocked: 0,
        skipped: 0,
      );
      expect(summary.progressPercent, equals(0.0));
    });

    test('progressPercent handles all completed', () {
      final summary = TaskListSummary(
        total: 5,
        pending: 0,
        inProgress: 0,
        completed: 5,
        blocked: 0,
        skipped: 0,
      );
      expect(summary.progressPercent, equals(100.0));
    });

    test('progressFraction calculates correctly', () {
      final summary = TaskListSummary(
        total: 4,
        pending: 1,
        inProgress: 1,
        completed: 1,
        blocked: 0,
        skipped: 1,
      );
      // (1 completed + 1 skipped) / 4 total = 0.5
      expect(summary.progressFraction, equals(0.5));
    });

    test('progressFraction returns 0 for empty list', () {
      final summary = TaskListSummary(
        total: 0,
        pending: 0,
        inProgress: 0,
        completed: 0,
        blocked: 0,
        skipped: 0,
      );
      expect(summary.progressFraction, equals(0.0));
    });
  });

  group('TaskListExtensions', () {
    late gen.TaskList dto;
    late TaskList taskList;

    setUp(() {
      dto = gen.TaskList(
        missionId: 'mission-123',
        tasks: [
          _createTask(id: '1', status: 'pending'),
          _createTask(id: '2', status: 'in_progress'),
          _createTask(id: '3', status: 'completed'),
          _createTask(id: '4', status: 'pending'),
        ],
      );
      taskList = TaskList(dto);
    });

    test('summary computes statistics', () {
      final summary = taskList.summary;
      expect(summary.total, 4);
      expect(summary.pending, 2);
      expect(summary.inProgress, 1);
      expect(summary.completed, 1);
    });

    test('actionableTasks returns pending tasks', () {
      final actionable = taskList.actionableTasks;
      expect(actionable.length, 2);
      expect(actionable.every((t) => t.status == TaskStatus.pending), isTrue);
    });

    test('currentTask returns first in_progress task', () {
      final current = taskList.currentTask;
      expect(current, isNotNull);
      expect(current!.id, '2');
      expect(current.status, TaskStatus.inProgress);
    });

    test('currentTask returns null when no in_progress tasks', () {
      final noProgressDto = gen.TaskList(
        missionId: 'mission-123',
        tasks: [
          _createTask(id: '1', status: 'pending'),
          _createTask(id: '2', status: 'completed'),
        ],
      );
      final noProgressList = TaskList(noProgressDto);
      expect(noProgressList.currentTask, isNull);
    });
  });

  group('TaskList', () {
    test('wraps DTO fields correctly', () {
      final dto = gen.TaskList(
        missionId: 'mission-abc',
        tasks: [_createTask(id: '1', status: 'pending')],
      );
      final taskList = TaskList(dto);

      expect(taskList.missionId, 'mission-abc');
      expect(taskList.tasks.length, 1);
      expect(taskList.tasks.first.id, '1');
    });

    test('tasks are wrapped as domain TaskItem', () {
      final dto = gen.TaskList(
        missionId: 'mission-123',
        tasks: [_createTask(id: '1', status: 'completed')],
      );
      final taskList = TaskList(dto);

      expect(taskList.tasks.first, isA<TaskItem>());
      expect(taskList.tasks.first.status, TaskStatus.completed);
    });
  });
}
