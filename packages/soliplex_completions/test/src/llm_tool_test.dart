import 'package:soliplex_completions/soliplex_completions.dart';
import 'package:test/test.dart';

void main() {
  group('LlmToolDef', () {
    test('stores name, description, and parameters', () {
      const tool = LlmToolDef(
        name: 'execute_python',
        description: 'Execute Python code',
        parameters: {
          'type': 'object',
          'properties': {
            'code': {'type': 'string'},
          },
        },
      );

      expect(tool.name, 'execute_python');
      expect(tool.description, 'Execute Python code');
      expect(tool.parameters, isNotNull);
      expect(tool.parameters!['type'], 'object');
    });

    test('parameters can be null', () {
      const tool = LlmToolDef(name: 'noop', description: 'Do nothing');
      expect(tool.parameters, isNull);
    });
  });

  group('LlmToolCall', () {
    test('stores id, name, and arguments', () {
      const call = LlmToolCall(
        id: 'call_1',
        name: 'execute_python',
        arguments: '{"code": "print(42)"}',
      );

      expect(call.id, 'call_1');
      expect(call.name, 'execute_python');
      expect(call.arguments, '{"code": "print(42)"}');
    });
  });

  group('LlmChatMessage', () {
    test('LlmUserMessage holds content', () {
      const msg = LlmUserMessage('Hello');
      expect(msg.content, 'Hello');
      expect(msg, isA<LlmChatMessage>());
    });

    test('LlmAssistantMessage with text only', () {
      const msg = LlmAssistantMessage(content: 'Hi there');
      expect(msg.content, 'Hi there');
      expect(msg.toolCalls, isNull);
    });

    test('LlmAssistantMessage with tool calls', () {
      const msg = LlmAssistantMessage(
        toolCalls: [
          LlmToolCall(id: 'tc_1', name: 'search', arguments: '{"q": "dart"}'),
        ],
      );
      expect(msg.content, isNull);
      expect(msg.toolCalls, hasLength(1));
      expect(msg.toolCalls!.first.name, 'search');
    });

    test('LlmToolResultMessage holds callId and output', () {
      const msg = LlmToolResultMessage(callId: 'tc_1', output: '42');
      expect(msg.callId, 'tc_1');
      expect(msg.output, '42');
    });

    test('LlmSystemMessage holds content', () {
      const msg = LlmSystemMessage('You are helpful.');
      expect(msg.content, 'You are helpful.');
    });

    test('sealed class covers all subtypes via switch', () {
      const messages = <LlmChatMessage>[
        LlmUserMessage('hi'),
        LlmAssistantMessage(content: 'hello'),
        LlmToolResultMessage(callId: 'c1', output: 'ok'),
        LlmSystemMessage('system'),
      ];

      final roles = messages.map((m) {
        return switch (m) {
          LlmUserMessage() => 'user',
          LlmAssistantMessage() => 'assistant',
          LlmToolResultMessage() => 'tool',
          LlmSystemMessage() => 'system',
        };
      }).toList();

      expect(roles, ['user', 'assistant', 'tool', 'system']);
    });
  });
}
