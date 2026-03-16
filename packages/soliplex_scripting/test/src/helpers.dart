import 'package:dart_monty_bridge/dart_monty_bridge.dart'
    show BridgeMiddleware, CallRole, ToolCall;
import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart'
    show BridgeLogger, NullBridgeLogger;
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
  void use(BridgeMiddleware middleware) {}

  @override
  void register(HostFunction function) => registered.add(function);

  @override
  void unregister(String name) => unregistered.add(name);

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
