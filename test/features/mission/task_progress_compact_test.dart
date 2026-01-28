import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/src/generated/task_list.dart' as gen;
import 'package:soliplex_frontend/core/providers/mission_providers.dart';
import 'package:soliplex_frontend/features/mission/widgets/task_progress_compact.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('TaskProgressCompact', () {
    testWidgets('shows progress bar and summary', (tester) async {
      final tasks = _createTasks([
        ('task-1', 'Task 1', 'completed'),
        ('task-2', 'Task 2', 'completed'),
        ('task-3', 'Task 3', 'in_progress'),
        ('task-4', 'Task 4', 'pending'),
        ('task-5', 'Task 5', 'pending'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressCompact(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      // Should show 40% (2 completed out of 5)
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('2/5 tasks complete'), findsOneWidget);
    });

    testWidgets('shows current task title', (tester) async {
      final tasks = _createTasks([
        ('task-1', 'Parse input files', 'completed'),
        ('task-2', 'Validate data', 'in_progress'),
        ('task-3', 'Generate report', 'pending'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressCompact(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      // Should show current task title
      expect(find.text('Validate data'), findsOneWidget);
    });

    testWidgets('hides when no tasks', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressCompact(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => null),
          ],
        ),
      );

      // Should not show the card
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('hides when task list is empty', (tester) async {
      final emptyTasks = _createTasks([]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressCompact(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => emptyTasks),
          ],
        ),
      );

      // Should not show the card
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;
      final tasks = _createTasks([
        ('task-1', 'Task 1', 'pending'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressCompact(
            threadId: 'thread',
            onTap: () => tapped = true,
          ),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      await tester.tap(find.byType(Card));
      expect(tapped, isTrue);
    });

    testWidgets('shows 100% when all tasks completed', (tester) async {
      final tasks = _createTasks([
        ('task-1', 'Task 1', 'completed'),
        ('task-2', 'Task 2', 'completed'),
        ('task-3', 'Task 3', 'completed'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressCompact(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('3/3 tasks complete'), findsOneWidget);
    });

    testWidgets('shows 0% when no tasks completed', (tester) async {
      final tasks = _createTasks([
        ('task-1', 'Task 1', 'pending'),
        ('task-2', 'Task 2', 'pending'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressCompact(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      expect(find.text('0%'), findsOneWidget);
      expect(find.text('0/2 tasks complete'), findsOneWidget);
    });

    testWidgets('has semantic label for accessibility', (tester) async {
      final tasks = _createTasks([
        ('task-1', 'Task 1', 'completed'),
        ('task-2', 'Task 2', 'pending'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressCompact(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      // Find the Card widget and get its Semantics ancestor
      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);

      final semantics = tester.getSemantics(find
          .ancestor(
            of: cardFinder,
            matching: find.byType(Semantics),
          )
          .first);
      expect(semantics.label, contains('Task progress'));
      expect(semantics.label, contains('50 percent'));
      expect(semantics.label, contains('1 of 2 complete'));
    });

    testWidgets('truncates long task title', (tester) async {
      final tasks = _createTasks([
        (
          'task-1',
          'A very long task title that should be truncated when displayed in the compact widget',
          'in_progress'
        ),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: SizedBox(
            width: 200, // Constrain width to force truncation
            child: TaskProgressCompact(threadId: 'thread'),
          ),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      // Should still find the text widget even if truncated
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('includes skipped tasks in progress calculation',
        (tester) async {
      final tasks = _createTasks([
        ('task-1', 'Task 1', 'completed'),
        ('task-2', 'Task 2', 'skipped'),
        ('task-3', 'Task 3', 'pending'),
        ('task-4', 'Task 4', 'pending'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressCompact(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      // 2 (completed + skipped) out of 4 = 50%
      expect(find.text('50%'), findsOneWidget);
    });
  });
}

/// Helper to create a TaskList with tasks from a list of (id, title, status) tuples.
TaskList _createTasks(List<(String, String, String)> taskData) {
  final genTasks = taskData.map((data) {
    final (id, title, status) = data;
    return gen.TaskItem(
      taskId: id,
      title: title,
      description: '',
      status: status,
      progressPct: status == 'completed' ? 100 : 0,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }).toList();

  return TaskList(
    gen.TaskList(missionId: 'mission-1', tasks: genTasks),
  );
}
