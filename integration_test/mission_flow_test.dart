// integration_test/mission_flow_test.dart
// Automated UI tests for mission flow using Flutter integration_test package.
//
// NOTE: This is an optional test file. To run these tests:
// 1. Add `integration_test` to dev_dependencies in pubspec.yaml:
//    integration_test:
//      sdk: flutter
// 2. Run: flutter test integration_test/
//
// These tests require a running backend server and are intended for
// manual verification of end-to-end flows.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soliplex_frontend/app.dart';
import 'package:soliplex_frontend/core/providers/shell_config_provider.dart';
import 'package:soliplex_frontend/features/mission/widgets/approval_banner.dart';
import 'package:soliplex_frontend/features/mission/widgets/approval_dialog.dart';
import 'package:soliplex_frontend/features/mission/widgets/task_progress_compact.dart';
import 'package:soliplex_frontend/features/mission/widgets/task_progress_expanded.dart';
import 'package:soliplex_frontend/soliplex_frontend.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Creates the app wrapped in ProviderScope with test configuration.
  Widget createTestApp() {
    return ProviderScope(
      overrides: [
        shellConfigProvider.overrideWithValue(
          const SoliplexConfig(oauthRedirectScheme: 'ai.soliplex.test'),
        ),
      ],
      child: const SoliplexApp(),
    );
  }

  group('Mission Flow E2E Tests', () {
    testWidgets('Full mission planning flow', (tester) async {
      // Launch app with test configuration
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to deep_planner room
      final roomTile = find.text('deep_planner');
      if (roomTile.evaluate().isNotEmpty) {
        await tester.tap(roomTile);
        await tester.pumpAndSettle();
      }

      // Find and tap the chat input field
      final textField = find.byType(TextField);
      expect(textField, findsWidgets);

      // Enter a prompt
      await tester.enterText(
        textField.first,
        'Create a simple Python hello world script',
      );
      await tester.pumpAndSettle();

      // Tap send button
      final sendButton = find.byIcon(Icons.send);
      if (sendButton.evaluate().isNotEmpty) {
        await tester.tap(sendButton);
        await tester.pumpAndSettle();
      }

      // Wait for task list to appear (may take several seconds)
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Verify task progress widget appears
      expect(find.byType(TaskProgressCompact), findsOneWidget);

      // Wait for mission to progress
      await tester.pumpAndSettle(const Duration(seconds: 30));

      // Tap to expand task list
      final compactWidget = find.byType(TaskProgressCompact);
      if (compactWidget.evaluate().isNotEmpty) {
        await tester.tap(compactWidget);
        await tester.pumpAndSettle();
      }

      // Verify expanded view shows
      expect(find.byType(TaskProgressExpanded), findsOneWidget);

      // Tap collapse button
      final collapseButton = find.byIcon(Icons.expand_less);
      if (collapseButton.evaluate().isNotEmpty) {
        await tester.tap(collapseButton);
        await tester.pumpAndSettle();
      }

      // Verify returns to compact view
      expect(find.byType(TaskProgressCompact), findsOneWidget);
    });

    testWidgets('Approval flow - approve action', (tester) async {
      // Launch app
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to deep_safe_coder room (requires approval)
      final roomTile = find.text('deep_safe_coder');
      if (roomTile.evaluate().isNotEmpty) {
        await tester.tap(roomTile);
        await tester.pumpAndSettle();
      }

      // Find chat input
      final textField = find.byType(TextField);
      expect(textField, findsWidgets);

      // Enter prompt that triggers approval
      await tester.enterText(
        textField.first,
        'Delete all temporary files in /tmp',
      );
      await tester.pumpAndSettle();

      // Tap send
      final sendButton = find.byIcon(Icons.send);
      if (sendButton.evaluate().isNotEmpty) {
        await tester.tap(sendButton);
        await tester.pumpAndSettle();
      }

      // Wait for approval banner to appear
      await tester.pumpAndSettle(const Duration(seconds: 15));

      // Verify approval banner shows
      expect(find.byType(ApprovalBanner), findsOneWidget);

      // Tap "Review & Approve" button
      final reviewButton = find.text('Review & Approve');
      if (reviewButton.evaluate().isNotEmpty) {
        await tester.tap(reviewButton);
        await tester.pumpAndSettle();
      }

      // Verify approval dialog shows
      expect(find.byType(ApprovalDialog), findsOneWidget);

      // Tap approve button in dialog
      final approveButton = find.text('Approve');
      if (approveButton.evaluate().isNotEmpty) {
        await tester.tap(approveButton);
        await tester.pumpAndSettle();
      }

      // Wait for dialog to close
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify banner disappears
      expect(find.byType(ApprovalBanner), findsNothing);

      // Wait for mission to continue
      await tester.pumpAndSettle(const Duration(seconds: 10));
    });

    testWidgets('Approval flow - reject action', (tester) async {
      // Launch app
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to deep_safe_coder room
      final roomTile = find.text('deep_safe_coder');
      if (roomTile.evaluate().isNotEmpty) {
        await tester.tap(roomTile);
        await tester.pumpAndSettle();
      }

      // Find chat input
      final textField = find.byType(TextField);
      expect(textField, findsWidgets);

      // Enter prompt that triggers approval
      await tester.enterText(
        textField.first,
        'Execute rm -rf on test directory',
      );
      await tester.pumpAndSettle();

      // Tap send
      final sendButton = find.byIcon(Icons.send);
      if (sendButton.evaluate().isNotEmpty) {
        await tester.tap(sendButton);
        await tester.pumpAndSettle();
      }

      // Wait for approval banner
      await tester.pumpAndSettle(const Duration(seconds: 15));

      // Verify approval banner shows
      expect(find.byType(ApprovalBanner), findsOneWidget);

      // Tap review button
      final reviewButton = find.text('Review & Approve');
      if (reviewButton.evaluate().isNotEmpty) {
        await tester.tap(reviewButton);
        await tester.pumpAndSettle();
      }

      // Tap reject button in dialog
      final rejectButton = find.text('Reject');
      if (rejectButton.evaluate().isNotEmpty) {
        await tester.tap(rejectButton);
        await tester.pumpAndSettle();
      }

      // Wait for dialog to close
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify banner disappears after rejection
      expect(find.byType(ApprovalBanner), findsNothing);
    });

    testWidgets('Task progress widget expand and collapse', (tester) async {
      // Launch app
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Navigate to a room with an active mission
      final roomTile = find.text('deep_planner');
      if (roomTile.evaluate().isNotEmpty) {
        await tester.tap(roomTile);
        await tester.pumpAndSettle();
      }

      // Start a mission
      final textField = find.byType(TextField);
      if (textField.evaluate().isNotEmpty) {
        await tester.enterText(
          textField.first,
          'List the steps to build a REST API',
        );
        await tester.pumpAndSettle();

        final sendButton = find.byIcon(Icons.send);
        if (sendButton.evaluate().isNotEmpty) {
          await tester.tap(sendButton);
          await tester.pumpAndSettle();
        }
      }

      // Wait for task progress to appear
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Find compact task progress widget
      final compactWidget = find.byType(TaskProgressCompact);
      if (compactWidget.evaluate().isNotEmpty) {
        // Verify compact view elements
        expect(find.byType(LinearProgressIndicator), findsWidgets);

        // Tap to expand
        await tester.tap(compactWidget);
        await tester.pumpAndSettle();

        // Verify expanded view
        expect(find.byType(TaskProgressExpanded), findsOneWidget);

        // Find and tap collapse
        final collapseIcon = find.byIcon(Icons.expand_less);
        if (collapseIcon.evaluate().isNotEmpty) {
          await tester.tap(collapseIcon);
          await tester.pumpAndSettle();
        }

        // Verify back to compact
        expect(find.byType(TaskProgressCompact), findsOneWidget);
      }
    });
  });
}
