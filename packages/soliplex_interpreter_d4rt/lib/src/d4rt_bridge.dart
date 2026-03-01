import 'package:soliplex_interpreter_d4rt/src/bridge_event.dart';
import 'package:soliplex_interpreter_d4rt/src/host_function.dart';
import 'package:soliplex_interpreter_d4rt/src/host_function_schema.dart';

/// Bridge for LLM-generated Dart code calling registered host functions.
///
/// Executes Dart code in the d4rt interpreter, dispatches host function
/// calls to registered [HostFunction] handlers, and emits [BridgeEvent]s.
abstract class D4rtBridge {
  /// All registered function schemas.
  List<HostFunctionSchema> get schemas;

  /// Registers a host function.
  void register(HostFunction function);

  /// Unregisters a host function by name.
  ///
  /// Note: d4rt does not support removing registered functions from an
  /// existing instance. This bridge tracks functions in a forwarding table
  /// and skips removed entries at dispatch time.
  void unregister(String name);

  /// Executes [code] and returns a stream of [BridgeEvent]s.
  ///
  /// Since d4rt execution is synchronous, all events are buffered during
  /// execution and emitted after `execute()` returns. There is no real-time
  /// streaming of tool call events.
  Stream<BridgeEvent> execute(String code);

  /// Releases resources.
  void dispose();
}
