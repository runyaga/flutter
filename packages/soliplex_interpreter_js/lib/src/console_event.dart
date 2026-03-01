import 'package:meta/meta.dart';

/// Events emitted during JavaScript code execution.
///
/// Simplified from Monty's ConsoleEvent: uses [String?] for value and
/// [String] for output (no MontyResourceUsage — that's Monty-specific).
@immutable
sealed class ConsoleEvent {
  const ConsoleEvent();
}

/// A line of console output from a `console.log()` call.
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

  /// The return value of the JavaScript expression, if any.
  final String? value;

  /// Collected console output from `console.log()` calls.
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
