import 'package:soliplex_completions/soliplex_completions.dart';
import 'package:test/test.dart';

void main() {
  group('OpenAiLlmProvider', () {
    test('default model is gpt-4o', () {
      final provider = OpenAiLlmProvider(apiKey: 'test-key');
      expect(provider.model, 'gpt-4o');
    });

    test('custom baseUrl is accepted', () {
      final provider = OpenAiLlmProvider(
        apiKey: 'test-key',
        baseUrl: 'http://localhost:8080/v1',
      );
      expect(provider, isA<LlmProvider>());
    });

    test('custom maxTokens is respected', () {
      final provider = OpenAiLlmProvider(
        apiKey: 'test-key',
        defaultMaxTokens: 4096,
      );
      expect(provider.defaultMaxTokens, 4096);
    });

    test('implements LlmProvider', () {
      final provider = OpenAiLlmProvider(apiKey: 'test-key');
      expect(provider, isA<LlmProvider>());
    });
  });
}
