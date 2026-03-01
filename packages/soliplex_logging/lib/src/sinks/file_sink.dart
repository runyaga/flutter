import 'dart:io';

import 'package:soliplex_logging/src/log_record.dart';
import 'package:soliplex_logging/src/log_sink.dart';

/// A [LogSink] that appends formatted log lines to a file.
///
/// Output format:
/// ```text
/// 2026-03-01T12:34:56.789 [INFO] Chat: message sent
///   Error: some error
///   Stack: ...
/// ```
///
/// Logging must never crash the app, so all I/O is wrapped in try-catch.
class FileSink implements LogSink {
  /// Creates a file sink that appends to [filePath].
  FileSink({required String filePath})
      : _sink = File(filePath).openWrite(mode: FileMode.append);

  final IOSink _sink;

  @override
  void write(LogRecord record) {
    try {
      final buffer = StringBuffer()
        ..write(record.timestamp.toIso8601String())
        ..write(' [${record.level.label}] ')
        ..write('${record.loggerName}: ${record.message}');

      if (record.spanId != null || record.traceId != null) {
        buffer.write(' (');
        if (record.traceId != null) buffer.write('trace=${record.traceId}');
        if (record.spanId != null && record.traceId != null) {
          buffer.write(', ');
        }
        if (record.spanId != null) buffer.write('span=${record.spanId}');
        buffer.write(')');
      }

      buffer.writeln();

      if (record.error != null) {
        buffer.writeln('  Error: ${record.error}');
      }

      final stackStr = record.stackTrace?.toString();
      if (stackStr != null && stackStr.isNotEmpty) {
        buffer.writeln('  Stack: $stackStr');
      }

      _sink.write(buffer.toString());
    } on Object {
      // Suppress all errors — logging must never crash the app.
    }
  }

  @override
  Future<void> flush() async {
    try {
      await _sink.flush();
    } on Object {
      // Suppress flush errors.
    }
  }

  @override
  Future<void> close() async {
    try {
      await _sink.close();
    } on Object {
      // Suppress close errors.
    }
  }
}
