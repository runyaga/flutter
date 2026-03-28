import 'package:soliplex_agent/src/models/agent_result.dart';

/// Interface for spawning and managing L2 sub-agents from Python.
///
/// Parallel to `HostApi` (which handles platform/UI concerns), this
/// interface handles agent orchestration. Implementations bridge to
/// `AgentRuntime` (production) or record calls (testing).
abstract interface class AgentApi {
  /// Spawns a new agent in [roomId] with the given [prompt].
  ///
  /// If [threadId] is provided, continues an existing conversation thread.
  /// Returns an integer handle for tracking the agent session.
  Future<int> spawnAgent(
    String roomId,
    String prompt, {
    String? threadId,
    Duration? timeout,
  });

  /// Waits for all agents identified by [handles] to complete.
  ///
  /// Returns their output texts in the same order as [handles].
  Future<List<String>> waitAll(List<int> handles, {Duration? timeout});

  /// Returns the output text for a completed agent [handle].
  Future<String> getResult(int handle, {Duration? timeout});

  /// Returns the thread ID for a given agent [handle].
  String getThreadId(int handle);

  /// Watches an agent and returns its [AgentResult] without evicting the
  /// handle.
  ///
  /// Unlike [getResult] which throws on failure and evicts the handle,
  /// this returns the full result status so callers can implement
  /// supervision logic (retry, escalation, quality checks).
  Future<AgentResult> watchAgent(int handle, {Duration? timeout});

  /// Cancels the agent identified by [handle].
  Future<void> cancelAgent(int handle);

  /// Returns the current lifecycle status of the agent as a string.
  ///
  /// Non-blocking — does not wait for the agent to complete. Returns one of:
  /// `"spawning"`, `"running"`, `"completed"`, `"failed"`, `"cancelled"`.
  String agentStatus(int handle);
}
