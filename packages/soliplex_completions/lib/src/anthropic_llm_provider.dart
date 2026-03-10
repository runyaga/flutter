import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import 'package:soliplex_completions/src/llm_provider.dart';

/// LLM provider backed by the Anthropic Messages API (Claude).
class AnthropicLlmProvider implements LlmProvider {
  AnthropicLlmProvider({
    required String apiKey,
    this.model = 'claude-sonnet-4-20250514',
    this.defaultMaxTokens = 1024,
  }) : _client = AnthropicClient.withApiKey(apiKey);

  final AnthropicClient _client;

  /// Claude model identifier.
  final String model;

  /// Default max tokens when not specified per-call.
  final int defaultMaxTokens;

  @override
  Future<String> complete(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    final response = await _client.messages.create(
      MessageCreateRequest(
        model: model,
        maxTokens: maxTokens ?? defaultMaxTokens,
        system: systemPrompt != null ? SystemPrompt.text(systemPrompt) : null,
        messages: [InputMessage.user(prompt)],
      ),
    );
    return _extractText(response);
  }

  @override
  Future<String> chat(
    List<LlmMessage> messages, {
    String? systemPrompt,
    int? maxTokens,
  }) async {
    final response = await _client.messages.create(
      MessageCreateRequest(
        model: model,
        maxTokens: maxTokens ?? defaultMaxTokens,
        system: systemPrompt != null ? SystemPrompt.text(systemPrompt) : null,
        messages: messages.map(_toMessage).toList(),
      ),
    );
    return _extractText(response);
  }

  static InputMessage _toMessage(LlmMessage msg) {
    return switch (msg.role) {
      'assistant' => InputMessage.assistant(msg.content),
      _ => InputMessage.user(msg.content),
    };
  }

  static String _extractText(Message response) {
    final buffer = StringBuffer();
    for (final block in response.content) {
      if (block is TextBlock) {
        buffer.write(block.text);
      }
    }
    return buffer.toString();
  }
}
