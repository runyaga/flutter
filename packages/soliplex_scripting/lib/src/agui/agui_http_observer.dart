import 'dart:async';

import 'package:soliplex_client/soliplex_client.dart';

/// Implements [HttpObserver] and emits `http.*` [CustomEvent]s.
///
/// Attach a single instance to [ObservableHttpClient] at session
/// construction. It captures both REST (`request`) and AG-UI SSE
/// (`requestStream`) traffic because both flow through the same
/// `HttpTransport → ObservableHttpClient` decorator chain.
class AgUiHttpObserver implements HttpObserver {
  AgUiHttpObserver() : _controller = StreamController<BaseEvent>.broadcast();

  final StreamController<BaseEvent> _controller;

  Stream<BaseEvent> get events => _controller.stream;

  @override
  void onRequest(HttpRequestEvent event) {
    _add(
      CustomEvent(
        name: 'http.request',
        value: {
          'requestId': event.requestId,
          'method': event.method,
          'uri': event.uri.toString(),
        },
        timestamp: event.timestamp.millisecondsSinceEpoch,
      ),
    );
  }

  @override
  void onResponse(HttpResponseEvent event) {
    _add(
      CustomEvent(
        name: 'http.response',
        value: {
          'requestId': event.requestId,
          'statusCode': event.statusCode,
          'durationMs': event.duration.inMilliseconds,
          'bodySize': event.bodySize,
          if (event.reasonPhrase != null) 'reasonPhrase': event.reasonPhrase,
        },
        timestamp: event.timestamp.millisecondsSinceEpoch,
      ),
    );
  }

  @override
  void onError(HttpErrorEvent event) {
    _add(
      CustomEvent(
        name: 'http.error',
        value: {
          'requestId': event.requestId,
          'method': event.method,
          'uri': event.uri.toString(),
          'exceptionType': event.exception.runtimeType.toString(),
          'message': event.exception.message,
          'durationMs': event.duration.inMilliseconds,
        },
        timestamp: event.timestamp.millisecondsSinceEpoch,
      ),
    );
  }

  @override
  void onStreamStart(HttpStreamStartEvent event) {
    _add(
      CustomEvent(
        name: 'http.stream.start',
        value: {
          'requestId': event.requestId,
          'method': event.method,
          'uri': event.uri.toString(),
        },
        timestamp: event.timestamp.millisecondsSinceEpoch,
      ),
    );
  }

  @override
  void onStreamEnd(HttpStreamEndEvent event) {
    _add(
      CustomEvent(
        name: 'http.stream.end',
        value: {
          'requestId': event.requestId,
          'bytesReceived': event.bytesReceived,
          'durationMs': event.duration.inMilliseconds,
          if (event.error != null) 'error': event.error!.message,
        },
        timestamp: event.timestamp.millisecondsSinceEpoch,
      ),
    );
  }

  void _add(CustomEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void dispose() => _controller.close();
}
