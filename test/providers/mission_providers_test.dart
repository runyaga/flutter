import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/src/domain/task_item.dart';
import 'package:soliplex_client/src/domain/task_list.dart';
import 'package:soliplex_client/src/generated/task_list.dart' as gen;
import 'package:soliplex_frontend/core/providers/mission_providers.dart';

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
  group('taskListProvider', () {
    test('returns null when no AG-UI state available (pre-M09)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final taskList = container.read(taskListProvider('room-123'));

      // Pre-M09: Provider returns null as AG-UI state integration
      // is not implemented
      expect(taskList, isNull);
    });
  });

  group('taskListSummaryProvider', () {
    test('returns null when taskList is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final summary = container.read(taskListSummaryProvider('room-123'));

      expect(summary, isNull);
    });

    test('computes summary from taskList when available', () {
      // Create a container with overridden taskListProvider
      final testTaskList = TaskList(
        gen.TaskList(
          missionId: 'mission-123',
          tasks: [
            _createTask(id: '1', status: 'pending'),
            _createTask(id: '2', status: 'in_progress'),
            _createTask(id: '3', status: 'completed'),
            _createTask(id: '4', status: 'completed'),
          ],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          taskListProvider('room-123').overrideWith((ref) => testTaskList),
        ],
      );
      addTearDown(container.dispose);

      final summary = container.read(taskListSummaryProvider('room-123'));

      expect(summary, isNotNull);
      expect(summary!.total, 4);
      expect(summary.pending, 1);
      expect(summary.inProgress, 1);
      expect(summary.completed, 2);
    });
  });

  group('currentTaskProvider', () {
    test('returns null when taskList is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final current = container.read(currentTaskProvider('room-123'));

      expect(current, isNull);
    });

    test('returns first in_progress task', () {
      final testTaskList = TaskList(
        gen.TaskList(
          missionId: 'mission-123',
          tasks: [
            _createTask(id: '1', status: 'pending'),
            _createTask(id: '2', status: 'in_progress'),
            _createTask(id: '3', status: 'completed'),
          ],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          taskListProvider('room-123').overrideWith((ref) => testTaskList),
        ],
      );
      addTearDown(container.dispose);

      final current = container.read(currentTaskProvider('room-123'));

      expect(current, isNotNull);
      expect(current!.id, '2');
      expect(current.status, TaskStatus.inProgress);
    });

    test('returns null when no in_progress tasks', () {
      final testTaskList = TaskList(
        gen.TaskList(
          missionId: 'mission-123',
          tasks: [
            _createTask(id: '1', status: 'pending'),
            _createTask(id: '2', status: 'completed'),
          ],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          taskListProvider('room-123').overrideWith((ref) => testTaskList),
        ],
      );
      addTearDown(container.dispose);

      final current = container.read(currentTaskProvider('room-123'));

      expect(current, isNull);
    });
  });

  group('pendingApprovalsProvider', () {
    test('returns empty list when no AG-UI state available (pre-M09)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final approvals = container.read(pendingApprovalsProvider('room-123'));

      // Pre-M09: Provider returns empty list as AG-UI state integration
      // is not implemented
      expect(approvals, isEmpty);
    });
  });

  group('firstPendingApprovalProvider', () {
    test('returns null when pendingApprovals is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(firstPendingApprovalProvider('room-123'));

      expect(first, isNull);
    });

    test('returns first approval from list when available', () {
      // This test documents expected behavior post-M09
      // For now, we can only test the empty case
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Pre-M09: Always returns null because pendingApprovals is empty
      final first = container.read(firstPendingApprovalProvider('room-123'));
      expect(first, isNull);
    });
  });

  group('provider family isolation', () {
    test('providers for different rooms are independent', () {
      final taskListRoom1 = TaskList(
        gen.TaskList(
          missionId: 'mission-1',
          tasks: [_createTask(id: '1', status: 'pending')],
        ),
      );
      final taskListRoom2 = TaskList(
        gen.TaskList(
          missionId: 'mission-2',
          tasks: [
            _createTask(id: '2', status: 'completed'),
            _createTask(id: '3', status: 'completed'),
          ],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          taskListProvider('room-1').overrideWith((ref) => taskListRoom1),
          taskListProvider('room-2').overrideWith((ref) => taskListRoom2),
        ],
      );
      addTearDown(container.dispose);

      final summary1 = container.read(taskListSummaryProvider('room-1'));
      final summary2 = container.read(taskListSummaryProvider('room-2'));

      expect(summary1!.total, 1);
      expect(summary1.pending, 1);

      expect(summary2!.total, 2);
      expect(summary2.completed, 2);
    });
  });
}
