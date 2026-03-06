import 'package:soliplex_agent/src/host/blackboard_api.dart';

/// In-memory [BlackboardApi] for single-threaded environments (WASM)
/// and same-isolate usage (native without isolate workers).
///
/// All operations are synchronous but wrapped in [Future] to satisfy
/// the [BlackboardApi] contract.
class DirectBlackboardApi implements BlackboardApi {
  /// Creates a blackboard backed by an in-memory [Map].
  DirectBlackboardApi();

  final Map<String, Object?> _store = {};

  @override
  Future<void> write(String key, Object? value) async {
    _store[key] = value;
  }

  @override
  Future<Object?> read(String key) async => _store[key];

  @override
  Future<List<String>> keys() async => _store.keys.toList();
}
