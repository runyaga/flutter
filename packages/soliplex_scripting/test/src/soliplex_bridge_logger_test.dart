import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_scripting/src/soliplex_bridge_logger.dart';
import 'package:test/test.dart';

void main() {
  group('SoliplexBridgeLogger', () {
    late _CaptureSink sink;

    setUp(() {
      LogManager.instance.minimumLevel = LogLevel.trace;
      sink = _CaptureSink();
      LogManager.instance.addSink(sink);
    });

    tearDown(() {
      LogManager.instance.removeSink(sink);
    });

    test('root factory creates logger with given name', () {
      SoliplexBridgeLogger.root(LogManager.instance, 'bridge')
          .info('hello');

      expect(sink.records, hasLength(1));
      expect(sink.records.first.loggerName, 'bridge');
      expect(sink.records.first.message, 'hello');
      expect(sink.records.first.level, LogLevel.info);
    });

    test('delegates all log levels', () {
      SoliplexBridgeLogger.root(LogManager.instance)
        ..trace('t')
        ..debug('d')
        ..info('i')
        ..warning('w')
        ..error('e');

      expect(sink.records.map((r) => r.level).toList(), [
        LogLevel.trace,
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warning,
        LogLevel.error,
      ]);
    });

    test('passes attributes through', () {
      SoliplexBridgeLogger.root(LogManager.instance)
          .info('msg', attributes: {'key': 'value', 'n': null});

      expect(
        sink.records.first.attributes,
        {'key': 'value', 'n': null},
      );
    });

    test('warning passes error and stackTrace', () {
      final err = Exception('boom');
      final stack = StackTrace.current;
      SoliplexBridgeLogger.root(LogManager.instance)
          .warning('oops', error: err, stackTrace: stack);

      final record = sink.records.first;
      expect(record.error, err);
      expect(record.stackTrace, stack);
    });

    test('error passes error and stackTrace', () {
      final err = Exception('fail');
      final stack = StackTrace.current;
      SoliplexBridgeLogger.root(LogManager.instance)
          .error('fatal', error: err, stackTrace: stack);

      final record = sink.records.first;
      expect(record.level, LogLevel.error);
      expect(record.error, err);
      expect(record.stackTrace, stack);
    });

    test('child creates hierarchical logger name', () {
      SoliplexBridgeLogger.root(LogManager.instance)
          .child('sandbox')
          .info('from child');

      expect(sink.records.first.loggerName, 'monty.sandbox');
    });

    test('nested children chain names', () {
      SoliplexBridgeLogger.root(LogManager.instance)
          .child('sandbox')
          .child('child.0')
          .debug('deep');

      expect(
        sink.records.first.loggerName,
        'monty.sandbox.child.0',
      );
    });

    test('close silences logger and children', () {
      final root = SoliplexBridgeLogger.root(LogManager.instance);
      final child = root.child('plugin');
      root
        ..close()
        ..info('should be silent');
      child.info('also silent');

      expect(sink.records, isEmpty);
    });

    test('child after close returns NullBridgeLogger', () {
      final root = SoliplexBridgeLogger.root(LogManager.instance)
        ..close();
      root.child('late').info('noop');

      expect(sink.records, isEmpty);
    });

    test('defaults root name to monty', () {
      SoliplexBridgeLogger.root(LogManager.instance).info('default');

      expect(sink.records.first.loggerName, 'monty');
    });
  });
}

class _CaptureSink implements LogSink {
  final records = <LogRecord>[];

  @override
  void write(LogRecord record) => records.add(record);

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}
