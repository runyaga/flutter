import 'package:meta/meta.dart';
import 'package:soliplex_interpreter_js/src/host_function_schema.dart';

/// Async handler that receives validated named arguments and returns a result.
typedef HostFunctionHandler = Future<Object?> Function(
  Map<String, Object?> args,
);

/// A host function: schema + handler.
@immutable
class HostFunction {
  const HostFunction({required this.schema, required this.handler});

  final HostFunctionSchema schema;
  final HostFunctionHandler handler;
}
