import 'package:dart_monty/dart_monty.dart';
import 'package:dart_monty/dart_monty_testing.dart';
import 'package:soliplex_interpreter_monty/src/schema_executor.dart';
import 'package:test/test.dart';

const _usage = MontyResourceUsage(
  memoryBytesUsed: 1024,
  timeElapsedMs: 10,
  stackDepthUsed: 5,
);

const _toolValidatorCode = '''
def validate_tool(raw):
    result = {}
    result['kind'] = str(raw.get('kind', ''))
    result['tool_name'] = str(raw.get('tool_name', ''))
    result['allow_mcp'] = bool(raw.get('allow_mcp', False))
    return result
''';

MontyResult _dictResult(Map<String, MontyValue> entries) => MontyResult(
  value: MontyDict(entries),
  usage: _usage,
);

void main() {
  late MockMontyPlatform mock;
  late SchemaExecutor executor;

  setUp(() {
    mock = MockMontyPlatform();
    executor = SchemaExecutor(platform: mock);
  });

  group('loadSchemas', () {
    test('makes schema names available', () {
      executor.loadSchemas({'tool': _toolValidatorCode});

      expect(executor.schemaNames, contains('tool'));
      expect(executor.hasSchemas, isTrue);
    });

    test('hasSchemas is false when empty', () {
      expect(executor.hasSchemas, isFalse);
    });

    test('merges multiple loads', () {
      executor
        ..loadSchemas({'tool': _toolValidatorCode})
        ..loadSchemas({'room': 'def validate_room(raw):\n    return raw\n'});

      expect(executor.schemaNames, containsAll(['tool', 'room']));
    });
  });

  group('validate', () {
    test('returns validated dict from Python function', () async {
      executor.loadSchemas({'tool': _toolValidatorCode});

      mock.runResult = _dictResult({
        'kind': const MontyString('search'),
        'tool_name': const MontyString('tools.search'),
        'allow_mcp': const MontyBool(false),
      });

      final result = await executor.validate('tool', {
        'kind': 'search',
        'tool_name': 'tools.search',
        'allow_mcp': false,
      });

      expect(result['kind'], 'search');
      expect(result['tool_name'], 'tools.search');
      expect(result['allow_mcp'], false);
    });

    test('composes correct Python code', () async {
      executor.loadSchemas({'tool': _toolValidatorCode});

      mock.runResult = _dictResult({});

      await executor.validate('tool', <String, Object?>{});

      expect(mock.history.lastRunCode, contains('raw = {}'));
      expect(mock.history.lastRunCode, contains('def validate_tool(raw):'));
      expect(mock.history.lastRunCode, contains('validate_tool(raw)'));
    });

    test('inlines raw JSON as Python literal', () async {
      executor.loadSchemas({'tool': _toolValidatorCode});

      mock.runResult = _dictResult({});

      await executor.validate('tool', <String, Object?>{'kind': 'test'});

      expect(mock.history.lastRunCode, contains("raw = {'kind': 'test'}"));
    });

    test('throws ArgumentError for unknown schema', () async {
      expect(
        () => executor.validate('unknown', <String, Object?>{}),
        throwsArgumentError,
      );
    });

    test('throws MontyException when Python code fails', () async {
      executor.loadSchemas({'tool': _toolValidatorCode});

      mock.runResult = const MontyResult(
        value: MontyNone(),
        error: MontyException(message: 'NameError: raw is not defined'),
        usage: _usage,
      );

      expect(
        () => executor.validate('tool', <String, Object?>{}),
        throwsA(isA<MontyException>()),
      );
    });
  });

  group('multiple schemas', () {
    test('validates different schemas independently', () async {
      executor.loadSchemas({
        'tool': _toolValidatorCode,
        'room': '''
def validate_room(raw):
    result = {}
    result['name'] = str(raw.get('name', ''))
    return result
''',
      });

      mock.runResult = _dictResult({'name': const MontyString('general')});

      final result = await executor.validate('room', {'name': 'general'});
      expect(result['name'], 'general');

      expect(mock.history.lastRunCode, contains('validate_room(raw)'));
      expect(mock.history.lastRunCode, isNot(contains('validate_tool')));
    });
  });
}
