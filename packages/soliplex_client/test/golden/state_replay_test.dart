import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/src/application/agui_event_processor.dart';

/// Golden state replay tests.
///
/// These tests replay captured event sequences and verify the final state
/// matches expected values. This ensures the StateDeltaProcessor correctly
/// handles real-world event patterns.
void main() {
  group('Golden state replay', () {
    // Use path relative to the package, not the test runner cwd
    final packageRoot = Directory.current.path.endsWith('soliplex_client')
        ? Directory.current.path
        : '${Directory.current.path}/packages/soliplex_client';
    final fixturesDir = Directory('$packageRoot/test/golden/fixtures');

    // Verify fixtures directory exists
    test('fixtures directory exists', () {
      expect(fixturesDir.existsSync(), isTrue,
          reason: 'Golden fixtures directory should exist');
    });

    // Dynamically load and test each fixture
    if (fixturesDir.existsSync()) {
      for (final file in fixturesDir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.json')) continue;

        final fixtureName = file.path.split('/').last.replaceAll('.json', '');

        test('replays fixture: $fixtureName', () async {
          // Load fixture
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;

          // Extract events and expected state
          final events = (data['events'] as List).cast<Map<String, dynamic>>();
          final expectedState = data['expected_state'] as Map<String, dynamic>;
          final description = data['description'] as String?;

          if (description != null) {
            // ignore: avoid_print
            print('Testing: $description');
          }

          // Create processor and replay events
          final processor = StateDeltaProcessor();

          for (final eventJson in events) {
            // Each event contains delta_path, delta_type, delta_value
            processor.processStateDeltaFromMap(eventJson);
          }

          // Verify final state matches expected
          expect(
            processor.state,
            equals(expectedState),
            reason: 'Final state should match expected after replaying '
                '${events.length} events',
          );
        });
      }
    }
  });

  group('Specific golden scenarios', () {
    test('task list progression: pending -> in_progress -> completed', () {
      final processor = StateDeltaProcessor();

      // Initialize task list
      processor.processStateDeltaFromMap({
        'delta_path': '/task_list',
        'delta_type': 'add',
        'delta_value': {'title': 'Test Tasks', 'tasks': <dynamic>[]},
      });

      // Add a task
      processor.processStateDeltaFromMap({
        'delta_path': '/task_list/tasks/-',
        'delta_type': 'add',
        'delta_value': {
          'id': 'task-1',
          'content': 'Do something',
          'status': 'pending',
        },
      });

      // Verify pending state
      expect(processor.state['task_list']['tasks'][0]['status'], 'pending');

      // Progress to in_progress
      processor.processStateDeltaFromMap({
        'delta_path': '/task_list/tasks/0/status',
        'delta_type': 'replace',
        'delta_value': 'in_progress',
      });

      expect(
        processor.state['task_list']['tasks'][0]['status'],
        'in_progress',
      );

      // Complete the task
      processor.processStateDeltaFromMap({
        'delta_path': '/task_list/tasks/0/status',
        'delta_type': 'replace',
        'delta_value': 'completed',
      });

      expect(processor.state['task_list']['tasks'][0]['status'], 'completed');
    });

    test('multiple tasks with interleaved updates', () {
      final processor = StateDeltaProcessor();

      // Initialize
      processor.processStateDeltaFromMap({
        'delta_path': '/task_list',
        'delta_type': 'add',
        'delta_value': {'title': 'Multi-task Test', 'tasks': <dynamic>[]},
      });

      // Add multiple tasks
      processor.processStateDeltaFromMap({
        'delta_path': '/task_list/tasks/-',
        'delta_type': 'add',
        'delta_value': {
          'id': 'task-1',
          'content': 'First',
          'status': 'pending'
        },
      });

      processor.processStateDeltaFromMap({
        'delta_path': '/task_list/tasks/-',
        'delta_type': 'add',
        'delta_value': {
          'id': 'task-2',
          'content': 'Second',
          'status': 'pending',
        },
      });

      processor.processStateDeltaFromMap({
        'delta_path': '/task_list/tasks/-',
        'delta_type': 'add',
        'delta_value': {
          'id': 'task-3',
          'content': 'Third',
          'status': 'pending'
        },
      });

      // Verify all added
      expect(processor.state['task_list']['tasks'].length, 3);

      // Update middle task
      processor.processStateDeltaFromMap({
        'delta_path': '/task_list/tasks/1/status',
        'delta_type': 'replace',
        'delta_value': 'in_progress',
      });

      expect(processor.state['task_list']['tasks'][0]['status'], 'pending');
      expect(processor.state['task_list']['tasks'][1]['status'], 'in_progress');
      expect(processor.state['task_list']['tasks'][2]['status'], 'pending');
    });

    test('approval request lifecycle', () {
      final processor = StateDeltaProcessor();

      // Add pending approval
      processor.processStateDeltaFromMap({
        'delta_path': '/pending_approval',
        'delta_type': 'add',
        'delta_value': {
          'id': 'approval-1',
          'action': 'delete_file',
          'description': 'Delete important.txt',
          'status': 'pending',
        },
      });

      expect(processor.state['pending_approval']['status'], 'pending');

      // User approves
      processor.processStateDeltaFromMap({
        'delta_path': '/pending_approval/status',
        'delta_type': 'replace',
        'delta_value': 'approved',
      });

      expect(processor.state['pending_approval']['status'], 'approved');

      // Clear approval after processing
      processor.processStateDeltaFromMap({
        'delta_path': '/pending_approval',
        'delta_type': 'remove',
        'delta_value': null,
      });

      expect(processor.state.containsKey('pending_approval'), isFalse);
    });

    test('nested path updates', () {
      final processor = StateDeltaProcessor();

      // Create nested structure
      processor.processStateDeltaFromMap({
        'delta_path': '/mission',
        'delta_type': 'add',
        'delta_value': {
          'id': 'mission-1',
          'metadata': {
            'created_by': 'user-1',
            'tags': ['important', 'urgent'],
          },
        },
      });

      // Update deeply nested value
      processor.processStateDeltaFromMap({
        'delta_path': '/mission/metadata/tags/-',
        'delta_type': 'add',
        'delta_value': 'reviewed',
      });

      expect(
        (processor.state['mission']['metadata']['tags'] as List).length,
        3,
      );
      expect(
        processor.state['mission']['metadata']['tags'][2],
        'reviewed',
      );
    });

    test('replace entire state', () {
      final processor = StateDeltaProcessor({'old': 'data'});

      processor.processStateDeltaFromMap({
        'delta_path': '/',
        'delta_type': 'replace',
        'delta_value': {'new': 'state', 'completely': 'different'},
      });

      expect(processor.state.containsKey('old'), isFalse);
      expect(processor.state['new'], 'state');
      expect(processor.state['completely'], 'different');
    });
  });

  group('Error handling', () {
    test('invalid path does not crash', () {
      final processor = StateDeltaProcessor();

      // Try to update non-existent path
      final result = processor.processStateDeltaFromMap({
        'delta_path': '/nonexistent/deeply/nested/path',
        'delta_type': 'replace',
        'delta_value': 'value',
      });

      // Should fail gracefully
      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
    });

    test('malformed delta is handled gracefully', () {
      final processor = StateDeltaProcessor();

      // Missing delta_path
      final result1 = processor.processStateDeltaFromMap({
        'delta_type': 'add',
        'delta_value': 'value',
      });
      expect(result1.isSuccess, isFalse);

      // Missing delta_type
      final result2 = processor.processStateDeltaFromMap({
        'delta_path': '/test',
        'delta_value': 'value',
      });
      expect(result2.isSuccess, isFalse);
    });

    test('state preserved after error', () {
      final processor = StateDeltaProcessor({'preserved': 'value'});

      // Try invalid operation
      processor.processStateDeltaFromMap({
        'delta_path': '/invalid/path',
        'delta_type': 'replace',
        'delta_value': 'ignored',
      });

      // Original state should be preserved
      expect(processor.state['preserved'], 'value');
    });
  });

  group('Reset functionality', () {
    test('reset clears state', () {
      final processor = StateDeltaProcessor({'initial': 'state'});
      expect(processor.state['initial'], 'state');

      processor.reset();
      expect(processor.state, isEmpty);
    });

    test('reset with new initial state', () {
      final processor = StateDeltaProcessor({'old': 'state'});

      processor.reset({'new': 'initial'});
      expect(processor.state.containsKey('old'), isFalse);
      expect(processor.state['new'], 'initial');
    });
  });

  group('getAtPath functionality', () {
    test('retrieves root state', () {
      final processor = StateDeltaProcessor({'key': 'value'});
      expect(processor.getAtPath('/'), processor.state);
      expect(processor.getAtPath(''), processor.state);
    });

    test('retrieves nested values', () {
      final processor = StateDeltaProcessor({
        'level1': {
          'level2': {
            'value': 42,
          },
        },
      });

      expect(processor.getAtPath('/level1/level2/value'), 42);
    });

    test('retrieves array elements', () {
      final processor = StateDeltaProcessor({
        'items': ['a', 'b', 'c'],
      });

      expect(processor.getAtPath('/items/0'), 'a');
      expect(processor.getAtPath('/items/2'), 'c');
    });

    test('returns null for non-existent paths', () {
      final processor = StateDeltaProcessor({'exists': 'yes'});

      expect(processor.getAtPath('/nonexistent'), isNull);
      expect(processor.getAtPath('/exists/deeply/nested'), isNull);
    });
  });
}
