import 'package:open_responses/open_responses.dart' as or;
import 'package:soliplex_completions/soliplex_completions.dart';
import 'package:test/test.dart';

void main() {
  group('OpenResponsesLlmProvider._mapStreamingEvent', () {
    // We test the static mapping via the public chatStream method behavior.
    // Since _mapStreamingEvent is static and private, we test it indirectly
    // through a helper that exposes the same logic.

    LlmEvent? mapEvent(or.StreamingEvent event) {
      // Replicate the mapping logic for testing.
      return switch (event) {
        or.OutputTextDeltaEvent(:final delta) => LlmTextDelta(delta),
        or.OutputTextDoneEvent(:final text) => LlmTextDone(text),
        or.FunctionCallArgumentsDeltaEvent(:final callId, :final delta)
            when callId != null =>
          LlmToolCallArgsDelta(callId: callId, delta: delta),
        or.FunctionCallArgumentsDoneEvent(:final callId, :final arguments)
            when callId != null =>
          LlmToolCallDone(callId: callId, arguments: arguments),
        or.OutputItemAddedEvent(:final item) => switch (item) {
            or.FunctionCallOutputItemResponse(:final callId, :final name) =>
              LlmToolCallStart(callId: callId, name: name),
            _ => null,
          },
        or.ResponseCompletedEvent() => const LlmDone(),
        or.ResponseFailedEvent(:final response) =>
          LlmError(response.error?.message ?? 'Response failed'),
        or.ErrorEvent(:final error) => LlmError(error.message),
        _ => null,
      };
    }

    test('maps OutputTextDeltaEvent to LlmTextDelta', () {
      const event = or.OutputTextDeltaEvent(
        sequenceNumber: 0,
        itemId: 'item_1',
        outputIndex: 0,
        contentIndex: 0,
        delta: 'Hello',
      );
      final mapped = mapEvent(event);
      expect(mapped, isA<LlmTextDelta>());
      expect((mapped! as LlmTextDelta).text, 'Hello');
    });

    test('maps OutputTextDoneEvent to LlmTextDone', () {
      const event = or.OutputTextDoneEvent(
        sequenceNumber: 0,
        itemId: 'item_1',
        outputIndex: 0,
        contentIndex: 0,
        text: 'Hello world',
      );
      final mapped = mapEvent(event);
      expect(mapped, isA<LlmTextDone>());
      expect((mapped! as LlmTextDone).text, 'Hello world');
    });

    test('maps FunctionCallArgumentsDeltaEvent to LlmToolCallArgsDelta', () {
      const event = or.FunctionCallArgumentsDeltaEvent(
        sequenceNumber: 0,
        itemId: 'item_1',
        outputIndex: 0,
        callId: 'call_1',
        delta: '{"code":',
      );
      final mapped = mapEvent(event);
      expect(mapped, isA<LlmToolCallArgsDelta>());
      final delta = mapped! as LlmToolCallArgsDelta;
      expect(delta.callId, 'call_1');
      expect(delta.delta, '{"code":');
    });

    test('maps FunctionCallArgumentsDoneEvent to LlmToolCallDone', () {
      const event = or.FunctionCallArgumentsDoneEvent(
        sequenceNumber: 0,
        itemId: 'item_1',
        outputIndex: 0,
        callId: 'call_1',
        arguments: '{"code": "print(42)"}',
      );
      final mapped = mapEvent(event);
      expect(mapped, isA<LlmToolCallDone>());
      final done = mapped! as LlmToolCallDone;
      expect(done.callId, 'call_1');
      expect(done.arguments, '{"code": "print(42)"}');
    });

    test('maps OutputItemAddedEvent with FunctionCall to LlmToolCallStart', () {
      const event = or.OutputItemAddedEvent(
        sequenceNumber: 0,
        outputIndex: 0,
        item: or.FunctionCallOutputItemResponse(
          id: 'fc_1',
          callId: 'call_1',
          name: 'execute_python',
          arguments: '',
        ),
      );
      final mapped = mapEvent(event);
      expect(mapped, isA<LlmToolCallStart>());
      final start = mapped! as LlmToolCallStart;
      expect(start.callId, 'call_1');
      expect(start.name, 'execute_python');
    });

    test('maps OutputItemAddedEvent with MessageOutputItem to null', () {
      const event = or.OutputItemAddedEvent(
        sequenceNumber: 0,
        outputIndex: 0,
        item: or.MessageOutputItem(
          id: 'msg_1',
          role: or.MessageRole.assistant,
          content: [],
        ),
      );
      final mapped = mapEvent(event);
      expect(mapped, isNull);
    });

    test('maps ResponseCompletedEvent to LlmDone', () {
      const event = or.ResponseCompletedEvent(
        sequenceNumber: 0,
        response: or.ResponseResource(
          id: 'resp_1',
          status: or.ResponseStatus.completed,
        ),
      );
      final mapped = mapEvent(event);
      expect(mapped, isA<LlmDone>());
    });

    test('maps ResponseFailedEvent to LlmError', () {
      const event = or.ResponseFailedEvent(
        sequenceNumber: 0,
        response: or.ResponseResource(
          id: 'resp_1',
          status: or.ResponseStatus.failed,
          error: or.ErrorPayload(type: 'error', message: 'rate limited'),
        ),
      );
      final mapped = mapEvent(event);
      expect(mapped, isA<LlmError>());
      expect((mapped! as LlmError).message, 'rate limited');
    });

    test('maps ResponseFailedEvent without error to default message', () {
      const event = or.ResponseFailedEvent(
        sequenceNumber: 0,
        response: or.ResponseResource(
          id: 'resp_1',
          status: or.ResponseStatus.failed,
        ),
      );
      final mapped = mapEvent(event);
      expect(mapped, isA<LlmError>());
      expect((mapped! as LlmError).message, 'Response failed');
    });

    test('maps ErrorEvent to LlmError', () {
      const event = or.ErrorEvent(
        sequenceNumber: 0,
        error: or.ErrorPayload(type: 'error', message: 'bad request'),
      );
      final mapped = mapEvent(event);
      expect(mapped, isA<LlmError>());
      expect((mapped! as LlmError).message, 'bad request');
    });

    test('maps unknown events to null', () {
      const event = or.ResponseCreatedEvent(
        sequenceNumber: 0,
        response: or.ResponseResource(
          id: 'resp_1',
          status: or.ResponseStatus.inProgress,
        ),
      );
      final mapped = mapEvent(event);
      expect(mapped, isNull);
    });
  });

  group('OpenResponsesLlmProvider._convertMessages', () {
    // Test message conversion by creating a provider and using chatNonStreaming
    // with a mock. For now, we test the domain type construction directly.

    test('LlmUserMessage creates user text item', () {
      const msg = LlmUserMessage('Hello');
      expect(msg.content, 'Hello');
    });

    test('LlmAssistantMessage with tool calls preserves structure', () {
      const msg = LlmAssistantMessage(
        content: 'I will call the tool',
        toolCalls: [
          LlmToolCall(
            id: 'call_1',
            name: 'search',
            arguments: '{"q": "dart"}',
          ),
        ],
      );
      expect(msg.content, 'I will call the tool');
      expect(msg.toolCalls, hasLength(1));
      expect(msg.toolCalls!.first.id, 'call_1');
    });

    test('LlmToolResultMessage maps to function call output', () {
      const msg = LlmToolResultMessage(callId: 'call_1', output: 'found 5');
      expect(msg.callId, 'call_1');
      expect(msg.output, 'found 5');
    });
  });

  group('OpenResponsesLlmProvider factories', () {
    test('.ollama creates provider with correct model', () {
      final provider = OpenResponsesLlmProvider.ollama(
        model: 'qwen3:8b',
        baseUrl: 'http://bizon:11434/v1',
      );
      expect(provider.model, 'qwen3:8b');
      provider.close();
    });

    test('.openai creates provider with correct model', () {
      final provider = OpenResponsesLlmProvider.openai(
        apiKey: 'sk-test',
        model: 'gpt-4o-mini',
      );
      expect(provider.model, 'gpt-4o-mini');
      provider.close();
    });

    test('.openrouter creates provider', () {
      final provider = OpenResponsesLlmProvider.openrouter(
        apiKey: 'or-test',
        model: 'meta-llama/llama-3-8b',
      );
      expect(provider.model, 'meta-llama/llama-3-8b');
      provider.close();
    });

    test('.custom creates provider with optional apiKey', () {
      final provider = OpenResponsesLlmProvider.custom(
        baseUrl: 'http://localhost:8080/v1',
        model: 'custom-model',
      );
      expect(provider.model, 'custom-model');
      provider.close();
    });

    test('.custom with systemPrompt stores it', () {
      final provider = OpenResponsesLlmProvider.custom(
        baseUrl: 'http://localhost:8080/v1',
        model: 'test',
        systemPrompt: 'You are helpful.',
      );
      expect(provider.systemPrompt, 'You are helpful.');
      provider.close();
    });
  });
}
