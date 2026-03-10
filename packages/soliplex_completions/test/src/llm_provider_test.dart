import 'package:soliplex_completions/soliplex_completions.dart';
import 'package:test/test.dart';

/// Fake provider for contract testing.
class FakeLlmProvider implements LlmProvider {
  final List<String> completeCalls = [];
  final List<List<LlmMessage>> chatCalls = [];

  String nextResponse = 'fake response';

  @override
  Future<String> complete(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    completeCalls.add(prompt);
    return nextResponse;
  }

  @override
  Future<String> chat(
    List<LlmMessage> messages, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    chatCalls.add(messages);
    return nextResponse;
  }
}

void main() {
  group('LlmProvider contract', () {
    late FakeLlmProvider provider;

    setUp(() {
      provider = FakeLlmProvider();
    });

    test('complete returns response text', () async {
      provider.nextResponse = 'Hello from LLM';
      final result = await provider.complete('Hi');
      expect(result, 'Hello from LLM');
      expect(provider.completeCalls, ['Hi']);
    });

    test('chat returns response text', () async {
      provider.nextResponse = 'Chat response';
      final messages = <LlmMessage>[
        (role: 'user', content: 'Hello'),
        (role: 'assistant', content: 'Hi!'),
        (role: 'user', content: 'How are you?'),
      ];
      final result = await provider.chat(messages);
      expect(result, 'Chat response');
      expect(provider.chatCalls, hasLength(1));
      expect(provider.chatCalls.first, hasLength(3));
    });

    test('complete passes systemPrompt and maxTokens', () async {
      final result = await provider.complete(
        'test',
        systemPrompt: 'Be helpful',
        maxTokens: 512,
      );
      expect(result, 'fake response');
    });

    test('chat passes systemPrompt and maxTokens', () async {
      final result = await provider.chat(
        [(role: 'user', content: 'test')],
        systemPrompt: 'Be helpful',
        maxTokens: 512,
      );
      expect(result, 'fake response');
    });
  });
}
