import 'dart:async';
import 'dart:convert';

import 'package:d4rt/d4rt.dart' hide D4rtBridge;
import 'package:soliplex_interpreter_d4rt/src/bridge_event.dart';
import 'package:soliplex_interpreter_d4rt/src/d4rt_bridge.dart';
import 'package:soliplex_interpreter_d4rt/src/host_function.dart';
import 'package:soliplex_interpreter_d4rt/src/host_function_schema.dart';

/// Buffered record of a tool call that occurred during synchronous execution.
class _ToolCallRecord {
  _ToolCallRecord({
    required this.toolCallId,
    required this.stepName,
    required this.args,
    required this.result,
    this.error,
  });

  final String toolCallId;
  final String stepName;
  final Map<String, Object?> args;
  final String result;
  final String? error;
}

/// Default [D4rtBridge] implementation.
///
/// Wraps a [D4rt] instance, dispatching host function calls to registered
/// handlers. Since d4rt execution is synchronous:
///
/// 1. Host function handlers are called **synchronously** during execution
///    (async handlers are not awaited — spike limitation).
/// 2. Tool call events are buffered and emitted post-execution.
/// 3. Print output is captured via [Zone.fork] with a custom print handler.
class DefaultD4rtBridge implements D4rtBridge {
  DefaultD4rtBridge({D4rt? interpreter, Duration? timeout})
      : _timeout = timeout {
    _interpreter = interpreter ?? D4rt();
  }

  late final D4rt _interpreter;
  final Duration? _timeout;
  final Map<String, HostFunction> _functions = {};
  int _idCounter = 0;
  bool _isExecuting = false;
  bool _isDisposed = false;

  String get _nextId => '${_idCounter++}';

  @override
  List<HostFunctionSchema> get schemas =>
      _functions.values.map((f) => f.schema).toList(growable: false);

  @override
  void register(HostFunction function) {
    if (_isDisposed) throw StateError('Bridge has been disposed');
    _functions[function.schema.name] = function;
  }

  @override
  void unregister(String name) {
    if (_isDisposed) throw StateError('Bridge has been disposed');
    _functions.remove(name);
  }

  @override
  Stream<BridgeEvent> execute(String code) {
    if (_isDisposed) throw StateError('Bridge has been disposed');
    if (_isExecuting) {
      throw StateError('Bridge is already executing');
    }

    final controller = StreamController<BridgeEvent>();
    _isExecuting = true;
    unawaited(
      _run(code, controller).whenComplete(() {
        _isExecuting = false;
        unawaited(controller.close());
      }),
    );

    return controller.stream;
  }

  @override
  void dispose() {
    _isDisposed = true;
  }

  Future<void> _run(
    String code,
    StreamController<BridgeEvent> controller,
  ) async {
    final runId = _nextId;
    controller.add(BridgeRunStarted(runId: runId));

    final printBuffer = StringBuffer();
    final toolCalls = <_ToolCallRecord>[];

    // Register host functions as d4rt top-level functions.
    // Each adapter maps d4rt's (visitor, positionalArgs, namedArgs, typeArgs)
    // to our HostFunction's schema-validated named params.
    final bridge = _interpreter;
    for (final fn in _functions.values) {
      bridge.registertopLevelFunction(
        fn.schema.name,
        (visitor, positionalArgs, namedArgs, typeArgs) {
          final toolCallId = _nextId;

          // Map positional + named args to validated named params.
          Map<String, Object?> args;
          try {
            args = fn.schema.mapAndValidate(positionalArgs, namedArgs);
          } on FormatException catch (e) {
            toolCalls.add(
              _ToolCallRecord(
                toolCallId: toolCallId,
                stepName: fn.schema.name,
                args: const {},
                result: 'Error: $e',
                error: e.toString(),
              ),
            );

            return null;
          }

          // Handler returns Future<Object?> but d4rt is synchronous —
          // we cannot await. Best-effort: call the handler, attach
          // a .then() to capture the result if it resolves as a
          // microtask (e.g. Future.value). This is a spike limitation.
          Object? handlerResult;
          String? handlerError;
          try {
            unawaited(
              fn.handler(args).then(
                (value) {
                  handlerResult = value;
                },
                onError: (Object e) {
                  handlerError = e.toString();
                },
              ),
            );
          } on Exception catch (e) {
            handlerError = e.toString();
          }

          toolCalls.add(
            _ToolCallRecord(
              toolCallId: toolCallId,
              stepName: fn.schema.name,
              args: args,
              result: handlerResult?.toString() ?? '',
              error: handlerError,
            ),
          );

          return handlerResult;
        },
      );
    }

    try {
      // Wrap code in main() if it doesn't already define one.
      final wrappedCode = _wrapInMain(code);

      // Capture print() output via Zone.
      final zone = Zone.current.fork(
        specification: ZoneSpecification(
          print: (self, parent, zone, line) {
            printBuffer.writeln(line);
          },
        ),
      );

      if (_timeout != null) {
        await Future<Object?>(
          () => zone.run(
            () => bridge.execute(source: wrappedCode),
          ),
        ).timeout(_timeout);
      } else {
        zone.run(() => bridge.execute(source: wrappedCode));
      }

      // Emit buffered tool call events.
      for (final tc in toolCalls) {
        controller
          ..add(BridgeStepStarted(stepName: tc.stepName))
          ..add(
            BridgeToolCallStart(
              toolCallId: tc.toolCallId,
              toolCallName: tc.stepName,
            ),
          )
          ..add(
            BridgeToolCallArgs(
              toolCallId: tc.toolCallId,
              delta: jsonEncode(tc.args),
            ),
          )
          ..add(BridgeToolCallEnd(toolCallId: tc.toolCallId))
          ..add(
            BridgeToolCallResult(
              toolCallId: tc.toolCallId,
              content: tc.error != null ? 'Error: ${tc.error}' : tc.result,
            ),
          )
          ..add(BridgeStepFinished(stepName: tc.stepName));
      }

      // Flush print buffer as text events.
      _flushPrintBuffer(printBuffer, controller);

      controller.add(BridgeRunFinished(runId: runId));
    } on TimeoutException {
      controller.add(
        const BridgeRunError(message: 'Execution timed out'),
      );
      // d4rt throws RuntimeError (not extending Exception/Error),
      // so we catch Object to handle all thrown types.
    } on Object catch (e) {
      controller.add(BridgeRunError(message: e.toString()));
    }
  }

  void _flushPrintBuffer(
    StringBuffer buffer,
    StreamController<BridgeEvent> controller,
  ) {
    if (buffer.isEmpty) return;
    final messageId = _nextId;
    controller
      ..add(BridgeTextStart(messageId: messageId))
      ..add(
        BridgeTextContent(messageId: messageId, delta: buffer.toString()),
      )
      ..add(BridgeTextEnd(messageId: messageId));
  }

  /// Wraps code in a `main()` function if one isn't already defined.
  ///
  /// d4rt requires a `main()` entry point. If the user code doesn't define
  /// one, we wrap the code body inside `main() { ... }`.
  String _wrapInMain(String code) {
    // Simple heuristic: check if code contains a main function declaration.
    if (RegExp(r'(^|\s)main\s*\(').hasMatch(code)) {
      return code;
    }

    return 'main() {\n$code\n}';
  }
}
