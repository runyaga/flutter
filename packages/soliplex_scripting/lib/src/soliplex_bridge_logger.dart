import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';
import 'package:soliplex_logging/soliplex_logging.dart' as logging;

/// [BridgeLogger] backed by soliplex_logging.
///
/// Adapts the Monty bridge logging contract to Soliplex's own logging
/// framework, bypassing struct_log entirely. Child loggers form a
/// hierarchical tree (e.g., `monty.sandbox.child.0`).
///
/// Use [SoliplexBridgeLogger.root] to create a root logger:
/// ```dart
/// final logger = SoliplexBridgeLogger.root(
///   logging.LogManager.instance,
/// );
/// ```
class SoliplexBridgeLogger implements BridgeLogger {
  /// Creates a logger wrapping a soliplex_logging [logging.Logger].
  SoliplexBridgeLogger(this._logger, this._logManager);

  /// Creates a root logger from a [logging.LogManager].
  factory SoliplexBridgeLogger.root(
    logging.LogManager logManager, [
    String name = 'monty',
  ]) => SoliplexBridgeLogger(logManager.getLogger(name), logManager);

  final logging.Logger _logger;
  final logging.LogManager _logManager;
  bool _disposed = false;
  final List<SoliplexBridgeLogger> _children = [];

  @override
  void trace(String message, {Map<String, Object?>? attributes}) {
    if (_disposed) return;
    _logger.trace(message, attributes: attributes);
  }

  @override
  void debug(String message, {Map<String, Object?>? attributes}) {
    if (_disposed) return;
    _logger.debug(message, attributes: attributes);
  }

  @override
  void info(String message, {Map<String, Object?>? attributes}) {
    if (_disposed) return;
    _logger.info(message, attributes: attributes);
  }

  @override
  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? attributes,
  }) {
    if (_disposed) return;
    _logger.warning(
      message,
      error: error,
      stackTrace: stackTrace,
      attributes: attributes,
    );
  }

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? attributes,
  }) {
    if (_disposed) return;
    _logger.error(
      message,
      error: error,
      stackTrace: stackTrace,
      attributes: attributes,
    );
  }

  @override
  BridgeLogger child(String name) {
    if (_disposed) return const NullBridgeLogger();
    final child = SoliplexBridgeLogger(
      _logManager.getLogger('${_logger.name}.$name'),
      _logManager,
    );
    _children.add(child);
    return child;
  }

  @override
  void close() {
    _disposed = true;
    for (final child in _children) {
      child.close();
    }
    _children.clear();
  }
}
