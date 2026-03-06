/// Shared key-value store for cross-agent state.
///
/// Scoped per top-level agent session. All child agents share the same
/// blackboard, enabling communication between parallel sub-agents.
///
/// Values must be JSON-compatible (`String`, `num`, `bool`, `List`, `Map`,
/// or `null`) to ensure sendability across isolate boundaries and
/// compatibility with the Monty bridge serialization.
///
/// Platform implementations:
/// - **Native:** `ProxyBlackboardApi` — delegates via `SendPort`/`ReceivePort`
/// - **WASM:** `DirectBlackboardApi` — direct in-memory `Map` access
abstract interface class BlackboardApi {
  /// Writes a value to the blackboard.
  ///
  /// Overwrites any existing value for [key].
  Future<void> write(String key, Object? value);

  /// Reads a value from the blackboard.
  ///
  /// Returns `null` if [key] does not exist.
  Future<Object?> read(String key);

  /// Returns all keys currently in the blackboard.
  Future<List<String>> keys();
}
