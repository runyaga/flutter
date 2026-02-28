import 'package:soliplex_agent/src/host/platform_constraints.dart';

/// Platform constraints for web (WASM).
///
/// Web has a single-threaded WASM interpreter. Only one bridge can
/// run at a time, and it cannot be re-entered while suspended.
class WebPlatformConstraints implements PlatformConstraints {
  /// Creates web platform constraints.
  const WebPlatformConstraints();

  @override
  bool get supportsParallelExecution => false;

  @override
  bool get supportsAsyncMode => false;

  @override
  int get maxConcurrentBridges => 1;

  @override
  bool get supportsReentrantInterpreter => false;
}
