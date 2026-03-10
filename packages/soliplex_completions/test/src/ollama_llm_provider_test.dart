import 'package:soliplex_completions/soliplex_completions.dart';
import 'package:test/test.dart';

void main() {
  group('OllamaLlmProvider', () {
    test('default model is llama3.2', () {
      final provider = OllamaLlmProvider();
      expect(provider.model, 'llama3.2');
    });

    test('custom model is accepted', () {
      final provider = OllamaLlmProvider(model: 'qwen2.5-coder:1.5b');
      expect(provider.model, 'qwen2.5-coder:1.5b');
    });

    test('custom baseUrl is accepted', () {
      final provider = OllamaLlmProvider(
        baseUrl: 'http://gpu-server:11434/api',
      );
      expect(provider, isA<LlmProvider>());
    });

    test('implements LlmProvider', () {
      final provider = OllamaLlmProvider();
      expect(provider, isA<LlmProvider>());
    });
  });
}
