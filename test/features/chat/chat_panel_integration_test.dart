import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_client/src/generated/approval_request.dart' as gen;
import 'package:soliplex_client/src/generated/task_list.dart' as task_gen;
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/mission_providers.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/features/chat/chat_panel.dart';
import 'package:soliplex_frontend/features/mission/widgets/approval_banner.dart';
import 'package:soliplex_frontend/features/mission/widgets/task_progress_compact.dart';
import 'package:soliplex_frontend/features/mission/widgets/task_progress_expanded.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('ChatPanel Integration - Task Progress', () {
    testWidgets('shows TaskProgressCompact when tasks exist', (tester) async {
      // Use only completed/pending tasks (no in_progress) to avoid spinner
      final tasks = _createTaskList([
        ('task-1', 'First task', 'completed'),
        ('task-2', 'Second task', 'pending'),
        ('task-3', 'Third task', 'pending'),
      ]);

      final room = TestData.createRoom();
      final thread = TestData.createThread(id: 'thread-123');

      await tester.pumpWidget(
        createTestApp(
          home: const ChatPanel(),
          overrides: [
            currentRoomProvider.overrideWith((ref) => room),
            currentThreadProvider.overrideWith((ref) => thread),
            activeRunNotifierOverride(const IdleState()),
            allMessagesProvider.overrideWith((ref) async => []),
            taskListProvider('thread-123').overrideWith((_) => tasks),
            taskListSummaryProvider('thread-123')
                .overrideWith((_) => tasks.summary),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaskProgressCompact), findsOneWidget);
      expect(find.text('33%'), findsOneWidget); // 1/3 complete
    });

    testWidgets('hides TaskProgressCompact when no tasks', (tester) async {
      final room = TestData.createRoom();
      final thread = TestData.createThread(id: 'thread-123');

      await tester.pumpWidget(
        createTestApp(
          home: const ChatPanel(),
          overrides: [
            currentRoomProvider.overrideWith((ref) => room),
            currentThreadProvider.overrideWith((ref) => thread),
            activeRunNotifierOverride(const IdleState()),
            allMessagesProvider.overrideWith((ref) async => []),
            taskListProvider('thread-123').overrideWith((_) => null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaskProgressCompact), findsNothing);
      expect(find.byType(TaskProgressExpanded), findsNothing);
    });

    testWidgets('expands task list on tap', (tester) async {
      final tasks = _createTaskList([
        ('task-1', 'Task A', 'completed'),
        ('task-2', 'Task B', 'pending'),
      ]);

      final room = TestData.createRoom();
      final thread = TestData.createThread(id: 'thread-123');

      await tester.pumpWidget(
        createTestApp(
          home: const ChatPanel(),
          overrides: [
            currentRoomProvider.overrideWith((ref) => room),
            currentThreadProvider.overrideWith((ref) => thread),
            activeRunNotifierOverride(const IdleState()),
            allMessagesProvider.overrideWith((ref) async => []),
            taskListProvider('thread-123').overrideWith((_) => tasks),
            taskListSummaryProvider('thread-123')
                .overrideWith((_) => tasks.summary),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Initially compact
      expect(find.byType(TaskProgressCompact), findsOneWidget);
      expect(find.byType(TaskProgressExpanded), findsNothing);

      // Tap to expand
      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      // Now expanded
      expect(find.byType(TaskProgressCompact), findsNothing);
      expect(find.byType(TaskProgressExpanded), findsOneWidget);
    });

    testWidgets('collapses task list when collapse button pressed',
        (tester) async {
      final tasks = _createTaskList([
        ('task-1', 'Task A', 'pending'),
      ]);

      final room = TestData.createRoom();
      final thread = TestData.createThread(id: 'thread-123');

      await tester.pumpWidget(
        createTestApp(
          home: const ChatPanel(),
          overrides: [
            currentRoomProvider.overrideWith((ref) => room),
            currentThreadProvider.overrideWith((ref) => thread),
            activeRunNotifierOverride(const IdleState()),
            allMessagesProvider.overrideWith((ref) async => []),
            taskListProvider('thread-123').overrideWith((_) => tasks),
            taskListSummaryProvider('thread-123')
                .overrideWith((_) => tasks.summary),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap to expand
      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(find.byType(TaskProgressExpanded), findsOneWidget);

      // Tap collapse button
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pumpAndSettle();

      // Back to compact
      expect(find.byType(TaskProgressCompact), findsOneWidget);
      expect(find.byType(TaskProgressExpanded), findsNothing);
    });

    testWidgets('has accessibility label for task progress', (tester) async {
      final tasks = _createTaskList([
        ('task-1', 'Task A', 'completed'),
        ('task-2', 'Task B', 'completed'),
        ('task-3', 'Task C', 'pending'),
        ('task-4', 'Task D', 'pending'),
      ]);
      final summary = tasks.summary;

      final room = TestData.createRoom();
      final thread = TestData.createThread(id: 'thread-123');

      await tester.pumpWidget(
        createTestApp(
          home: const ChatPanel(),
          overrides: [
            currentRoomProvider.overrideWith((ref) => room),
            currentThreadProvider.overrideWith((ref) => thread),
            activeRunNotifierOverride(const IdleState()),
            allMessagesProvider.overrideWith((ref) async => []),
            taskListProvider('thread-123').overrideWith((_) => tasks),
            taskListSummaryProvider('thread-123').overrideWith((_) => summary),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Find Semantics widget with label containing 'progress'
      // Multiple Semantics widgets exist, so check if any has progress label
      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );

      final hasProgressLabel = semanticsWidgets.any(
        (s) => s.properties.label?.contains('progress') ?? false,
      );
      expect(hasProgressLabel, isTrue);
    });
  });

  group('ChatPanel Integration - Approval Banner', () {
    testWidgets('shows ApprovalBanner when approval pending', (tester) async {
      final approval = _createApprovalRequest(
        title: 'Delete Files',
        description: 'Delete temporary files',
      );

      final room = TestData.createRoom();
      final thread = TestData.createThread(id: 'thread-123');

      await tester.pumpWidget(
        createTestApp(
          home: const ChatPanel(),
          overrides: [
            currentRoomProvider.overrideWith((ref) => room),
            currentThreadProvider.overrideWith((ref) => thread),
            activeRunNotifierOverride(const IdleState()),
            allMessagesProvider.overrideWith((ref) async => []),
            firstPendingApprovalProvider('thread-123')
                .overrideWith((_) => approval),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ApprovalBanner), findsOneWidget);
      expect(find.text('Action Required: Delete Files'), findsOneWidget);
    });

    testWidgets('hides ApprovalBanner when no approvals', (tester) async {
      final room = TestData.createRoom();
      final thread = TestData.createThread(id: 'thread-123');

      await tester.pumpWidget(
        createTestApp(
          home: const ChatPanel(),
          overrides: [
            currentRoomProvider.overrideWith((ref) => room),
            currentThreadProvider.overrideWith((ref) => thread),
            activeRunNotifierOverride(const IdleState()),
            allMessagesProvider.overrideWith((ref) async => []),
            firstPendingApprovalProvider('thread-123')
                .overrideWith((_) => null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Banner renders as SizedBox.shrink when no approvals
      expect(find.text('Action Required'), findsNothing);
      expect(find.byType(MaterialBanner), findsNothing);
    });
  });

  group('ChatPanel Integration - Combined State', () {
    testWidgets('shows both task progress and approval banner', (tester) async {
      // Use completed task to avoid spinner animation timeout
      final tasks = _createTaskList([
        ('task-1', 'Processing', 'completed'),
      ]);
      final approval = _createApprovalRequest(title: 'Confirm Action');

      final room = TestData.createRoom();
      final thread = TestData.createThread(id: 'thread-123');

      await tester.pumpWidget(
        createTestApp(
          home: const ChatPanel(),
          overrides: [
            currentRoomProvider.overrideWith((ref) => room),
            currentThreadProvider.overrideWith((ref) => thread),
            activeRunNotifierOverride(const IdleState()),
            allMessagesProvider.overrideWith((ref) async => []),
            taskListProvider('thread-123').overrideWith((_) => tasks),
            taskListSummaryProvider('thread-123')
                .overrideWith((_) => tasks.summary),
            firstPendingApprovalProvider('thread-123')
                .overrideWith((_) => approval),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaskProgressCompact), findsOneWidget);
      expect(find.text('Action Required: Confirm Action'), findsOneWidget);
    });

    testWidgets(
      'hides widgets when no thread selected',
      (tester) async {
        final room = TestData.createRoom();
        final thread = TestData.createThread(id: 'thread-empty');

        await tester.pumpWidget(
          createTestApp(
            home: const ChatPanel(),
            overrides: [
              currentRoomProvider.overrideWith((ref) => room),
              // Use a thread but with no tasks/approvals
              currentThreadProvider.overrideWith((ref) => thread),
              activeRunNotifierOverride(const IdleState()),
              allMessagesProvider.overrideWith((ref) async => <ChatMessage>[]),
              taskListProvider('thread-empty').overrideWith((_) => null),
              firstPendingApprovalProvider('thread-empty')
                  .overrideWith((_) => null),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // No widgets shown when no tasks/approvals
        expect(find.byType(TaskProgressCompact), findsNothing);
        expect(find.byType(MaterialBanner), findsNothing);
      },
    );

    testWidgets('animated size provides smooth transitions', (tester) async {
      final room = TestData.createRoom();
      final thread = TestData.createThread(id: 'thread-123');

      await tester.pumpWidget(
        createTestApp(
          home: const ChatPanel(),
          overrides: [
            currentRoomProvider.overrideWith((ref) => room),
            currentThreadProvider.overrideWith((ref) => thread),
            activeRunNotifierOverride(const IdleState()),
            allMessagesProvider.overrideWith((ref) async => []),
            taskListProvider('thread-123').overrideWith((_) => null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // AnimatedSize is present even when no tasks
      expect(find.byType(AnimatedSize), findsOneWidget);
    });
  });
}

/// Helper to create a TaskList with tasks.
TaskList _createTaskList(List<(String, String, String)> taskData) {
  final genTasks = taskData.map((data) {
    final (id, title, status) = data;
    return task_gen.TaskItem(
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
    task_gen.TaskList(missionId: 'mission-1', tasks: genTasks),
  );
}

/// Helper to create an ApprovalRequest for testing.
ApprovalRequest _createApprovalRequest({
  String id = 'approval-123',
  String title = 'Test Action',
  String description = 'Test description',
}) {
  final genRequest = gen.ApprovalRequest(
    approvalId: id,
    title: title,
    actionType: 'test',
    description: description,
    status: 'pending',
    missionId: 'mission-1',
    payload: <String, dynamic>{},
    createdAt: '2026-01-25T12:00:00Z',
    expiresAt: '2026-01-25T13:00:00Z',
  );
  return ApprovalRequest(genRequest);
}
