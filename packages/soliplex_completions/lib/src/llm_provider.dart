/// A message in a multi-turn conversation.
typedef LlmMessage = ({String role, String content});

/// Contract for LLM completion providers.
///
/// Implementations wrap specific SDK clients (Anthropic, OpenAI, Ollama)
/// and expose a uniform interface. The returned functions can be passed
/// directly to `LlmPlugin.fromCallbacks()` in `soliplex_scripting`.
abstract interface class LlmProvider {
  /// Send a single prompt and return the response text.
  Future<String> complete(
    String prompt, {
    String? systemPrompt,
    int? maxTokens,
  });

  /// Send a multi-turn conversation and return the response text.
  Future<String> chat(
    List<LlmMessage> messages, {
    String? systemPrompt,
    int? maxTokens,
  });
}
