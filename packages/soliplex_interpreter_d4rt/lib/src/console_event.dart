import 'package:meta/meta.dart';

/// Events emitted during Dart code execution via the d4rt interpreter.
///
/// Adapted from soliplex_interpreter_monty's ConsoleEvent, but without
/// Monty-specific types (MontyResourceUsage, MontyException).
@immutable
sealed class ConsoleEvent {
  const ConsoleEvent();
}

/// A line of console output from a `print()` call.
final class ConsoleOutput extends ConsoleEvent {
  const ConsoleOutput(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ConsoleOutput && text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'ConsoleOutput($text)';
}

/// Execution completed successfully.
final class ConsoleComplete extends ConsoleEvent {
  const ConsoleComplete({required this.output, this.value});

  /// The return value of the executed code, if any.
  final String? value;

  /// Collected console output from `print()` calls.
  final String output;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsoleComplete &&
          value == other.value &&
          output == other.output;

  @override
  int get hashCode => Object.hash(value, output);

  @override
  String toString() => 'ConsoleComplete(value: $value, output: $output)';
}

/// Execution failed with an error.
final class ConsoleError extends ConsoleEvent {
  const ConsoleError(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsoleError && message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'ConsoleError($message)';
}
