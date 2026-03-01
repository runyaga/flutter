import 'package:soliplex_interpreter_js/src/bridge_event.dart';
import 'package:soliplex_interpreter_js/src/host_function.dart';
import 'package:soliplex_interpreter_js/src/host_function_schema.dart';

/// Bridge for JavaScript code calling registered Dart host functions.
///
/// Mirrors the MontyBridge contract from 0008 spec, adapted for
/// js_interpreter's synchronous eval model. Emits [BridgeEvent]s instead of
/// ag-ui BaseEvents to avoid the ag_ui dependency.
abstract class JsBridge {
  /// All registered function schemas.
  List<HostFunctionSchema> get schemas;

  /// Registers a host function.
  void register(HostFunction function);

  /// Unregisters a host function by name.
  void unregister(String name);

  /// Executes [code] and returns a stream of bridge events.
  ///
  /// Since js_interpreter's eval is synchronous, all events are buffered
  /// during execution and emitted after eval returns. There is no real-time
  /// suspend/resume.
  Stream<BridgeEvent> execute(String code);

  /// Releases resources.
  void dispose();
}
