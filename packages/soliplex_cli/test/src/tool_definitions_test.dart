import 'dart:convert';

import 'package:soliplex_cli/src/tool_definitions.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:test/test.dart';

void main() {
  late ToolRegistry registry;

  setUp(() {
    registry = buildDemoToolRegistry();
  });

  group('buildDemoToolRegistry', () {
    test('registers two tools', () {
      expect(registry.length, equals(2));
    });

    test('contains secret_number', () {
      expect(registry.contains('secret_number'), isTrue);
    });

    test('contains echo', () {
      expect(registry.contains('echo'), isTrue);
    });

    test('secret_number returns 42', () async {
      final result = await registry.execute(
        const ToolCallInfo(id: 'tc-1', name: 'secret_number'),
      );
      expect(result, equals('42'));
    });

    test('echo returns text argument', () async {
      final result = await registry.execute(
        ToolCallInfo(
          id: 'tc-2',
          name: 'echo',
          arguments: jsonEncode({'text': 'hello'}),
        ),
      );
      expect(result, equals('hello'));
    });

    test('echo returns empty string when no arguments', () async {
      final result = await registry.execute(
        const ToolCallInfo(id: 'tc-3', name: 'echo'),
      );
      expect(result, isEmpty);
    });

    test('secret_number has parameters JSON schema', () {
      final tool = registry.lookup('secret_number');
      expect(tool.definition.parameters, isA<Map<String, dynamic>>());
    });

    test('echo has parameters JSON schema with text property', () {
      final tool = registry.lookup('echo');
      final params = tool.definition.parameters as Map<String, dynamic>;
      final props = params['properties'] as Map<String, dynamic>;
      expect(props, contains('text'));
    });
  });
}
