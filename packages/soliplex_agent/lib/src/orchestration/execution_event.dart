import 'package:meta/meta.dart';
import 'package:soliplex_client/soliplex_client.dart';

/// Granular execution events for UI observability.
///
/// Emitted by `AgentSession` via the `lastExecutionEvent` signal so that
/// UI layers can react to fine-grained progress (text streaming, tool
/// execution, terminal states) without polling `RunState`.
@immutable
sealed class ExecutionEvent {
  const ExecutionEvent();
}

/// A delta of streamed assistant text.
class TextDelta extends ExecutionEvent {
  const TextDelta({required this.delta});

  /// The incremental text fragment.
  final String delta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TextDelta && delta == other.delta;

  @override
  int get hashCode => delta.hashCode;
}

/// The model has started a thinking/reasoning phase.
class ThinkingStarted extends ExecutionEvent {
  const ThinkingStarted();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ThinkingStarted;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// A delta of streamed thinking content.
class ThinkingContent extends ExecutionEvent {
  const ThinkingContent({required this.delta});

  /// The incremental thinking text fragment.
  final String delta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThinkingContent && delta == other.delta;

  @override
  int get hashCode => delta.hashCode;
}

/// A server-side tool call has started (observed, not executed locally).
class ServerToolCallStarted extends ExecutionEvent {
  const ServerToolCallStarted({
    required this.toolName,
    required this.toolCallId,
  });

  final String toolName;
  final String toolCallId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerToolCallStarted &&
          toolName == other.toolName &&
          toolCallId == other.toolCallId;

  @override
  int get hashCode => Object.hash(toolName, toolCallId);
}

/// A server-side tool call has completed.
class ServerToolCallCompleted extends ExecutionEvent {
  const ServerToolCallCompleted({
    required this.toolCallId,
    required this.result,
  });

  final String toolCallId;
  final String result;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerToolCallCompleted &&
          toolCallId == other.toolCallId &&
          result == other.result;

  @override
  int get hashCode => Object.hash(toolCallId, result);
}

/// A client-side tool execution has started.
class ClientToolExecuting extends ExecutionEvent {
  const ClientToolExecuting({
    required this.toolName,
    required this.toolCallId,
  });

  final String toolName;
  final String toolCallId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientToolExecuting &&
          toolName == other.toolName &&
          toolCallId == other.toolCallId;

  @override
  int get hashCode => Object.hash(toolName, toolCallId);
}

/// A client-side tool execution has completed.
class ClientToolCompleted extends ExecutionEvent {
  const ClientToolCompleted({
    required this.toolCallId,
    required this.result,
    required this.status,
  });

  final String toolCallId;
  final String result;
  final ToolCallStatus status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientToolCompleted &&
          toolCallId == other.toolCallId &&
          result == other.result &&
          status == other.status;

  @override
  int get hashCode => Object.hash(toolCallId, result, status);
}

/// The run completed successfully.
class RunCompleted extends ExecutionEvent {
  const RunCompleted();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RunCompleted;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// The run failed with an error.
class RunFailed extends ExecutionEvent {
  const RunFailed({required this.error});

  final String error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RunFailed && error == other.error;

  @override
  int get hashCode => error.hashCode;
}

/// The run was cancelled.
class RunCancelled extends ExecutionEvent {
  const RunCancelled();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RunCancelled;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// AG-UI state update received from the backend.
class StateUpdated extends ExecutionEvent {
  const StateUpdated({required this.aguiState});

  final Map<String, dynamic> aguiState;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StateUpdated && _mapEquals(aguiState, other.aguiState);

  @override
  int get hashCode => Object.hashAll([
        for (final key in aguiState.keys.toList()..sort())
          Object.hash(key, aguiState[key]),
      ]);
}

bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (a[key] != b[key]) return false;
  }
  return true;
}

/// Step progress event for multi-step pipelines.
class StepProgress extends ExecutionEvent {
  const StepProgress({required this.stepName});

  final String stepName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepProgress && stepName == other.stepName;

  @override
  int get hashCode => stepName.hashCode;
}

/// Extension point for third-party plugins to emit custom events.
///
/// Use this when a `SessionExtension` needs to communicate
/// domain-specific progress to the UI without modifying the core
/// sealed class hierarchy.
class CustomExecutionEvent extends ExecutionEvent {
  const CustomExecutionEvent({
    required this.type,
    required this.payload,
  });

  /// Identifier for the event kind (e.g. `'monty.execution_started'`).
  final String type;

  /// Arbitrary event payload.
  final Map<String, dynamic> payload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomExecutionEvent &&
          type == other.type &&
          _mapEquals(payload, other.payload);

  @override
  int get hashCode => Object.hash(
        type,
        Object.hashAll([
          for (final key in payload.keys.toList()..sort())
            Object.hash(key, payload[key]),
        ]),
      );
}
