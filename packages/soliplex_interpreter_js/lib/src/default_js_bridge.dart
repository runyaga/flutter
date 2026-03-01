import 'dart:async';
import 'dart:convert';

import 'package:js_interpreter/js_interpreter.dart';
import 'package:soliplex_interpreter_js/src/bridge_event.dart';
import 'package:soliplex_interpreter_js/src/host_function.dart';
import 'package:soliplex_interpreter_js/src/host_function_schema.dart';
import 'package:soliplex_interpreter_js/src/js_bridge.dart';
import 'package:soliplex_interpreter_js/src/js_value_converter.dart';

/// Default [JsBridge] wrapping a [JSInterpreter] instance.
///
/// Since js_interpreter's `eval()` is synchronous, tool call events are
/// buffered during execution and emitted post-completion. There is no
/// real-time suspend/resume capability.
class DefaultJsBridge implements JsBridge {
  DefaultJsBridge({Duration? timeout}) : _timeout = timeout;

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
    if (_isExecuting) throw StateError('Bridge is already executing');

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
    final threadId = _nextId;
    final runId = _nextId;

    controller.add(BridgeRunStarted(threadId: threadId, runId: runId));

    final interpreter = JSInterpreter();
    final printBuffer = StringBuffer();
    final toolCallLog = <BridgeEvent>[];

    // Override the built-in console object with our intercepting version.
    // We must use JSNativeFunction directly (not a Dart closure) because
    // setGlobal with a raw Function double-wraps through fromDart.
    final consoleObj = JSObject()
      ..setProperty(
        'log',
        JSNativeFunction(
          functionName: 'log',
          nativeImpl: (List<JSValue> args) {
            final text = args
                .map(
                  (a) => JsValueConverter.toDart(a)?.toString() ?? 'undefined',
                )
                .join(' ');
            printBuffer.writeln(text);
            return JSValueFactory.undefined();
          },
        ),
      );
    interpreter.setGlobal('console', consoleObj);

    // Register host functions as JSNativeFunction globals.
    // Since eval is synchronous, host function handlers (which are async)
    // cannot be awaited inline. We execute them synchronously by completing
    // the Future inline and buffering tool call events.
    for (final entry in _functions.entries) {
      final fn = entry.value;
      interpreter.setGlobal(
        entry.key,
        JSNativeFunction(
          functionName: entry.key,
          nativeImpl: (List<JSValue> args) {
            final toolCallId = _nextId;
            toolCallLog
              ..add(BridgeStepStarted(stepName: fn.schema.name))
              ..add(
                BridgeToolCallStart(
                  toolCallId: toolCallId,
                  toolCallName: fn.schema.name,
                ),
              );

            // Convert JSValue args to Dart and map positional -> named.
            final dartArgs = [
              for (final arg in args) JsValueConverter.toDart(arg),
            ];
            try {
              final namedArgs = fn.schema.mapAndValidate(dartArgs);
              toolCallLog
                ..add(
                  BridgeToolCallArgs(
                    toolCallId: toolCallId,
                    delta: jsonEncode(namedArgs),
                  ),
                )
                ..add(BridgeToolCallEnd(toolCallId: toolCallId));

              // Execute handler synchronously (blocks on Future).
              // NOTE: Spike limitation — truly async handlers return null.
              final result = _runHandlerSync(fn.handler, namedArgs);
              toolCallLog
                ..add(
                  BridgeToolCallResult(
                    messageId: _nextId,
                    toolCallId: toolCallId,
                    content: result?.toString() ?? '',
                  ),
                )
                ..add(BridgeStepFinished(stepName: fn.schema.name));

              return JsValueConverter.toJs(result);
            } on Object catch (e) {
              toolCallLog
                ..add(
                  BridgeToolCallResult(
                    messageId: _nextId,
                    toolCallId: toolCallId,
                    content: 'Error: $e',
                  ),
                )
                ..add(BridgeStepFinished(stepName: fn.schema.name));
              return JSValueFactory.undefined();
            }
          },
        ),
      );
    }

    try {
      final evalFuture = Future<JSValue>(() => interpreter.eval(code));

      final JSValue result;
      if (_timeout != null) {
        result = await evalFuture.timeout(_timeout);
      } else {
        result = await evalFuture;
      }

      // Emit buffered tool call events.
      toolCallLog.forEach(controller.add);

      // Flush print buffer.
      _flushPrintBuffer(printBuffer, controller);

      // Check for error result.
      if (result is JSError) {
        controller.add(BridgeRunError(message: result.toString()));
      } else {
        controller.add(BridgeRunFinished(threadId: threadId, runId: runId));
      }
    } on TimeoutException {
      controller.add(
        const BridgeRunError(message: 'Execution timed out'),
      );
    } on Object catch (e) {
      controller.add(BridgeRunError(message: e.toString()));
    }
  }

  /// Runs an async handler synchronously by forcing microtask execution.
  ///
  /// Uses a [Zone] with immediate microtask scheduling so that handlers
  /// like `async => value` complete inline. Truly async handlers (I/O,
  /// timers) will still fail — this is a known spike limitation.
  static Object? _runHandlerSync(
    HostFunctionHandler handler,
    Map<String, Object?> args,
  ) {
    Object? result;
    Object? error;
    var completed = false;

    runZonedGuarded(
      () {
        unawaited(
          handler(args).then(
            (value) {
              result = value;
              completed = true;
            },
            onError: (Object e) {
              error = e;
              completed = true;
            },
          ),
        );
      },
      (e, _) {
        error = e;
        completed = true;
      },
      zoneSpecification: ZoneSpecification(
        scheduleMicrotask: (self, parent, zone, f) => f(),
      ),
    );

    if (error != null) {
      throw error! is Exception ? error! as Exception : Exception('$error');
    }
    if (!completed) return null;
    return result;
  }

  void _flushPrintBuffer(
    StringBuffer buffer,
    StreamController<BridgeEvent> controller,
  ) {
    if (buffer.isEmpty) return;
    final messageId = _nextId;
    controller
      ..add(BridgeTextStart(messageId: messageId))
      ..add(BridgeTextContent(messageId: messageId, delta: buffer.toString()))
      ..add(BridgeTextEnd(messageId: messageId));
  }
}
