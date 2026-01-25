import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/mission_providers.dart';
import 'package:soliplex_frontend/core/services/approval_service.dart';
import 'package:soliplex_frontend/features/mission/widgets/approval_banner.dart';
import 'package:soliplex_frontend/features/mission/widgets/approval_dialog.dart';
import 'package:soliplex_client/src/generated/approval_request.dart' as gen;

class MockApprovalService extends Mock implements ApprovalService {}

void main() {
  late MockApprovalService mockApprovalService;

  setUp(() {
    mockApprovalService = MockApprovalService();
  });

  /// Creates an ApprovalRequest for testing using the domain model.
  ApprovalRequest createApprovalRequest({
    String id = 'approval-123',
    String title = 'Delete files',
    String actionType = 'delete',
    String description = 'Delete 15 files from the output directory',
    String status = 'pending',
    List<ApprovalOption>? options,
    Map<String, dynamic>? details,
  }) {
    // Build payload with options and details
    final payload = <String, dynamic>{};
    if (options != null) {
      payload['options'] = options
          .map((o) => {
                'id': o.id,
                'label': o.label,
                'is_destructive': o.isDestructive,
              })
          .toList();
    }
    if (details != null) {
      payload['details'] = details;
    }

    final genRequest = gen.ApprovalRequest(
      approvalId: id,
      title: title,
      actionType: actionType,
      description: description,
      status: status,
      missionId: 'mission-1',
      payload: payload,
      createdAt: '2026-01-25T12:00:00Z',
      expiresAt: '2026-01-25T13:00:00Z',
    );
    return ApprovalRequest(genRequest);
  }

  group('ApprovalBanner', () {
    testWidgets('shows when approval pending', (tester) async {
      final approval = createApprovalRequest();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firstPendingApprovalProvider('thread-1').overrideWith((_) => approval),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ApprovalBanner(threadId: 'thread-1')),
          ),
        ),
      );

      expect(find.text('Action Required: Delete files'), findsOneWidget);
      expect(find.text('The agent needs your approval to continue.'), findsOneWidget);
      expect(find.text('Review & Approve'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('hides when no approvals pending', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firstPendingApprovalProvider('thread-1').overrideWith((_) => null),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ApprovalBanner(threadId: 'thread-1')),
          ),
        ),
      );

      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.text('Action Required'), findsNothing);
    });

    testWidgets('opens dialog when Review & Approve tapped', (tester) async {
      final approval = createApprovalRequest();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firstPendingApprovalProvider('thread-1').overrideWith((_) => approval),
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ApprovalBanner(threadId: 'thread-1')),
          ),
        ),
      );

      await tester.tap(find.text('Review & Approve'));
      await tester.pumpAndSettle();

      expect(find.byType(ApprovalDialog), findsOneWidget);
      expect(find.text('Delete files'), findsOneWidget);
    });
  });

  group('ApprovalDialog', () {
    testWidgets('displays action as title', (tester) async {
      final approval = createApprovalRequest(title: 'Execute Script');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      expect(find.text('Execute Script'), findsOneWidget);
    });

    testWidgets('displays description as body', (tester) async {
      final approval = createApprovalRequest(
        description: 'This will execute a shell script with elevated privileges.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      expect(
        find.text('This will execute a shell script with elevated privileges.'),
        findsOneWidget,
      );
    });

    testWidgets('shows all option buttons', (tester) async {
      final approval = createApprovalRequest(
        options: [
          const ApprovalOption(id: 'approve', label: 'Approve'),
          const ApprovalOption(id: 'modify', label: 'Modify'),
          const ApprovalOption(id: 'reject', label: 'Reject', isDestructive: true),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Modify'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('styles destructive options in red', (tester) async {
      final approval = createApprovalRequest(
        options: [
          const ApprovalOption(id: 'approve', label: 'Approve'),
          const ApprovalOption(id: 'delete', label: 'Delete All', isDestructive: true),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      // Find the Delete All button and verify it has red foreground color
      final deleteButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Delete All'),
          matching: find.byType(TextButton),
        ),
      );

      expect(deleteButton.style?.foregroundColor?.resolve({}), Colors.red);
    });

    testWidgets('calls API on option tap', (tester) async {
      final approval = createApprovalRequest();

      when(
        () => mockApprovalService.submitApproval(
          threadId: any(named: 'threadId'),
          approvalId: any(named: 'approvalId'),
          selectedOption: any(named: 'selectedOption'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      verify(
        () => mockApprovalService.submitApproval(
          threadId: 'thread-1',
          approvalId: 'approval-123',
          selectedOption: 'approve',
        ),
      ).called(1);
    });

    testWidgets('shows loading state during submission', (tester) async {
      final approval = createApprovalRequest();

      // Create a completer to control when the future completes
      final completer = Completer<void>();

      when(
        () => mockApprovalService.submitApproval(
          threadId: any(named: 'threadId'),
          approvalId: any(named: 'approvalId'),
          selectedOption: any(named: 'selectedOption'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      // Tap the approve button
      await tester.tap(find.text('Approve'));
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Buttons should be hidden during loading
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);

      // Complete the future
      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('shows error snackbar on API failure', (tester) async {
      final approval = createApprovalRequest();

      when(
        () => mockApprovalService.submitApproval(
          threadId: any(named: 'threadId'),
          approvalId: any(named: 'approvalId'),
          selectedOption: any(named: 'selectedOption'),
        ),
      ).thenThrow(ApprovalException('Network error'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to submit: ApprovalException: Network error'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsOneWidget);

      // Buttons should be re-enabled after error
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('prevents double-submit', (tester) async {
      final approval = createApprovalRequest();

      final completer = Completer<void>();

      when(
        () => mockApprovalService.submitApproval(
          threadId: any(named: 'threadId'),
          approvalId: any(named: 'approvalId'),
          selectedOption: any(named: 'selectedOption'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      // Tap approve
      await tester.tap(find.text('Approve'));
      await tester.pump();

      // During loading, buttons are not visible so double-tap isn't possible
      expect(find.text('Approve'), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();

      // API should only be called once
      verify(
        () => mockApprovalService.submitApproval(
          threadId: any(named: 'threadId'),
          approvalId: any(named: 'approvalId'),
          selectedOption: any(named: 'selectedOption'),
        ),
      ).called(1);
    });

    testWidgets('expandable details section shows JSON', (tester) async {
      final approval = createApprovalRequest(
        details: {'files': ['file1.txt', 'file2.txt'], 'total_size': '45 MB'},
        options: [const ApprovalOption(id: 'approve', label: 'Approve')],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      // Details should be collapsed initially
      expect(find.text('Technical Details'), findsOneWidget);
      expect(find.textContaining('file1.txt'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('Technical Details'));
      await tester.pumpAndSettle();

      // Details should now be visible
      expect(find.textContaining('file1.txt'), findsOneWidget);
      expect(find.textContaining('45 MB'), findsOneWidget);

      // Tap to collapse
      await tester.tap(find.text('Technical Details'));
      await tester.pumpAndSettle();

      expect(find.textContaining('file1.txt'), findsNothing);
    });

    testWidgets('dialog closes after successful submission', (tester) async {
      final approval = createApprovalRequest();

      when(
        () => mockApprovalService.submitApproval(
          threadId: any(named: 'threadId'),
          approvalId: any(named: 'approvalId'),
          selectedOption: any(named: 'selectedOption'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => ApprovalDialog(
                        approval: approval,
                        threadId: 'thread-1',
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(ApprovalDialog), findsOneWidget);

      // Submit approval
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.byType(ApprovalDialog), findsNothing);
    });

    testWidgets('shows dismiss button for accessibility', (tester) async {
      final approval = createApprovalRequest();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      // Dismiss button should always be present
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('dismiss button closes dialog without API call', (tester) async {
      final approval = createApprovalRequest();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => ApprovalDialog(
                        approval: approval,
                        threadId: 'thread-1',
                      ),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(ApprovalDialog), findsOneWidget);

      // Tap dismiss
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.byType(ApprovalDialog), findsNothing);

      // API should not be called
      verifyNever(
        () => mockApprovalService.submitApproval(
          threadId: any(named: 'threadId'),
          approvalId: any(named: 'approvalId'),
          selectedOption: any(named: 'selectedOption'),
        ),
      );
    });

    testWidgets('empty options array falls back to default Approve/Reject', (tester) async {
      // Create approval with explicit empty options array in payload
      final genRequest = gen.ApprovalRequest(
        approvalId: 'approval-123',
        title: 'Test Action',
        actionType: 'test',
        description: 'Test description',
        status: 'pending',
        missionId: 'mission-1',
        payload: {'options': <Map<String, dynamic>>[]}, // Empty options array
        createdAt: '2026-01-25T12:00:00Z',
        expiresAt: '2026-01-25T13:00:00Z',
      );
      final approval = ApprovalRequest(genRequest);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      // Should show default options
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('cancel button available during loading', (tester) async {
      final approval = createApprovalRequest();
      final completer = Completer<void>();

      when(
        () => mockApprovalService.submitApproval(
          threadId: any(named: 'threadId'),
          approvalId: any(named: 'approvalId'),
          selectedOption: any(named: 'selectedOption'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      // Tap approve to start loading
      await tester.tap(find.text('Approve'));
      await tester.pump();

      // Cancel button should be visible during loading
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      // Should be back to normal state with buttons visible
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete();
    });

    testWidgets('timeout error shows appropriate message', (tester) async {
      final approval = createApprovalRequest();

      when(
        () => mockApprovalService.submitApproval(
          threadId: any(named: 'threadId'),
          approvalId: any(named: 'approvalId'),
          selectedOption: any(named: 'selectedOption'),
        ),
      ).thenThrow(ApprovalException('Request timed out. Please try again.', isTimeout: true));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('timed out'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsOneWidget);

      // Buttons should be re-enabled for retry
      expect(find.text('Approve'), findsOneWidget);
    });

    testWidgets('does not show details section when payload has no details key', (tester) async {
      // Create approval with payload but no 'details' key
      final genRequest = gen.ApprovalRequest(
        approvalId: 'approval-123',
        title: 'Test Action',
        actionType: 'test',
        description: 'Test description',
        status: 'pending',
        missionId: 'mission-1',
        payload: {'other_field': 'value'}, // No 'details' key
        createdAt: '2026-01-25T12:00:00Z',
        expiresAt: '2026-01-25T13:00:00Z',
      );
      final approval = ApprovalRequest(genRequest);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            approvalServiceProvider.overrideWithValue(mockApprovalService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ApprovalDialog(approval: approval, threadId: 'thread-1'),
            ),
          ),
        ),
      );

      // Technical Details section should NOT be shown (prevents data leakage)
      expect(find.text('Technical Details'), findsNothing);
    });
  });
}
