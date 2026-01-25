import 'package:soliplex_client/src/application/agui_event_processor.dart';
import 'package:soliplex_client/src/application/json_patch.dart';
import 'package:soliplex_client/src/generated/state_delta_event.dart';
import 'package:test/test.dart';

void main() {
  group('StateDeltaProcessor', () {
    late StateDeltaProcessor processor;

    setUp(() {
      processor = StateDeltaProcessor();
    });

    group('malformed patch handling', () {
      test('missing delta_path returns failure with preserved state', () {
        processor = StateDeltaProcessor({'existing': 'data'});
        final result = processor.processStateDeltaFromMap({
          'delta_type': 'replace',
          'delta_value': 'new_value',
        });

        expect(result.isSuccess, isFalse);
        expect(result.error, contains('delta_path'));
        expect(result.state['existing'], equals('data'));
      });

      test('missing delta_type returns failure with preserved state', () {
        processor = StateDeltaProcessor({'existing': 'data'});
        final result = processor.processStateDeltaFromMap({
          'delta_path': '/foo',
          'delta_value': 'new_value',
        });

        expect(result.isSuccess, isFalse);
        expect(result.error, contains('delta_type'));
        expect(result.state['existing'], equals('data'));
      });

      test('invalid path format returns failure with preserved state', () {
        processor = StateDeltaProcessor({'existing': 'data'});
        final result = processor.processStateDeltaFromMap({
          'delta_path': 'no-leading-slash',
          'delta_type': 'replace',
          'delta_value': 'new_value',
        });

        expect(result.isSuccess, isFalse);
        expect(result.state['existing'], equals('data'));
      });

      test('non-existent path for replace returns failure', () {
        processor = StateDeltaProcessor({'foo': 'bar'});
        final result = processor.processStateDeltaFromMap({
          'delta_path': '/nonexistent/nested/path',
          'delta_type': 'replace',
          'delta_value': 'value',
        });

        expect(result.isSuccess, isFalse);
        expect(result.state['foo'], equals('bar'));
      });

      test('invalid array index returns failure with preserved state', () {
        processor = StateDeltaProcessor({
          'items': ['a', 'b', 'c'],
        });
        final result = processor.processStateDeltaFromMap({
          'delta_path': '/items/99',
          'delta_type': 'replace',
          'delta_value': 'x',
        });

        expect(result.isSuccess, isFalse);
        expect((result.state['items'] as List).length, equals(3));
      });

      test('unknown operation type returns failure', () {
        processor = StateDeltaProcessor({'foo': 'bar'});
        final result = processor.processStateDeltaFromMap({
          'delta_path': '/foo',
          'delta_type': 'unknown_op',
          'delta_value': 'value',
        });

        expect(result.isSuccess, isFalse);
        expect(result.error, contains('Unknown'));
        expect(result.state['foo'], equals('bar'));
      });

      test('multiple malformed patches in sequence preserve state', () {
        processor = StateDeltaProcessor({'counter': 0});

        // First: valid patch
        var result = processor.processStateDeltaFromMap({
          'delta_path': '/counter',
          'delta_type': 'replace',
          'delta_value': 1,
        });
        expect(result.isSuccess, isTrue);
        expect(result.state['counter'], equals(1));

        // Second: malformed patch
        result = processor.processStateDeltaFromMap({
          'delta_type': 'replace', // missing path
          'delta_value': 2,
        });
        expect(result.isSuccess, isFalse);
        expect(result.state['counter'], equals(1)); // Preserved from previous

        // Third: another valid patch
        result = processor.processStateDeltaFromMap({
          'delta_path': '/counter',
          'delta_type': 'replace',
          'delta_value': 3,
        });
        expect(result.isSuccess, isTrue);
        expect(result.state['counter'], equals(3));
      });
    });

    group('valid operations', () {
      test('add operation creates new key', () {
        final result = processor.processStateDeltaFromMap({
          'delta_path': '/newKey',
          'delta_type': 'add',
          'delta_value': 'newValue',
        });

        expect(result.isSuccess, isTrue);
        expect(result.state['newKey'], equals('newValue'));
      });

      test('replace operation updates existing key', () {
        processor = StateDeltaProcessor({'key': 'oldValue'});
        final result = processor.processStateDeltaFromMap({
          'delta_path': '/key',
          'delta_type': 'replace',
          'delta_value': 'newValue',
        });

        expect(result.isSuccess, isTrue);
        expect(result.state['key'], equals('newValue'));
      });

      test('remove operation deletes key', () {
        processor = StateDeltaProcessor({'key': 'value', 'other': 'data'});
        final result = processor.processStateDeltaFromMap({
          'delta_path': '/key',
          'delta_type': 'remove',
        });

        expect(result.isSuccess, isTrue);
        expect(result.state.containsKey('key'), isFalse);
        expect(result.state['other'], equals('data'));
      });

      test('nested path operations work correctly', () {
        processor = StateDeltaProcessor({
          'task_list': {
            'tasks': [
              {'id': '1', 'status': 'pending'},
              {'id': '2', 'status': 'pending'},
            ],
          },
        });

        final result = processor.processStateDeltaFromMap({
          'delta_path': '/task_list/tasks/0/status',
          'delta_type': 'replace',
          'delta_value': 'completed',
        });

        expect(result.isSuccess, isTrue);
        final tasks = result.state['task_list']['tasks'] as List;
        expect(tasks[0]['status'], equals('completed'));
        expect(tasks[1]['status'], equals('pending'));
      });
    });

    group('batch processing', () {
      test('processStateDeltasFromMaps applies all patches', () {
        processor = StateDeltaProcessor({'a': 1, 'b': 2});

        final results = processor.processStateDeltasFromMaps([
          {'delta_path': '/a', 'delta_type': 'replace', 'delta_value': 10},
          {'delta_path': '/c', 'delta_type': 'add', 'delta_value': 30},
          {'delta_type': 'invalid'}, // Malformed - should fail but not stop
          {'delta_path': '/b', 'delta_type': 'remove'},
        ]);

        expect(results.length, equals(4));
        expect(results[0].isSuccess, isTrue);
        expect(results[1].isSuccess, isTrue);
        expect(results[2].isSuccess, isFalse);
        expect(results[3].isSuccess, isTrue);

        // Final state should reflect all successful patches
        expect(processor.state['a'], equals(10));
        expect(processor.state['c'], equals(30));
        expect(processor.state.containsKey('b'), isFalse);
      });
    });

    group('getAtPath', () {
      test('returns value at simple path', () {
        processor = StateDeltaProcessor({'foo': 'bar'});
        expect(processor.getAtPath('/foo'), equals('bar'));
      });

      test('returns value at nested path', () {
        processor = StateDeltaProcessor({
          'deep': {
            'nested': {'value': 42},
          },
        });
        expect(processor.getAtPath('/deep/nested/value'), equals(42));
      });

      test('returns null for non-existent path', () {
        processor = StateDeltaProcessor({'foo': 'bar'});
        expect(processor.getAtPath('/nonexistent'), isNull);
      });

      test('returns entire state for root path', () {
        processor = StateDeltaProcessor({'foo': 'bar'});
        expect(processor.getAtPath('/'), equals({'foo': 'bar'}));
      });
    });
  });

  group('JsonPatcher', () {
    group('malformed patch handling', () {
      test('missing op returns failure', () {
        final result = JsonPatcher.apply(
          {'key': 'value'},
          {'path': '/key', 'value': 'new'},
        );

        expect(result.isSuccess, isFalse);
        expect(result.error, contains('op'));
        expect(result.state['key'], equals('value'));
      });

      test('missing path returns failure', () {
        final result = JsonPatcher.apply(
          {'key': 'value'},
          {'op': 'replace', 'value': 'new'},
        );

        expect(result.isSuccess, isFalse);
        expect(result.error, contains('path'));
        expect(result.state['key'], equals('value'));
      });

      test('move without from returns failure', () {
        final result = JsonPatcher.apply(
          {'a': 1, 'b': 2},
          {'op': 'move', 'path': '/c'},
        );

        expect(result.isSuccess, isFalse);
        expect(result.error, contains('from'));
      });

      test('copy without from returns failure', () {
        final result = JsonPatcher.apply(
          {'a': 1},
          {'op': 'copy', 'path': '/b'},
        );

        expect(result.isSuccess, isFalse);
        expect(result.error, contains('from'));
      });

      test('original state is never mutated on failure', () {
        final original = {'key': 'value', 'nested': {'data': 123}};
        final originalCopy = Map<String, dynamic>.from(original);

        JsonPatcher.apply(original, {'op': 'replace', 'path': '/invalid/path'});

        expect(original, equals(originalCopy));
      });
    });

    group('RFC 6902 operations', () {
      test('add to array with - appends', () {
        final result = JsonPatcher.apply(
          {
            'items': ['a', 'b'],
          },
          {'op': 'add', 'path': '/items/-', 'value': 'c'},
        );

        expect(result.isSuccess, isTrue);
        expect(result.state['items'], equals(['a', 'b', 'c']));
      });

      test('add to array at index inserts', () {
        final result = JsonPatcher.apply(
          {
            'items': ['a', 'c'],
          },
          {'op': 'add', 'path': '/items/1', 'value': 'b'},
        );

        expect(result.isSuccess, isTrue);
        expect(result.state['items'], equals(['a', 'b', 'c']));
      });

      test('move relocates value', () {
        final result = JsonPatcher.apply(
          {'source': 'value', 'target': null},
          {'op': 'move', 'from': '/source', 'path': '/target'},
        );

        expect(result.isSuccess, isTrue);
        expect(result.state.containsKey('source'), isFalse);
        expect(result.state['target'], equals('value'));
      });

      test('copy duplicates value', () {
        final result = JsonPatcher.apply(
          {'source': 'value'},
          {'op': 'copy', 'from': '/source', 'path': '/target'},
        );

        expect(result.isSuccess, isTrue);
        expect(result.state['source'], equals('value'));
        expect(result.state['target'], equals('value'));
      });

      test('remove from array shifts indices', () {
        final result = JsonPatcher.apply(
          {
            'items': ['a', 'b', 'c'],
          },
          {'op': 'remove', 'path': '/items/1'},
        );

        expect(result.isSuccess, isTrue);
        expect(result.state['items'], equals(['a', 'c']));
      });
    });

    group('applyAll', () {
      test('applies multiple patches in sequence', () {
        final result = JsonPatcher.applyAll(
          {'counter': 0},
          [
            {'op': 'replace', 'path': '/counter', 'value': 1},
            {'op': 'add', 'path': '/new', 'value': 'field'},
            {'op': 'replace', 'path': '/counter', 'value': 2},
          ],
        );

        expect(result.isSuccess, isTrue);
        expect(result.state['counter'], equals(2));
        expect(result.state['new'], equals('field'));
      });

      test('stops on first error', () {
        final result = JsonPatcher.applyAll(
          {'counter': 0},
          [
            {'op': 'replace', 'path': '/counter', 'value': 1},
            {'op': 'replace', 'path': '/invalid/path', 'value': 'x'},
            {'op': 'replace', 'path': '/counter', 'value': 3},
          ],
        );

        expect(result.isSuccess, isFalse);
        // State should be at point of failure (first patch applied)
        expect(result.state['counter'], equals(1));
      });
    });
  });
}
