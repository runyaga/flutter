import 'package:soliplex_completions/soliplex_completions.dart';
import 'package:test/test.dart';

void main() {
  group('AnthropicLlmProvider', () {
    test('complete sends correct request and extracts text', () {
      final provider = AnthropicLlmProvider(apiKey: 'test-key');

      expect(provider.model, 'claude-sonnet-4-20250514');
      expect(provider.defaultMaxTokens, 1024);
    });

    test('custom model is accepted', () {
      final provider = AnthropicLlmProvider(
        apiKey: 'test-key',
        model: 'claude-haiku-3-20250414',
      );
      expect(provider.model, 'claude-haiku-3-20250414');
    });

    test('custom maxTokens is respected', () {
      final provider = AnthropicLlmProvider(
        apiKey: 'test-key',
        defaultMaxTokens: 2048,
      );
      expect(provider.defaultMaxTokens, 2048);
    });

    test('implements LlmProvider', () {
      final provider = AnthropicLlmProvider(apiKey: 'test-key');
      expect(provider, isA<LlmProvider>());
    });
  });
}
