import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_frontend/features/chat/widgets/tool_execution_card.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;

void main() {
  group('ToolExecutionCard', () {
    testWidgets('shows tool name and running status', (tester) async {
      final execution = ToolExecution(
        id: 'call-1',
        toolName: 'execute_code',
        arguments: {'code': 'print("hello")'},
        status: ToolExecutionStatus.running,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ToolExecutionCard(execution: execution)),
        ),
      );

      expect(find.text('execute_code'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows completed status with checkmark', (tester) async {
      final execution = ToolExecution(
        id: 'call-2',
        toolName: 'write_file',
        arguments: {'path': '/tmp/test.txt'},
        status: ToolExecutionStatus.completed,
        output: 'File written successfully',
        duration: const Duration(milliseconds: 150),
        startedAt: DateTime.now().subtract(const Duration(milliseconds: 150)),
        completedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ToolExecutionCard(execution: execution)),
        ),
      );

      expect(find.text('write_file'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows failed status with error icon', (tester) async {
      final execution = ToolExecution(
        id: 'call-3',
        toolName: 'read_file',
        arguments: {'path': '/nonexistent'},
        status: ToolExecutionStatus.failed,
        error: 'File not found',
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ToolExecutionCard(execution: execution)),
        ),
      );

      expect(find.text('read_file'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('shows pending status', (tester) async {
      final execution = ToolExecution(
        id: 'call-4',
        toolName: 'search',
        arguments: {'query': 'test'},
        status: ToolExecutionStatus.pending,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ToolExecutionCard(execution: execution)),
        ),
      );

      expect(find.text('search'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byIcon(Icons.pending), findsOneWidget);
    });

    testWidgets('expands to show arguments on tap', (tester) async {
      final execution = ToolExecution(
        id: 'call-5',
        toolName: 'write_file',
        arguments: {'path': '/tmp/test.txt', 'content': 'hello world'},
        status: ToolExecutionStatus.completed,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolExecutionCard(execution: execution),
            ),
          ),
        ),
      );

      // Initially collapsed - arguments not visible
      expect(find.text('Arguments:'), findsNothing);

      // Tap to expand
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Now shows arguments
      expect(find.text('Arguments:'), findsOneWidget);
      expect(find.textContaining('/tmp/test.txt'), findsOneWidget);
      expect(find.textContaining('hello world'), findsOneWidget);
    });

    testWidgets('expands to show output', (tester) async {
      final execution = ToolExecution(
        id: 'call-6',
        toolName: 'execute_code',
        arguments: {'code': 'print("hi")'},
        status: ToolExecutionStatus.completed,
        output: 'hi\n',
        duration: const Duration(milliseconds: 50),
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolExecutionCard(execution: execution),
            ),
          ),
        ),
      );

      // Initially collapsed
      expect(find.text('Output:'), findsNothing);

      // Tap to expand
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Now shows output
      expect(find.text('Output:'), findsOneWidget);
      expect(find.textContaining('hi'), findsWidgets);
    });

    testWidgets('shows error in red styling', (tester) async {
      final execution = ToolExecution(
        id: 'call-7',
        toolName: 'execute_code',
        arguments: {'code': 'raise Exception("oops")'},
        status: ToolExecutionStatus.failed,
        error: 'Exception: oops',
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolExecutionCard(execution: execution),
            ),
          ),
        ),
      );

      // Tap to expand
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Shows error label (not output)
      expect(find.text('Error:'), findsOneWidget);
      expect(find.text('Output:'), findsNothing);
      expect(find.textContaining('Exception: oops'), findsOneWidget);
    });

    testWidgets('shows duration when available', (tester) async {
      final execution = ToolExecution(
        id: 'call-8',
        toolName: 'slow_operation',
        arguments: {},
        status: ToolExecutionStatus.completed,
        duration: const Duration(milliseconds: 2345),
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolExecutionCard(execution: execution),
            ),
          ),
        ),
      );

      // Tap to expand
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Shows duration
      expect(find.textContaining('Duration:'), findsOneWidget);
      expect(find.textContaining('2345ms'), findsOneWidget);
    });

    testWidgets('shows description when provided', (tester) async {
      final execution = ToolExecution(
        id: 'call-9',
        toolName: 'analyze_data',
        description: 'Analyzing dataset for patterns',
        arguments: {'dataset': 'sales.csv'},
        status: ToolExecutionStatus.running,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ToolExecutionCard(execution: execution)),
        ),
      );

      expect(find.text('analyze_data'), findsOneWidget);
      expect(find.text('Analyzing dataset for patterns'), findsOneWidget);
    });

    testWidgets('collapses when tapped again', (tester) async {
      final execution = ToolExecution(
        id: 'call-10',
        toolName: 'test_tool',
        arguments: {'key': 'value'},
        status: ToolExecutionStatus.completed,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolExecutionCard(execution: execution),
            ),
          ),
        ),
      );

      // Initially collapsed
      expect(find.text('Arguments:'), findsNothing);

      // Tap to expand
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.text('Arguments:'), findsOneWidget);

      // Tap again to collapse
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.text('Arguments:'), findsNothing);
    });

    testWidgets('truncates long argument values', (tester) async {
      // Create a string longer than 100 characters
      final longValue = 'x' * 150;
      final execution = ToolExecution(
        id: 'call-11',
        toolName: 'process_data',
        arguments: {'data': longValue},
        status: ToolExecutionStatus.completed,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ToolExecutionCard(execution: execution),
            ),
          ),
        ),
      );

      // Tap to expand
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Should show truncated value (full 150-char value should NOT appear)
      expect(find.textContaining(longValue), findsNothing);
      // But should show the truncation indicator
      expect(find.textContaining('...'), findsOneWidget);
    });
  });
}
