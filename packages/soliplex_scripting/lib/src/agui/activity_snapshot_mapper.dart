import 'package:ag_ui/ag_ui.dart' hide Tool;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Maps a [BridgeEvent] to an ACTIVITY_SNAPSHOT [CustomEvent], or null
/// if the event has no activity representation.
///
/// Produces [CustomEvent] with `name: 'activity_snapshot'` and a value
/// map containing `messageId`, `activityType`, `content`, and `replace`.
/// The `messageId` format is `"<namespace>:<callId>"` for tool events and
/// `"run:<runId>"` for run lifecycle events.
class ActivitySnapshotMapper {
  const ActivitySnapshotMapper({required this.runId});

  final String runId;

  CustomEvent? map(BridgeEvent event) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return switch (event) {
      BridgeRunStarted() => _activity(
          timestamp: now,
          messageId: 'run:$runId',
          activityType: 'run_start',
          content: const {},
          replace: false,
        ),
      BridgeRunFinished() => _activity(
          timestamp: now,
          messageId: 'run:$runId',
          activityType: 'run_end',
          content: const {},
          replace: true,
        ),
      BridgeRunError(:final message) => _activity(
          timestamp: now,
          messageId: 'run:$runId',
          activityType: 'run_error',
          content: {'message': message},
          replace: true,
        ),
      BridgeToolCallStart(:final callId, :final name) => _activity(
          timestamp: now,
          messageId: '${_namespace(name)}:$callId',
          activityType: 'skill_tool_start',
          content: {'name': name},
          replace: false,
        ),
      BridgeToolCallArgs(:final callId, :final delta) => _activity(
          timestamp: now,
          messageId: 'tool:$callId',
          activityType: 'skill_tool_args',
          content: {'delta': delta},
          replace: false,
        ),
      BridgeToolCallResult(:final callId, :final result) => _activity(
          timestamp: now,
          messageId: 'tool:$callId',
          activityType: 'skill_tool_result',
          content: {'result': result},
          replace: true,
        ),
      _ => null,
    };
  }

  static String _namespace(String toolName) {
    final dot = toolName.indexOf('.');
    return dot >= 0 ? toolName.substring(0, dot) : toolName;
  }

  static CustomEvent _activity({
    required int timestamp,
    required String messageId,
    required String activityType,
    required Map<String, Object?> content,
    required bool replace,
  }) =>
      CustomEvent(
        name: 'activity_snapshot',
        value: {
          'messageId': messageId,
          'activityType': activityType,
          'content': content,
          'replace': replace,
        },
        timestamp: timestamp,
      );
}
