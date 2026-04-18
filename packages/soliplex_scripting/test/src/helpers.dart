import 'package:dart_monty/dart_monty.dart' show OsCallHandler;
import 'package:dart_monty/dart_monty_bridge.dart'
    show BridgeLogger, NullBridgeLogger;
import 'package:dart_monty/dart_monty_bridge.dart'
    show BridgeMiddleware, CallRole, ToolCall;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Records all [register] calls for verification.
class RecordingBridge implements MontyBridge {
  final registered = <HostFunction>[];
  final unregistered = <String>[];

  @override
  BridgeLogger get logger => const NullBridgeLogger();

  @override
  List<HostFunctionSchema> get schemas =>
      registered.map((f) => f.schema).toList();

  @override
  Map<String, List<HostFunctionSchema>> get schemasByCategory => {};

  @override
  void use(BridgeMiddleware middleware) {}

  @override
  void register(HostFunction function, {String? category}) =>
      registered.add(function);

  @override
  void unregister(String name) => unregistered.add(name);

  @override
  void registerOs(OsCallHandler handler) {}

  @override
  Stream<BridgeEvent> execute(String code) => const Stream.empty();

  @override
  Future<Object?> invokeHostFunction(
    String name,
    Map<String, Object?> args, {
    CallRole role = const ToolCall(),
  }) =>
      throw UnimplementedError();

  @override
  void dispose() {}
}
