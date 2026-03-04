import 'dart:io';

import 'package:soliplex_client/soliplex_client.dart';

/// HTTP observer that logs all traffic to stderr for CLI debugging.
///
/// Prints request/response/error/stream events in a compact format
/// prefixed with `[HTTP]` or `[SSE]` so they can be grepped from output.
class DebugHttpObserver implements HttpObserver {
  @override
  void onRequest(HttpRequestEvent event) {
    stderr.writeln('[HTTP] ${event.method} ${event.uri}');
  }

  @override
  void onResponse(HttpResponseEvent event) {
    stderr.writeln(
      '[HTTP] ${event.statusCode} (${event.duration.inMilliseconds}ms)',
    );
  }

  @override
  void onError(HttpErrorEvent event) {
    stderr.writeln(
      '[HTTP] ERROR ${event.method} ${event.uri} ${event.exception}',
    );
  }

  @override
  void onStreamStart(HttpStreamStartEvent event) {
    stderr.writeln('[SSE] ${event.method} ${event.uri}');
  }

  @override
  void onStreamEnd(HttpStreamEndEvent event) {
    final status = event.isSuccess ? 'OK' : 'ERROR';
    stderr.writeln(
      '[SSE] END $status (${event.duration.inMilliseconds}ms, '
      '${event.bytesReceived}B)',
    );
  }
}
