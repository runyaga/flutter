import 'dart:async';

import 'package:js_interpreter/js_interpreter.dart';
import 'package:soliplex_interpreter_js/src/console_event.dart';
import 'package:soliplex_interpreter_js/src/js_value_converter.dart';

/// Executes JavaScript code via [JSInterpreter] and streams console output.
///
/// Simple execution service without host function dispatch — mirrors
/// MontyExecutionService but for js_interpreter.
///
/// Only one execution may run at a time. Attempting to call [execute]
/// while another execution is in progress throws a [StateError].
class JsExecutionService {
  JsExecutionService({Duration? timeout}) : _timeout = timeout;

  final Duration? _timeout;
  bool _isExecuting = false;
  bool _isDisposed = false;

  bool get isExecuting => _isExecuting;

  /// Executes [code] and returns a stream of [ConsoleEvent]s.
  ///
  /// The stream emits [ConsoleOutput] for each `console.log()` call,
  /// then either [ConsoleComplete] or [ConsoleError] before closing.
  ///
  /// Throws [StateError] if already executing or disposed.
  Stream<ConsoleEvent> execute(String code) {
    if (_isDisposed) {
      throw StateError('JsExecutionService has been disposed');
    }
    if (_isExecuting) {
      throw StateError(
        'JsExecutionService is already executing. '
        'Only one execution may run at a time.',
      );
    }

    final controller = StreamController<ConsoleEvent>();
    _isExecuting = true;
    unawaited(
      _run(code, controller).whenComplete(() {
        _isExecuting = false;
        unawaited(controller.close());
      }),
    );

    return controller.stream;
  }

  void dispose() {
    _isDisposed = true;
  }

  Future<void> _run(
    String code,
    StreamController<ConsoleEvent> controller,
  ) async {
    final interpreter = JSInterpreter();
    final output = StringBuffer();

    // Override the built-in console object with our intercepting version.
    // Using JSNativeFunction directly avoids the double-wrap from fromDart.
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
            final line = '$text\n';
            output.write(line);
            controller.add(ConsoleOutput(line));
            return JSValueFactory.undefined();
          },
        ),
      );
    interpreter.setGlobal('console', consoleObj);

    try {
      final evalFuture = Future<JSValue>(() => interpreter.eval(code));

      final JSValue result;
      if (_timeout != null) {
        result = await evalFuture.timeout(_timeout);
      } else {
        result = await evalFuture;
      }

      if (result is JSError) {
        controller.add(ConsoleError(result.toString()));
      } else {
        final dartValue = JsValueConverter.toDart(result);
        controller.add(
          ConsoleComplete(
            value: dartValue?.toString(),
            output: output.toString(),
          ),
        );
      }
    } on TimeoutException {
      controller.add(const ConsoleError('Execution timed out'));
    } on Object catch (e) {
      controller.add(ConsoleError(e.toString()));
    }
  }
}
