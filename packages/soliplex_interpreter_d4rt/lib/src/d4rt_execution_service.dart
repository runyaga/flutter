import 'dart:async';

import 'package:d4rt/d4rt.dart';
import 'package:soliplex_interpreter_d4rt/src/console_event.dart';

/// Executes Dart code via [D4rt] and streams console output.
///
/// Simpler than `DefaultD4rtBridge` — no host function dispatch or
/// `BridgeEvent` emission. Just runs code and captures print output.
///
/// Only one execution may run at a time. Attempting to call [execute]
/// while another execution is in progress throws a [StateError].
class D4rtExecutionService {
  D4rtExecutionService({D4rt? interpreter, Duration? timeout})
      : _timeout = timeout {
    _interpreter = interpreter ?? D4rt();
  }

  late final D4rt _interpreter;
  final Duration? _timeout;
  bool _isExecuting = false;
  bool _isDisposed = false;

  /// Whether an execution is currently in progress.
  bool get isExecuting => _isExecuting;

  /// Executes [code] and returns a stream of [ConsoleEvent]s.
  ///
  /// The stream emits [ConsoleOutput] for each `print()` call,
  /// then either [ConsoleComplete] or [ConsoleError] before closing.
  ///
  /// Throws [StateError] if already executing or disposed.
  Stream<ConsoleEvent> execute(String code) {
    if (_isDisposed) {
      throw StateError('D4rtExecutionService has been disposed');
    }
    if (_isExecuting) {
      throw StateError(
        'D4rtExecutionService is already executing. '
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

  /// Releases resources held by this service.
  void dispose() {
    _isDisposed = true;
  }

  Future<void> _run(
    String code,
    StreamController<ConsoleEvent> controller,
  ) async {
    final output = StringBuffer();

    // Wrap code in main() if needed.
    final wrappedCode = _wrapInMain(code);

    try {
      // Capture print() output via Zone.
      Object? result;
      final zone = Zone.current.fork(
        specification: ZoneSpecification(
          print: (self, parent, zone, line) {
            final text = '$line\n';
            output.write(text);
            controller.add(ConsoleOutput(text));
          },
        ),
      );

      if (_timeout != null) {
        result = await Future<Object?>(
          () => zone.run(() => _interpreter.execute(source: wrappedCode)),
        ).timeout(_timeout);
      } else {
        result = zone.run(() => _interpreter.execute(source: wrappedCode));
      }

      controller.add(
        ConsoleComplete(
          value: result?.toString(),
          output: output.toString(),
        ),
      );
    } on TimeoutException {
      controller.add(const ConsoleError('Execution timed out'));
      // d4rt throws RuntimeError (not extending Exception/Error),
      // so we catch Object to handle all thrown types.
    } on Object catch (e) {
      controller.add(ConsoleError(e.toString()));
    }
  }

  /// Wraps code in a `main()` function if one isn't already defined.
  String _wrapInMain(String code) {
    if (RegExp(r'(^|\s)main\s*\(').hasMatch(code)) {
      return code;
    }

    return 'main() {\n$code\n}';
  }
}
