import 'package:soliplex_completions/soliplex_completions.dart';
import 'package:test/test.dart';

void main() {
  group('LlmEvent sealed hierarchy', () {
    test('LlmTextDelta holds text', () {
      const event = LlmTextDelta('Hello');
      expect(event.text, 'Hello');
      expect(event, isA<LlmEvent>());
    });

    test('LlmTextDone holds complete text', () {
      const event = LlmTextDone('Hello world');
      expect(event.text, 'Hello world');
    });

    test('LlmToolCallStart holds callId and name', () {
      const event = LlmToolCallStart(
        callId: 'call_1',
        name: 'execute_python',
      );
      expect(event.callId, 'call_1');
      expect(event.name, 'execute_python');
    });

    test('LlmToolCallArgsDelta holds callId and delta', () {
      const event = LlmToolCallArgsDelta(
        callId: 'call_1',
        delta: '{"code":',
      );
      expect(event.callId, 'call_1');
      expect(event.delta, '{"code":');
    });

    test('LlmToolCallDone holds callId and full arguments', () {
      const event = LlmToolCallDone(
        callId: 'call_1',
        arguments: '{"code": "print(42)"}',
      );
      expect(event.callId, 'call_1');
      expect(event.arguments, '{"code": "print(42)"}');
    });

    test('LlmDone is singleton-like', () {
      const a = LlmDone();
      const b = LlmDone();
      expect(identical(a, b), isTrue);
    });

    test('LlmError holds message', () {
      const event = LlmError('connection refused');
      expect(event.message, 'connection refused');
    });

    test('exhaustive switch covers all subtypes', () {
      const events = <LlmEvent>[
        LlmTextDelta('a'),
        LlmTextDone('a'),
        LlmToolCallStart(callId: 'c', name: 'n'),
        LlmToolCallArgsDelta(callId: 'c', delta: 'd'),
        LlmToolCallDone(callId: 'c', arguments: 'a'),
        LlmDone(),
        LlmError('e'),
      ];

      final types = events.map((e) {
        return switch (e) {
          LlmTextDelta() => 'text_delta',
          LlmTextDone() => 'text_done',
          LlmToolCallStart() => 'tool_start',
          LlmToolCallArgsDelta() => 'tool_args_delta',
          LlmToolCallDone() => 'tool_done',
          LlmDone() => 'done',
          LlmError() => 'error',
        };
      }).toList();

      expect(types, [
        'text_delta',
        'text_done',
        'tool_start',
        'tool_args_delta',
        'tool_done',
        'done',
        'error',
      ]);
    });
  });
}
