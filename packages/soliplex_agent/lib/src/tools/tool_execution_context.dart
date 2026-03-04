import 'package:soliplex_agent/src/orchestration/execution_event.dart';
import 'package:soliplex_agent/src/runtime/agent_session.dart';
import 'package:soliplex_agent/src/runtime/session_extension.dart';
import 'package:soliplex_client/soliplex_client.dart';

/// Context available to tools during execution.
///
/// Provides access to cancellation, child spawning, event emission,
/// and session-scoped extensions. Implemented by [AgentSession].
///
/// Tool executors MUST be cooperative with Dart's event loop:
/// - Insert `await Future<void>.delayed(Duration.zero)` in tight loops
/// - Use streaming/chunked processing for large data
/// - Check [cancelToken] at natural yield points
abstract interface class ToolExecutionContext {
  /// Cancellation token for the current run.
  CancelToken get cancelToken;

  /// Spawn a child agent session linked to the current session.
  Future<AgentSession> spawnChild({
    required String roomId,
    required String prompt,
  });

  /// Emit a granular execution event for UI observation.
  void emitEvent(ExecutionEvent event);

  /// Access a session-scoped extension by type.
  T? getExtension<T extends SessionExtension>();
}
