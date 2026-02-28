/// Lifecycle state of an `AgentSession`.
///
/// Transitions: spawning → running → completed / failed / cancelled.
enum AgentSessionState {
  /// Session created, thread/run being initialized.
  spawning,

  /// Run active, streaming events.
  running,

  /// Run finished successfully.
  completed,

  /// Run failed with a classified error.
  failed,

  /// Run was cancelled by the caller.
  cancelled,
}
