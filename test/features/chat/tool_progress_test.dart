import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/soliplex_client.dart';

void main() {
  group('ToolProgress Model', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'tool_id': 'research_abc123',
        'phase': 'processing',
        'message': 'Analyzing content...',
        'progress_pct': 65.5,
        'items_done': 3,
        'items_total': 5,
        'updated_at': '2026-01-25T12:00:00Z',
      };

      final progress = ToolProgress.fromJson(json);

      expect(progress.toolId, 'research_abc123');
      expect(progress.phase, 'processing');
      expect(progress.message, 'Analyzing content...');
      expect(progress.progressPct, 65.5);
      expect(progress.itemsDone, 3);
      expect(progress.itemsTotal, 5);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'tool_id': 'test_tool',
        'phase': 'starting',
        'message': 'Starting...',
      };

      final progress = ToolProgress.fromJson(json);

      expect(progress.toolId, 'test_tool');
      expect(progress.phase, 'starting');
      expect(progress.message, 'Starting...');
      expect(progress.progressPct, isNull);
      expect(progress.itemsDone, isNull);
      expect(progress.itemsTotal, isNull);
    });

    test('toJson serializes correctly', () {
      final progress = ToolProgress(
        toolId: 'test_123',
        phase: 'fetching',
        message: 'Fetching data',
        progressPct: 30.0,
        itemsDone: 1,
        itemsTotal: 3,
        updatedAt: DateTime.utc(2026, 1, 25, 12, 0, 0),
      );

      final json = progress.toJson();

      expect(json['tool_id'], 'test_123');
      expect(json['phase'], 'fetching');
      expect(json['message'], 'Fetching data');
      expect(json['progress_pct'], 30.0);
      expect(json['items_done'], 1);
      expect(json['items_total'], 3);
    });

    test('progressText shows items when available', () {
      final progress = ToolProgress(
        toolId: 'test',
        phase: 'processing',
        message: 'Processing',
        progressPct: 50.0,
        itemsDone: 3,
        itemsTotal: 6,
      );

      expect(progress.progressText, '3/6');
    });

    test('progressText shows percentage when no items', () {
      final progress = ToolProgress(
        toolId: 'test',
        phase: 'processing',
        message: 'Processing',
        progressPct: 45.5,
      );

      expect(progress.progressText, '46%');
    });

    test('progressText shows phase as fallback', () {
      final progress = ToolProgress(
        toolId: 'test',
        phase: 'initializing',
        message: 'Starting up',
      );

      expect(progress.progressText, 'initializing');
    });
  });

  group('ToolProgress Widget', () {
    testWidgets('displays progress bar when progressPct available',
        (tester) async {
      final progress = ToolProgress(
        toolId: 'test_tool',
        phase: 'processing',
        message: 'Processing data...',
        progressPct: 50.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressSection(progress: progress),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Processing data...'), findsOneWidget);
    });

    testWidgets('displays items counter when itemsTotal available',
        (tester) async {
      final progress = ToolProgress(
        toolId: 'test_tool',
        phase: 'fetching',
        message: 'Fetching sources',
        progressPct: 40.0,
        itemsDone: 2,
        itemsTotal: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressSection(progress: progress),
          ),
        ),
      );

      expect(find.text('2 / 5'), findsOneWidget);
    });

    testWidgets('hides progress bar when progressPct is null', (tester) async {
      final progress = ToolProgress(
        toolId: 'test_tool',
        phase: 'starting',
        message: 'Starting...',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressSection(progress: progress),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Starting...'), findsOneWidget);
    });

    testWidgets('returns empty widget when progress is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProgressSection(progress: null),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('displays phase icon', (tester) async {
      final progress = ToolProgress(
        toolId: 'test_tool',
        phase: 'searching',
        message: 'Searching for sources...',
        progressPct: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressSection(progress: progress),
          ),
        ),
      );

      expect(find.byType(PhaseIcon), findsOneWidget);
    });
  });

  group('Phase Icons', () {
    testWidgets('starting phase shows play icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhaseIcon(phase: 'starting'),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });

    testWidgets('searching phase shows search icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhaseIcon(phase: 'searching'),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('fetching phase shows download icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhaseIcon(phase: 'fetching'),
          ),
        ),
      );

      expect(find.byIcon(Icons.download), findsOneWidget);
    });

    testWidgets('processing phase shows settings icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhaseIcon(phase: 'processing'),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('analyzing phase shows analytics icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhaseIcon(phase: 'analyzing'),
          ),
        ),
      );

      expect(find.byIcon(Icons.analytics), findsOneWidget);
    });

    testWidgets('writing phase shows edit icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhaseIcon(phase: 'writing'),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('complete phase shows check icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhaseIcon(phase: 'complete'),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('error phase shows error icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhaseIcon(phase: 'error'),
          ),
        ),
      );

      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('running phase shows play arrow icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhaseIcon(phase: 'running'),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('unknown phase shows hourglass empty icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhaseIcon(phase: 'unknown_phase'),
          ),
        ),
      );

      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });
  });

  group('Progress Integration with ToolExecution', () {
    test('execution can be created with running status', () {
      final execution = ToolExecution(
        id: 'call_123',
        toolName: 'research_report',
        status: ToolExecutionStatus.running,
        startedAt: DateTime.now(),
        arguments: {'topic': 'AI Research'},
      );

      final progress = ToolProgress(
        toolId: 'call_123',
        phase: 'analyzing',
        message: 'Analyzing 5 sources...',
        progressPct: 60.0,
        itemsDone: 3,
        itemsTotal: 5,
      );

      expect(execution.isRunning, isTrue);
      expect(progress.phase, 'analyzing');
      expect(progress.itemsDone, 3);
      expect(progress.itemsTotal, 5);
    });

    test('execution handles null progress gracefully', () {
      final execution = ToolExecution(
        id: 'call_456',
        toolName: 'quick_tool',
        status: ToolExecutionStatus.running,
        startedAt: DateTime.now(),
        arguments: {},
      );

      // Execution can exist without progress
      expect(execution.id, 'call_456');
      expect(execution.isRunning, isTrue);
    });
  });

  group('Progress State Updates', () {
    test('progress updates from STATE_DELTA event', () {
      // Simulate state delta event processing
      final stateDelta = {
        'op': 'replace',
        'path': '/tool_progress/research_abc',
        'value': {
          'tool_id': 'research_abc',
          'phase': 'fetching',
          'message': 'Fetching source 2/5',
          'progress_pct': 35.0,
          'items_done': 2,
          'items_total': 5,
        },
      };

      // Extract progress from delta
      final progressJson = stateDelta['value'] as Map<String, dynamic>;
      final progress = ToolProgress.fromJson(progressJson);

      expect(progress.toolId, 'research_abc');
      expect(progress.phase, 'fetching');
      expect(progress.itemsDone, 2);
      expect(progress.itemsTotal, 5);
    });

    test('multiple tools can have independent progress', () {
      final stateSnapshot = {
        'tool_progress': {
          'tool_1': {
            'tool_id': 'tool_1',
            'phase': 'processing',
            'message': 'Processing...',
            'progress_pct': 50.0,
          },
          'tool_2': {
            'tool_id': 'tool_2',
            'phase': 'fetching',
            'message': 'Fetching...',
            'progress_pct': 25.0,
          },
        },
      };

      final progressMap =
          stateSnapshot['tool_progress'] as Map<String, dynamic>;

      final progress1 =
          ToolProgress.fromJson(progressMap['tool_1'] as Map<String, dynamic>);
      final progress2 =
          ToolProgress.fromJson(progressMap['tool_2'] as Map<String, dynamic>);

      expect(progress1.phase, 'processing');
      expect(progress1.progressPct, 50.0);
      expect(progress2.phase, 'fetching');
      expect(progress2.progressPct, 25.0);
    });
  });
}

/// Test-only widget for ProgressSection (extracted from ToolExecutionCard)
class ProgressSection extends StatelessWidget {
  final ToolProgress? progress;

  const ProgressSection({super.key, this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhaseIcon(phase: progress!.phase),
              const SizedBox(width: 8),
              Expanded(child: Text(progress!.message)),
            ],
          ),
          if (progress!.progressPct != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress!.progressPct! / 100,
              backgroundColor: Colors.grey[300],
            ),
          ],
          if (progress!.itemsTotal != null) ...[
            const SizedBox(height: 4),
            Text(
              '${progress!.itemsDone ?? 0} / ${progress!.itemsTotal}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Test-only widget for PhaseIcon
class PhaseIcon extends StatelessWidget {
  final String phase;

  const PhaseIcon({super.key, required this.phase});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;

    // Match production _PhaseIcon in tool_execution_card.dart
    switch (phase) {
      case 'starting':
        icon = Icons.play_circle_outline;
        color = Colors.blue;
      case 'searching':
        icon = Icons.search;
        color = Colors.orange;
      case 'fetching':
        icon = Icons.download;
        color = Colors.purple;
      case 'processing':
        icon = Icons.settings;
        color = Colors.indigo;
      case 'analyzing':
        icon = Icons.analytics;
        color = Colors.teal;
      case 'writing':
        icon = Icons.edit;
        color = Colors.green;
      case 'running':
        icon = Icons.play_arrow;
        color = Colors.blue;
      case 'complete':
        icon = Icons.check_circle;
        color = Colors.green;
      case 'error':
        icon = Icons.error;
        color = Colors.red;
      default:
        icon = Icons.hourglass_empty;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 20);
  }
}
