import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:soliplex_client/soliplex_client.dart' hide CancelToken;
import 'package:soliplex_client/src/utils/cancel_token.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test helpers (same FakePlatformClient as stack integration test)
// ---------------------------------------------------------------------------

class FakePlatformClient implements SoliplexHttpClient {
  HttpResponse? nextResponse;
  SoliplexException? nextRequestError;

  StreamedHttpResponse? nextStreamResponse;
  SoliplexException? nextStreamError;

  bool closed = false;

  @override
  Future<HttpResponse> request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    if (nextRequestError != null) throw nextRequestError!;
    return nextResponse!;
  }

  @override
  Future<StreamedHttpResponse> requestStream(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    CancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancelled();
    if (nextStreamError != null) throw nextStreamError!;
    return nextStreamResponse!;
  }

  @override
  void close() {
    closed = true;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakePlatformClient platform;
  late HttpClientAdapter adapter;

  final testUri = Uri.parse('https://api.example.com/v1/test');

  setUp(() {
    platform = FakePlatformClient();
    adapter = HttpClientAdapter(client: platform);
  });

  tearDown(() {
    adapter.close();
  });

  group('HttpClientAdapter integration', () {
    test('regular request through adapter returns real status code', () async {
      platform.nextResponse = HttpResponse(
        statusCode: 200,
        bodyBytes: Uint8List.fromList([65, 66, 67]),
        headers: const {'content-type': 'text/plain'},
      );

      final request = http.Request('GET', testUri);
      final response = await adapter.send(request);

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], equals('text/plain'));

      final body = await response.stream.toBytes();
      expect(body, equals([65, 66, 67]));
    });

    test('SSE request through adapter returns real status code and headers',
        () async {
      final controller = StreamController<List<int>>();
      platform.nextStreamResponse = StreamedHttpResponse(
        statusCode: 200,
        headers: const {'content-type': 'text/event-stream'},
        body: controller.stream,
      );

      final request = http.Request('GET', testUri)
        ..headers['accept'] = 'text/event-stream';
      final response = await adapter.send(request);

      expect(response.statusCode, equals(200));
      expect(
        response.headers['content-type'],
        equals('text/event-stream'),
      );

      final sub = response.stream.listen((_) {});
      await controller.close();
      await sub.cancel();
    });

    test('SSE stream data flows through adapter to consumer', () async {
      final controller = StreamController<List<int>>();
      platform.nextStreamResponse = StreamedHttpResponse(
        statusCode: 200,
        body: controller.stream,
      );

      final request = http.Request('GET', testUri)
        ..headers['accept'] = 'text/event-stream';
      final response = await adapter.send(request);

      final chunks = <List<int>>[];
      final completer = Completer<void>();

      response.stream.listen(chunks.add, onDone: completer.complete);

      controller
        ..add([100, 101])
        ..add([102, 103, 104]);
      await controller.close();
      await completer.future;

      expect(chunks, hasLength(2));
      expect(chunks[0], equals([100, 101]));
      expect(chunks[1], equals([102, 103, 104]));
    });

    test('NetworkException from SSE connection propagates through adapter',
        () async {
      platform.nextStreamError = const NetworkException(
        message: 'Connection timed out',
      );

      final request = http.Request('GET', testUri)
        ..headers['accept'] = 'text/event-stream';

      Object? caughtError;
      try {
        await adapter.send(request);
      } catch (e) {
        caughtError = e;
      }

      expect(caughtError, isA<NetworkException>());
      expect(
        (caughtError! as NetworkException).message,
        equals('Connection timed out'),
      );
    });

    test('adapter close propagates to underlying client', () {
      HttpClientAdapter(client: platform).close();
      expect(platform.closed, isTrue);
    });
  });
}
