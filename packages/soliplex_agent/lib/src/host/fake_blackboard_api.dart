import 'package:soliplex_agent/src/host/blackboard_api.dart';

/// In-memory [BlackboardApi] for testing.
///
/// Records all calls and exposes the backing store for assertions.
class FakeBlackboardApi implements BlackboardApi {
  /// Creates a fake blackboard with an empty store.
  FakeBlackboardApi();

  /// The backing store, exposed for test assertions.
  final Map<String, Object?> store = {};

  /// Recorded method calls as `{methodName: [args]}`.
  final Map<String, List<Object?>> calls = {};

  @override
  Future<void> write(String key, Object? value) async {
    calls['write'] = [key, value];
    store[key] = value;
  }

  @override
  Future<Object?> read(String key) async {
    calls['read'] = [key];
    return store[key];
  }

  @override
  Future<List<String>> keys() async {
    calls['keys'] = [];
    return store.keys.toList();
  }
}
