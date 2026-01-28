import 'package:ag_ui/ag_ui.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:soliplex_client/src/application/json_patch.dart';
import 'package:soliplex_client/src/application/streaming_state.dart';
import 'package:soliplex_client/src/domain/chat_message.dart';
import 'package:soliplex_client/src/domain/conversation.dart';
import 'package:soliplex_client/src/generated/state_delta_event.dart'
    as generated;

/// Result of processing an AG-UI event.
///
/// Contains both the updated domain state (Conversation) and ephemeral
/// streaming state.
@immutable
class EventProcessingResult {
  /// Creates an event processing result.
  const EventProcessingResult({
    required this.conversation,
    required this.streaming,
  });

  /// Updated conversation (domain state).
  final Conversation conversation;

  /// Updated streaming state (ephemeral operation state).
  final StreamingState streaming;
}

/// Processes a single AG-UI event, returning updated domain and streaming
/// state.
///
/// This is a pure function with no side effects. It takes the current state
/// and an event, and returns the new state.
///
/// Example usage:
/// ```dart
/// final result = processEvent(conversation, streaming, event);
/// // result.conversation - updated domain state
/// // result.streaming - updated streaming state
/// ```
EventProcessingResult processEvent(
  Conversation conversation,
  StreamingState streaming,
  BaseEvent event,
) {
  return switch (event) {
    // Run lifecycle events
    RunStartedEvent(:final runId) => EventProcessingResult(
        conversation: conversation.withStatus(Running(runId: runId)),
        streaming: streaming,
      ),
    RunFinishedEvent() => EventProcessingResult(
        conversation: conversation.withStatus(const Completed()),
        streaming: const NotStreaming(),
      ),
    RunErrorEvent(:final message) => EventProcessingResult(
        conversation: conversation.withStatus(Failed(error: message)),
        streaming: const NotStreaming(),
      ),

    // Text message streaming events
    TextMessageStartEvent(:final messageId, :final role) =>
      EventProcessingResult(
        conversation: conversation,
        streaming: Streaming(
          messageId: messageId,
          user: _mapRoleToChatUser(role),
          text: '',
        ),
      ),
    TextMessageContentEvent(:final messageId, :final delta) =>
      _processTextContent(conversation, streaming, messageId, delta),
    TextMessageEndEvent(:final messageId) => _processTextEnd(
        conversation,
        streaming,
        messageId,
      ),

    // Tool call events
    ToolCallStartEvent(:final toolCallId, :final toolCallName) =>
      EventProcessingResult(
        conversation: conversation.withToolCall(
          ToolCallInfo(id: toolCallId, name: toolCallName),
        ),
        streaming: streaming,
      ),
    ToolCallEndEvent(:final toolCallId) => EventProcessingResult(
        conversation: conversation.copyWith(
          toolCalls: conversation.toolCalls
              .where((tc) => tc.id != toolCallId)
              .toList(),
        ),
        streaming: streaming,
      ),

    // All other events pass through unchanged
    _ => EventProcessingResult(
        conversation: conversation,
        streaming: streaming,
      ),
  };
}

// TODO(cleanup): Extract streaming guard pattern if a third streaming event
// type is added. Both _processTextContent and _processTextEnd share the
// "check if streaming matches messageId, else return unchanged" pattern.
EventProcessingResult _processTextContent(
  Conversation conversation,
  StreamingState streaming,
  String messageId,
  String delta,
) {
  if (streaming is Streaming && streaming.messageId == messageId) {
    return EventProcessingResult(
      conversation: conversation,
      streaming: streaming.appendDelta(delta),
    );
  }
  return EventProcessingResult(
    conversation: conversation,
    streaming: streaming,
  );
}

EventProcessingResult _processTextEnd(
  Conversation conversation,
  StreamingState streaming,
  String messageId,
) {
  if (streaming is Streaming && streaming.messageId == messageId) {
    final newMessage = TextMessage.create(
      id: messageId,
      user: streaming.user,
      text: streaming.text,
    );
    return EventProcessingResult(
      conversation: conversation.withAppendedMessage(newMessage),
      streaming: const NotStreaming(),
    );
  }
  return EventProcessingResult(
    conversation: conversation,
    streaming: streaming,
  );
}

/// Maps AG-UI TextMessageRole to domain ChatUser.
ChatUser _mapRoleToChatUser(TextMessageRole role) {
  return switch (role) {
    TextMessageRole.user => ChatUser.user,
    TextMessageRole.assistant => ChatUser.assistant,
    TextMessageRole.system => ChatUser.system,
    TextMessageRole.developer => ChatUser.system,
  };
}

/// Logger for state delta processing.
final _stateDeltaLogger = Logger('StateDeltaProcessor');

/// Result of processing a state delta event.
@immutable
class StateDeltaResult {
  /// Creates a state delta result.
  const StateDeltaResult({
    required this.state,
    this.error,
  });

  /// Creates a successful result.
  const StateDeltaResult.success(this.state) : error = null;

  /// Creates a failed result with unchanged state.
  const StateDeltaResult.failure(this.state, this.error);

  /// The current state (may be unchanged if error occurred).
  final Map<String, dynamic> state;

  /// Error message if processing failed, null otherwise.
  final String? error;

  /// Whether the state was updated successfully.
  bool get isSuccess => error == null;
}

/// Processes STATE_DELTA events and applies them to mission state.
///
/// This processor maintains a mutable state map that represents the current
/// mission state. State delta events contain JSON Patch operations that
/// modify this state.
///
/// Usage:
/// ```dart
/// final processor = StateDeltaProcessor();
///
/// // Process incoming state delta events
/// for (final event in events) {
///   final result = processor.processStateDelta(event);
///   if (!result.isSuccess) {
///     print('Warning: ${result.error}');
///   }
/// }
///
/// // Access current state
/// final currentState = processor.state;
/// ```
class StateDeltaProcessor {
  /// Creates a state delta processor with optional initial state.
  StateDeltaProcessor([Map<String, dynamic>? initialState])
      : _state = initialState ?? {};

  /// Current mission state.
  Map<String, dynamic> _state;

  /// Returns an immutable view of the current state.
  Map<String, dynamic> get state => Map.unmodifiable(_state);

  /// Resets the state to empty or the given initial state.
  void reset([Map<String, dynamic>? initialState]) {
    _state = initialState ?? {};
  }

  /// Processes a STATE_DELTA event.
  ///
  /// The event should contain:
  /// - `delta_path`: Path to the value to modify (e.g., "/tasks/0/status")
  /// - `delta_type`: Operation type (add, remove, replace)
  /// - `delta_value`: New value for add/replace operations
  ///
  /// Returns a [StateDeltaResult] with the updated state or error info.
  StateDeltaResult processStateDelta(generated.StateDeltaEvent event) {
    return processStateDeltaFromMap({
      'delta_path': event.deltaPath,
      'delta_type': event.deltaType,
      'delta_value': event.deltaValue,
    });
  }

  /// Processes a state delta from a raw map.
  ///
  /// Useful when working with raw SSE data before parsing into StateDeltaEvent.
  StateDeltaResult processStateDeltaFromMap(Map<String, dynamic> delta) {
    final path = delta['delta_path'] as String?;
    final type = delta['delta_type'] as String?;

    if (path == null) {
      _stateDeltaLogger.warning('STATE_DELTA missing delta_path');
      return StateDeltaResult.failure(
        _state,
        'STATE_DELTA event missing delta_path field',
      );
    }

    if (type == null) {
      _stateDeltaLogger.warning('STATE_DELTA missing delta_type');
      return StateDeltaResult.failure(
        _state,
        'STATE_DELTA event missing delta_type field',
      );
    }

    try {
      final result = JsonPatcher.applyDelta(_state, delta);

      if (result.isSuccess) {
        _state = result.state;
        return StateDeltaResult.success(_state);
      } else {
        _stateDeltaLogger
            .warning('Failed to apply state delta: ${result.error}');
        return StateDeltaResult.failure(_state, result.error);
      }
    } on FormatException catch (e) {
      _stateDeltaLogger.warning('Malformed state delta: $e');
      return StateDeltaResult.failure(_state, 'Malformed delta format: $e');
    } catch (e) {
      _stateDeltaLogger.severe('Unexpected error applying state delta: $e');
      return StateDeltaResult.failure(
        _state,
        'Unexpected error: $e',
      );
    }
  }

  /// Processes a list of state deltas in sequence.
  ///
  /// Applies all deltas, collecting any errors encountered.
  /// Processing continues even if individual deltas fail.
  List<StateDeltaResult> processStateDeltasFromMaps(
    List<Map<String, dynamic>> deltas,
  ) {
    return deltas.map(processStateDeltaFromMap).toList();
  }

  /// Gets a value at the specified path in the current state.
  ///
  /// Returns null if the path doesn't exist.
  dynamic getAtPath(String path) {
    if (path.isEmpty || path == '/') return _state;

    final segments =
        path.startsWith('/') ? path.substring(1).split('/') : path.split('/');

    dynamic current = _state;
    for (final segment in segments) {
      if (current is Map<String, dynamic>) {
        if (!current.containsKey(segment)) return null;
        current = current[segment];
      } else if (current is List) {
        final index = int.tryParse(segment);
        if (index == null || index < 0 || index >= current.length) return null;
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }
}
