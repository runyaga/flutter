import 'package:meta/meta.dart';

import 'package:soliplex_agent/src/models/failure_reason.dart';
import 'package:soliplex_agent/src/models/thread_key.dart';
import 'package:soliplex_client/soliplex_client.dart';

/// State of a single agent run lifecycle.
///
/// Use pattern matching for exhaustive handling:
/// ```dart
/// switch (state) {
///   case IdleState():
///     // No active run
///   case RunningState(:final threadKey, :final runId):
///     // Stream connected
///   case CompletedState(:final threadKey, :final runId):
///     // RunFinished received
///   case FailedState(:final reason, :final error):
///     // Error occurred
///   case CancelledState(:final threadKey):
///     // User cancelled
/// }
/// ```
@immutable
sealed class RunState {
  const RunState();
}

/// No active run.
@immutable
class IdleState extends RunState {
  const IdleState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IdleState;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'IdleState()';
}

/// Stream connected and receiving events.
@immutable
class RunningState extends RunState {
  const RunningState({
    required this.threadKey,
    required this.runId,
    required this.conversation,
    required this.streaming,
  });

  /// The thread this run belongs to.
  final ThreadKey threadKey;

  /// The backend run ID.
  final String runId;

  /// Current domain state of the conversation.
  final Conversation conversation;

  /// Current ephemeral streaming state.
  final StreamingState streaming;

  /// Creates a copy with the given fields replaced.
  RunningState copyWith({
    Conversation? conversation,
    StreamingState? streaming,
  }) {
    return RunningState(
      threadKey: threadKey,
      runId: runId,
      conversation: conversation ?? this.conversation,
      streaming: streaming ?? this.streaming,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunningState &&
          threadKey == other.threadKey &&
          runId == other.runId &&
          conversation == other.conversation &&
          streaming == other.streaming;

  @override
  int get hashCode => Object.hash(threadKey, runId, conversation, streaming);

  @override
  String toString() => 'RunningState(runId: $runId, threadKey: $threadKey)';
}

/// Run completed successfully (RunFinished received).
@immutable
class CompletedState extends RunState {
  const CompletedState({
    required this.threadKey,
    required this.runId,
    required this.conversation,
  });

  /// The thread this run belonged to.
  final ThreadKey threadKey;

  /// The backend run ID.
  final String runId;

  /// Final conversation state at completion.
  final Conversation conversation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompletedState &&
          threadKey == other.threadKey &&
          runId == other.runId &&
          conversation == other.conversation;

  @override
  int get hashCode => Object.hash(threadKey, runId, conversation);

  @override
  String toString() => 'CompletedState(runId: $runId, threadKey: $threadKey)';
}

/// Run failed with a classified error.
@immutable
class FailedState extends RunState {
  const FailedState({
    required this.threadKey,
    required this.reason,
    required this.error,
    this.conversation,
  });

  /// The thread this run belonged to.
  final ThreadKey threadKey;

  /// Classification of why the run failed.
  final FailureReason reason;

  /// Human-readable error description.
  final String error;

  /// Conversation state at time of failure, if available.
  final Conversation? conversation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailedState &&
          threadKey == other.threadKey &&
          reason == other.reason &&
          error == other.error &&
          conversation == other.conversation;

  @override
  int get hashCode => Object.hash(threadKey, reason, error, conversation);

  @override
  String toString() => 'FailedState(reason: $reason, error: $error, '
      'threadKey: $threadKey)';
}

/// Run was cancelled by the user.
@immutable
class CancelledState extends RunState {
  const CancelledState({
    required this.threadKey,
    this.conversation,
  });

  /// The thread this run belonged to.
  final ThreadKey threadKey;

  /// Conversation state at time of cancellation, if available.
  final Conversation? conversation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CancelledState &&
          threadKey == other.threadKey &&
          conversation == other.conversation;

  @override
  int get hashCode => Object.hash(threadKey, conversation);

  @override
  String toString() => 'CancelledState(threadKey: $threadKey)';
}
