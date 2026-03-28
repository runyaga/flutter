import 'package:meta/meta.dart';

/// Events emitted by an LLM provider during streaming.
///
/// These are Soliplex domain events for observing real-time LLM output.
/// Provider implementations (Anthropic, OpenAI, Ollama) map their
/// SDK-specific streaming types to this sealed hierarchy.
@immutable
sealed class LlmEvent {
  /// Creates an [LlmEvent].
  const LlmEvent();
}

/// A chunk of generated text.
@immutable
class LlmTextDelta extends LlmEvent {
  /// Creates an [LlmTextDelta] with the given [text] fragment.
  const LlmTextDelta(this.text);

  /// The incremental text fragment.
  final String text;
}

/// The complete generated text (end of text stream).
@immutable
class LlmTextDone extends LlmEvent {
  /// Creates an [LlmTextDone] with the full accumulated [text].
  const LlmTextDone(this.text);

  /// The full accumulated response text.
  final String text;
}

/// A tool call has started.
@immutable
class LlmToolCallStart extends LlmEvent {
  /// Creates an [LlmToolCallStart].
  const LlmToolCallStart({required this.callId, required this.name});

  /// The unique identifier for this tool call.
  final String callId;

  /// The name of the tool being called.
  final String name;
}

/// A chunk of tool call arguments.
@immutable
class LlmToolCallArgsDelta extends LlmEvent {
  /// Creates an [LlmToolCallArgsDelta].
  const LlmToolCallArgsDelta({required this.callId, required this.delta});

  /// The tool call this argument chunk belongs to.
  final String callId;

  /// The incremental JSON argument fragment.
  final String delta;
}

/// A tool call is complete with full arguments.
@immutable
class LlmToolCallDone extends LlmEvent {
  /// Creates an [LlmToolCallDone].
  const LlmToolCallDone({required this.callId, required this.arguments});

  /// The tool call that completed.
  final String callId;

  /// The full JSON-encoded arguments string.
  final String arguments;
}

/// The LLM response is complete.
@immutable
class LlmDone extends LlmEvent {
  /// Creates an [LlmDone].
  const LlmDone();
}

/// An error occurred during generation.
@immutable
class LlmError extends LlmEvent {
  /// Creates an [LlmError] with the given [message].
  const LlmError(this.message);

  /// Human-readable error description.
  final String message;
}
