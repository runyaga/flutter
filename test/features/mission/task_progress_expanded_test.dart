import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/src/generated/task_list.dart' as gen;
import 'package:soliplex_frontend/core/providers/mission_providers.dart';
import 'package:soliplex_frontend/features/mission/widgets/task_item_tile.dart';
import 'package:soliplex_frontend/features/mission/widgets/task_progress_expanded.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('TaskProgressExpanded', () {
    testWidgets('shows empty state when no tasks', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => null),
          ],
        ),
      );

      expect(find.text('No tasks'), findsOneWidget);
      expect(find.byIcon(Icons.task_outlined), findsOneWidget);
    });

    testWidgets('shows empty state when task list is empty', (tester) async {
      final emptyTasks = _createTasks([]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => emptyTasks),
          ],
        ),
      );

      expect(find.text('No tasks'), findsOneWidget);
    });

    testWidgets('shows all tasks in list', (tester) async {
      final tasks = _createTasks([
        ('task-1', 'Parse input files', 'completed'),
        ('task-2', 'Validate data', 'in_progress'),
        ('task-3', 'Generate report', 'pending'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      expect(find.text('Parse input files'), findsOneWidget);
      expect(find.text('Validate data'), findsOneWidget);
      expect(find.text('Generate report'), findsOneWidget);
    });

    testWidgets('shows header with title', (tester) async {
      final tasks = _createTasks(
        [('task-1', 'Task 1', 'pending')],
        title: 'Data Processing Pipeline',
      );

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      expect(find.text('Data Processing Pipeline'), findsOneWidget);
    });

    testWidgets('shows default title when none provided', (tester) async {
      final tasks = _createTasks([('task-1', 'Task 1', 'pending')]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      expect(find.text('Tasks'), findsOneWidget);
    });

    testWidgets('shows correct status icons', (tester) async {
      final tasks = _createTasks([
        ('task-1', 'Completed Task', 'completed'),
        ('task-2', 'In Progress Task', 'in_progress'),
        ('task-3', 'Pending Task', 'pending'),
        ('task-4', 'Blocked Task', 'blocked'),
        ('task-5', 'Skipped Task', 'skipped'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
            taskListSummaryProvider('thread').overrideWith((_) => tasks.summary),
          ],
        ),
      );
      // Use pump() with duration instead of pumpAndSettle() because the
      // spinning icon animation runs infinitely
      await tester.pump(const Duration(milliseconds: 100));

      // Check for status icons
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // completed
      expect(find.byIcon(Icons.sync), findsOneWidget); // in_progress (spinning)
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget); // pending
      expect(find.byIcon(Icons.block), findsOneWidget); // blocked
      expect(find.byIcon(Icons.skip_next), findsOneWidget); // skipped
    });

    testWidgets('blocked task shows blocked indicator', (tester) async {
      final tasks = _createTasks([
        ('task-1', 'Blocked Task', 'blocked'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      expect(find.text('Blocked'), findsOneWidget);
    });

    testWidgets('calls onCollapse when collapse button tapped', (tester) async {
      bool collapsed = false;
      final tasks = _createTasks([('task-1', 'Task 1', 'pending')]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(
            threadId: 'thread',
            onCollapse: () => collapsed = true,
          ),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      expect(collapsed, isTrue);
    });

    testWidgets('does not show collapse button when onCollapse is null', (tester) async {
      final tasks = _createTasks([('task-1', 'Task 1', 'pending')]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
    });

    testWidgets('in-progress task shows progress indicator', (tester) async {
      final tasks = _createTasks([
        ('task-1', 'Working on it', 'in_progress'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      // Should find CircularProgressIndicator as trailing widget
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('scrollable with many tasks', (tester) async {
      final tasks = _createTasks(
        List.generate(20, (i) => ('task-$i', 'Task $i', 'pending')),
      );

      await tester.pumpWidget(
        createTestApp(
          home: SizedBox(
            height: 300, // Constrain height
            child: TaskProgressExpanded(threadId: 'thread'),
          ),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
            taskListSummaryProvider('thread').overrideWith((_) => tasks.summary),
          ],
        ),
      );

      // Should find ListView
      expect(find.byType(ListView), findsOneWidget);

      // First task should be visible
      expect(find.text('Task 0'), findsOneWidget);

      // Verify the list is scrollable by checking we can find items
      // beyond the visible area after scrolling
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      // After scrolling down significantly, the first task should no longer
      // be visible, but a later task should be
      expect(find.text('Task 0'), findsNothing);
      // At least one later task should be visible
      expect(
        find.textContaining('Task 1'),
        findsWidgets,
        reason: 'Should find tasks after scrolling',
      );
    });

    testWidgets('renders 100 tasks performantly', (tester) async {
      final tasks = _createTasks(
        List.generate(100, (i) {
          final status = i < 30
              ? 'completed'
              : i < 40
                  ? 'in_progress'
                  : 'pending';
          return ('task-$i', 'Task $i', status);
        }),
      );

      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        createTestApp(
          home: SizedBox(
            height: 600,
            child: TaskProgressExpanded(threadId: 'thread'),
          ),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      stopwatch.stop();

      // Should render in under 100ms (generous threshold for CI)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));

      // Verify structure is correct
      expect(find.byType(TaskItemTile), findsWidgets);
    });

    testWidgets('shows progress summary in header', (tester) async {
      final tasks = _createTasks([
        ('task-1', 'Task 1', 'completed'),
        ('task-2', 'Task 2', 'completed'),
        ('task-3', 'Task 3', 'pending'),
        ('task-4', 'Task 4', 'pending'),
        ('task-5', 'Task 5', 'pending'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      expect(find.text('2/5 complete'), findsOneWidget);
    });

    testWidgets('TaskItemTile has semantic label', (tester) async {
      final tasks = _createTasks([
        ('task-1', 'Important Task', 'completed'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label != null,
      );
      expect(semanticsFinder, findsWidgets);
    });

    testWidgets('completed task shows description as result', (tester) async {
      final tasks = _createTasksWithDescription([
        ('task-1', 'Completed Task', 'Analysis complete: 42 items processed', 'completed'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      // Description is shown with relative timestamp appended
      expect(
        find.textContaining('Analysis complete: 42 items processed'),
        findsOneWidget,
      );
    });

    testWidgets('in-progress task shows description', (tester) async {
      final tasks = _createTasksWithDescription([
        ('task-1', 'Processing', 'Analyzing file 5 of 10...', 'in_progress'),
      ]);

      await tester.pumpWidget(
        createTestApp(
          home: TaskProgressExpanded(threadId: 'thread'),
          overrides: [
            taskListProvider('thread').overrideWith((_) => tasks),
          ],
        ),
      );

      expect(find.text('Analyzing file 5 of 10...'), findsOneWidget);
    });
  });
}

/// Helper to create a TaskList with tasks from a list of (id, title, status) tuples.
TaskList _createTasks(
  List<(String, String, String)> taskData, {
  String? title,
}) {
  final genTasks = taskData.map((data) {
    final (id, taskTitle, status) = data;
    return gen.TaskItem(
      taskId: id,
      title: taskTitle,
      description: '',
      status: status,
      progressPct: status == 'completed' ? 100 : 0,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }).toList();

  return TaskList(
    gen.TaskList(missionId: 'mission-1', tasks: genTasks),
    title: title,
  );
}

/// Helper to create tasks with descriptions.
TaskList _createTasksWithDescription(
  List<(String, String, String, String)> taskData, {
  String? title,
}) {
  final genTasks = taskData.map((data) {
    final (id, taskTitle, description, status) = data;
    return gen.TaskItem(
      taskId: id,
      title: taskTitle,
      description: description,
      status: status,
      progressPct: status == 'completed' ? 100 : 0,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }).toList();

  return TaskList(
    gen.TaskList(missionId: 'mission-1', tasks: genTasks),
    title: title,
  );
}
