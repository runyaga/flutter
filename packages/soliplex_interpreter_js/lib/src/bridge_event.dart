import 'package:meta/meta.dart';

/// Bridge event hierarchy copied from 0008 spec for spike validation.
///
/// These events model the lifecycle of interpreter execution against the
/// bridge contract. The spike validates whether js_interpreter can produce
/// this event stream.
@immutable
sealed class BridgeEvent {
  const BridgeEvent();
}

/// Execution run started.
final class BridgeRunStarted extends BridgeEvent {
  const BridgeRunStarted({required this.threadId, required this.runId});

  final String threadId;
  final String runId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeRunStarted &&
          threadId == other.threadId &&
          runId == other.runId;

  @override
  int get hashCode => Object.hash(threadId, runId);

  @override
  String toString() => 'BridgeRunStarted(threadId: $threadId, runId: $runId)';
}

/// Execution run finished successfully.
final class BridgeRunFinished extends BridgeEvent {
  const BridgeRunFinished({required this.threadId, required this.runId});

  final String threadId;
  final String runId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeRunFinished &&
          threadId == other.threadId &&
          runId == other.runId;

  @override
  int get hashCode => Object.hash(threadId, runId);

  @override
  String toString() => 'BridgeRunFinished(threadId: $threadId, runId: $runId)';
}

/// Execution run encountered an error.
final class BridgeRunError extends BridgeEvent {
  const BridgeRunError({required this.message});

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeRunError && message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'BridgeRunError(message: $message)';
}

/// A step (host function dispatch cycle) started.
final class BridgeStepStarted extends BridgeEvent {
  const BridgeStepStarted({required this.stepName});

  final String stepName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeStepStarted && stepName == other.stepName;

  @override
  int get hashCode => stepName.hashCode;

  @override
  String toString() => 'BridgeStepStarted(stepName: $stepName)';
}

/// A step finished.
final class BridgeStepFinished extends BridgeEvent {
  const BridgeStepFinished({required this.stepName});

  final String stepName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeStepFinished && stepName == other.stepName;

  @override
  int get hashCode => stepName.hashCode;

  @override
  String toString() => 'BridgeStepFinished(stepName: $stepName)';
}

/// A tool call began.
final class BridgeToolCallStart extends BridgeEvent {
  const BridgeToolCallStart({
    required this.toolCallId,
    required this.toolCallName,
  });

  final String toolCallId;
  final String toolCallName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeToolCallStart &&
          toolCallId == other.toolCallId &&
          toolCallName == other.toolCallName;

  @override
  int get hashCode => Object.hash(toolCallId, toolCallName);

  @override
  String toString() =>
      'BridgeToolCallStart(toolCallId: $toolCallId, name: $toolCallName)';
}

/// Tool call arguments (JSON-encoded).
final class BridgeToolCallArgs extends BridgeEvent {
  const BridgeToolCallArgs({required this.toolCallId, required this.delta});

  final String toolCallId;
  final String delta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeToolCallArgs &&
          toolCallId == other.toolCallId &&
          delta == other.delta;

  @override
  int get hashCode => Object.hash(toolCallId, delta);

  @override
  String toString() =>
      'BridgeToolCallArgs(toolCallId: $toolCallId, delta: $delta)';
}

/// Tool call argument streaming ended.
final class BridgeToolCallEnd extends BridgeEvent {
  const BridgeToolCallEnd({required this.toolCallId});

  final String toolCallId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeToolCallEnd && toolCallId == other.toolCallId;

  @override
  int get hashCode => toolCallId.hashCode;

  @override
  String toString() => 'BridgeToolCallEnd(toolCallId: $toolCallId)';
}

/// Tool call handler returned a result.
final class BridgeToolCallResult extends BridgeEvent {
  const BridgeToolCallResult({
    required this.messageId,
    required this.toolCallId,
    required this.content,
  });

  final String messageId;
  final String toolCallId;
  final String content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeToolCallResult &&
          messageId == other.messageId &&
          toolCallId == other.toolCallId &&
          content == other.content;

  @override
  int get hashCode => Object.hash(messageId, toolCallId, content);

  @override
  String toString() => 'BridgeToolCallResult(messageId: $messageId, '
      'toolCallId: $toolCallId, content: $content)';
}

/// Text output streaming started.
final class BridgeTextStart extends BridgeEvent {
  const BridgeTextStart({required this.messageId});

  final String messageId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeTextStart && messageId == other.messageId;

  @override
  int get hashCode => messageId.hashCode;

  @override
  String toString() => 'BridgeTextStart(messageId: $messageId)';
}

/// A chunk of text output.
final class BridgeTextContent extends BridgeEvent {
  const BridgeTextContent({required this.messageId, required this.delta});

  final String messageId;
  final String delta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeTextContent &&
          messageId == other.messageId &&
          delta == other.delta;

  @override
  int get hashCode => Object.hash(messageId, delta);

  @override
  String toString() =>
      'BridgeTextContent(messageId: $messageId, delta: $delta)';
}

/// Text output streaming ended.
final class BridgeTextEnd extends BridgeEvent {
  const BridgeTextEnd({required this.messageId});

  final String messageId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeTextEnd && messageId == other.messageId;

  @override
  int get hashCode => messageId.hashCode;

  @override
  String toString() => 'BridgeTextEnd(messageId: $messageId)';
}
