import 'dart:io';

import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

void main() {
  group('FileSink', () {
    late Directory tempDir;
    late String filePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('file_sink_test_');
      filePath = '${tempDir.path}/test.log';
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('writes formatted log line with ISO timestamp', () async {
      final sink = FileSink(filePath: filePath);
      final timestamp = DateTime(2026, 3, 1, 12, 34, 56, 789);

      sink.write(
        LogRecord(
          level: LogLevel.info,
          message: 'message sent',
          timestamp: timestamp,
          loggerName: 'Chat',
        ),
      );

      await sink.flush();
      await sink.close();

      final content = File(filePath).readAsStringSync();
      expect(content, contains('[INFO]'));
      expect(content, contains('Chat: message sent'));
      expect(content, contains('2026-03-01'));
    });

    test('includes error on indented line', () async {
      final sink = FileSink(filePath: filePath)
        ..write(
          LogRecord(
            level: LogLevel.error,
            message: 'something broke',
            timestamp: DateTime.now(),
            loggerName: 'App',
            error: Exception('boom'),
          ),
        );

      await sink.flush();
      await sink.close();

      final content = File(filePath).readAsStringSync();
      expect(content, contains('  Error: Exception: boom'));
    });

    test('includes stackTrace on indented line', () async {
      final stack = StackTrace.current;
      final sink = FileSink(filePath: filePath)
        ..write(
          LogRecord(
            level: LogLevel.error,
            message: 'crash',
            timestamp: DateTime.now(),
            loggerName: 'App',
            error: StateError('bad state'),
            stackTrace: stack,
          ),
        );

      await sink.flush();
      await sink.close();

      final content = File(filePath).readAsStringSync();
      expect(content, contains('  Error: Bad state: bad state'));
      expect(content, contains('  Stack:'));
    });

    test('writes multiple records', () async {
      final sink = FileSink(filePath: filePath)
        ..write(
          LogRecord(
            level: LogLevel.info,
            message: 'first',
            timestamp: DateTime.now(),
            loggerName: 'A',
          ),
        )
        ..write(
          LogRecord(
            level: LogLevel.warning,
            message: 'second',
            timestamp: DateTime.now(),
            loggerName: 'B',
          ),
        )
        ..write(
          LogRecord(
            level: LogLevel.error,
            message: 'third',
            timestamp: DateTime.now(),
            loggerName: 'C',
          ),
        );

      await sink.flush();
      await sink.close();

      final lines = File(filePath)
          .readAsLinesSync()
          .where((l) => l.contains('] '))
          .toList();
      expect(lines, hasLength(3));
      expect(lines[0], contains('[INFO]'));
      expect(lines[1], contains('[WARNING]'));
      expect(lines[2], contains('[ERROR]'));
    });

    test('appends to existing file', () async {
      File(filePath).writeAsStringSync('existing content\n');

      final sink = FileSink(filePath: filePath)
        ..write(
          LogRecord(
            level: LogLevel.debug,
            message: 'appended',
            timestamp: DateTime.now(),
            loggerName: 'Test',
          ),
        );

      await sink.flush();
      await sink.close();

      final content = File(filePath).readAsStringSync();
      expect(content, startsWith('existing content\n'));
      expect(content, contains('appended'));
    });

    test('includes span context when present', () async {
      final sink = FileSink(filePath: filePath)
        ..write(
          LogRecord(
            level: LogLevel.info,
            message: 'traced',
            timestamp: DateTime.now(),
            loggerName: 'Test',
            spanId: 'span-1',
            traceId: 'trace-2',
          ),
        );

      await sink.flush();
      await sink.close();

      final content = File(filePath).readAsStringSync();
      expect(content, contains('trace=trace-2'));
      expect(content, contains('span=span-1'));
    });

    test('flush completes without error', () async {
      final sink = FileSink(filePath: filePath);
      await expectLater(sink.flush(), completes);
      await sink.close();
    });

    test('close completes without error', () async {
      final sink = FileSink(filePath: filePath);
      await expectLater(sink.close(), completes);
    });

    test('writes all log levels', () async {
      final sink = FileSink(filePath: filePath);

      for (final level in LogLevel.values) {
        sink.write(
          LogRecord(
            level: level,
            message: 'msg-${level.name}',
            timestamp: DateTime.now(),
            loggerName: 'Test',
          ),
        );
      }

      await sink.flush();
      await sink.close();

      final content = File(filePath).readAsStringSync();
      expect(content, contains('[TRACE]'));
      expect(content, contains('[DEBUG]'));
      expect(content, contains('[INFO]'));
      expect(content, contains('[WARNING]'));
      expect(content, contains('[ERROR]'));
      expect(content, contains('[FATAL]'));
    });
  });
}
