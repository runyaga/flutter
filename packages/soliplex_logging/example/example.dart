/// Minimal example showing how to configure logging and emit log records.
///
/// ```bash
/// dart run example/example.dart
/// ```
library;

import 'package:soliplex_logging/soliplex_logging.dart';

void main() {
  // 1. Configure the log manager and get a named logger.
  final log = (LogManager.instance
        ..minimumLevel = LogLevel.debug
        ..addSink(ConsoleSink()))
      .getLogger('MyApp')
    // 2. Emit log records at various levels.
    ..info('Application started')
    ..debug('Loading configuration')
    ..warning('Cache miss for key "user:42"');

  try {
    throw const FormatException('bad input');
  } on FormatException catch (e, s) {
    log.error('Failed to parse input', error: e, stackTrace: s);
  }
}
