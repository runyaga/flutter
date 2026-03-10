/// Events emitted by an LLM provider during streaming.
///
/// These are Soliplex's domain events — NOT open_responses types.
/// The mapping from open_responses StreamingEvent to LlmEvent
/// happens inside OpenResponsesLlmProvider.
sealed class LlmEvent {
  const LlmEvent();
}

/// A chunk of generated text.
class LlmTextDelta extends LlmEvent {
  const LlmTextDelta(this.text);
  final String text;
}

/// The complete generated text (end of text stream).
class LlmTextDone extends LlmEvent {
  const LlmTextDone(this.text);
  final String text;
}

/// A tool call has started.
class LlmToolCallStart extends LlmEvent {
  const LlmToolCallStart({required this.callId, required this.name});
  final String callId;
  final String name;
}

/// A chunk of tool call arguments.
class LlmToolCallArgsDelta extends LlmEvent {
  const LlmToolCallArgsDelta({required this.callId, required this.delta});
  final String callId;
  final String delta;
}

/// A tool call is complete with full arguments.
class LlmToolCallDone extends LlmEvent {
  const LlmToolCallDone({required this.callId, required this.arguments});
  final String callId;
  final String arguments;
}

/// The LLM response is complete.
class LlmDone extends LlmEvent {
  const LlmDone();
}

/// An error occurred during generation.
class LlmError extends LlmEvent {
  const LlmError(this.message);
  final String message;
}
