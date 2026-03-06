# SSE Stream Close Reported as Error — Analysis

## Symptom

When the CLI connects to the datetime room and completes a successful run, the
verbose output shows:

```text
[AGUI] Completed  run=75569356-...  msgs=2  tools=1
[AGUI]   last: TextMessage(...)
[c950f8ad-...] SUCCESS: The current date and time is: 2026-03-04T19:28:19...
> [SSE] END ERROR (6816ms, 3050B)
[cleanup] SSE stream disconnect (ignored)
```

The run completes successfully (we get the answer), but the SSE stream close is
logged as `[SSE] END ERROR` instead of `[SSE] END OK`.

## How SSE Works

SSE (Server-Sent Events) is a one-way streaming protocol. The server sends
events over a long-lived HTTP connection, then **closes the connection** when
done. This close is *normal protocol behavior*, not an error. The AG-UI
protocol uses SSE: the server streams run events, then closes the connection
after sending the final `RunFinished` event.

## Root Cause Chain

### Layer 1: `DartHttpClient.requestStream()` (dart_http_client.dart:114-187)

```dart
subscription = streamedResponse.stream.listen(
  controller.add,
  onError: (Object error, StackTrace stackTrace) {
    // Wrap all stream errors as NetworkException
    controller.addError(
      NetworkException(
        message: 'Stream error: $error',
        originalError: error,
        stackTrace: stackTrace,
      ),
    );
  },
  onDone: controller.close,
  cancelOnError: true,    // <-- KEY PROBLEM
);
```

The `http` package (dart:io or browser) surfaces the server closing the TCP
connection as a stream **error** (likely `ClientException: Connection closed
while receiving data`), not a clean stream **done**.

With `cancelOnError: true`:

1. The error fires → `onError` handler wraps it as `NetworkException` and adds
   to the controller
2. The subscription auto-cancels immediately
3. `onDone` **never fires** because `cancelOnError` killed the subscription

So the controller emits an error but is never properly closed through the done
path.

### Layer 2: `ObservableHttpClient.requestStream()` (observable_http_client.dart:152-249)

The `StreamTransformer.fromHandlers` has two paths:

- `handleError` (line 201): Fires `onStreamEnd` with `error: soliplexError` →
  `isSuccess = false`
- `handleDone` (line 229): Fires `onStreamEnd` with `error: null` →
  `isSuccess = true`

Because the error path fires (from Layer 1), observers see `isSuccess = false`.

### Layer 3: `DebugHttpObserver.onStreamEnd()` (debug_observer.dart:35-41)

```dart
void onStreamEnd(HttpStreamEndEvent event) {
  final status = event.isSuccess ? 'OK' : 'ERROR';
  stderr.writeln('[SSE] END $status ...');
}
```

Prints `[SSE] END ERROR` because `isSuccess` is `false`.

### Layer 4: `cli_runner.dart` runZonedGuarded (line 51-60)

The `NetworkException` propagates as an unhandled async error, caught by the
guarded zone:

```dart
(e, _) {
  if (e.toString().contains('Connection closed')) {
    stderr.writeln('[cleanup] SSE stream disconnect (ignored)');
  } else {
    stderr.writeln('[async error] $e');
  }
}
```

This is a band-aid — it catches and ignores the error, but the damage (false
`[SSE] END ERROR` logging) already happened upstream.

## The Two Interacting Problems

1. **`cancelOnError: true`** in `DartHttpClient.requestStream()` — When the
   `http` package emits a stream error on connection close, `cancelOnError`
   prevents `onDone` from ever firing. The controller gets an error added but
   is never closed cleanly. This means the downstream `handleDone` in
   `ObservableHttpClient` never fires.

2. **No distinction between "server closed connection" and "real network
   error"** — The `onError` handler in `DartHttpClient` wraps ALL errors as
   `NetworkException('Stream error: ...')` without checking if the error is
   just a normal SSE connection close. A server closing the connection after
   sending all events is protocol-correct behavior, not a network failure.

## Proposed Fix Options

### Option A: Change `cancelOnError` to `false` + close controller after error

In `DartHttpClient.requestStream()`, change `cancelOnError: false` so that
`onDone` still fires after an error. The stream will emit the error AND then
complete normally. The `handleDone` in `ObservableHttpClient` will fire and
report `isSuccess = true`.

**Risk**: If a real network error occurs mid-stream, we'd continue listening
instead of stopping. We'd need the consumer to handle errors properly.

### Option B: Detect "connection closed" errors as clean completion

In `DartHttpClient.requestStream()`, check the error message in `onError`. If
it matches known "connection closed" patterns from dart:io / browser HTTP, treat
it as a clean close:

```dart
onError: (Object error, StackTrace stackTrace) {
  if (_isConnectionClosedError(error)) {
    // Server closed SSE connection — this is normal.
    controller.close();
    return;
  }
  // Real error — propagate.
  controller.addError(
    NetworkException(
      message: 'Stream error: $error',
      originalError: error,
      stackTrace: stackTrace,
    ),
  );
},
```

**Risk**: Relies on string matching error messages, which is fragile across
platforms and `http` package versions.

### Option C: Handle at ObservableHttpClient layer

In `ObservableHttpClient.requestStream()`, change the `handleError` to detect
connection-closed errors and report them as successful stream ends:

```dart
handleError: (error, stackTrace, sink) {
  final endTime = DateTime.now();
  final duration = endTime.difference(startTime);
  final isConnectionClosed = _isConnectionClosedError(error);

  _notifyObservers((observer) {
    observer.onStreamEnd(
      HttpStreamEndEvent(
        requestId: requestId,
        timestamp: endTime,
        bytesReceived: bytesReceived,
        duration: duration,
        error: isConnectionClosed ? null : (error is SoliplexException ...),
        body: ...,
      ),
    );
  });

  if (!isConnectionClosed) {
    sink.addError(error, stackTrace);
  } else {
    sink.close();
  }
},
```

### Option D: Fix at DartHttpClient — close controller after error

After adding the error to the controller in `onError`, also close the
controller. And remove `cancelOnError: true` or change it to `false`:

```dart
onError: (Object error, StackTrace stackTrace) {
  controller.addError(
    NetworkException(
      message: 'Stream error: $error',
      originalError: error,
      stackTrace: stackTrace,
    ),
  );
  // Close the controller since the stream is done (error or not)
  controller.close();
},
cancelOnError: false,
```

This ensures `handleDone` always fires after any error, and the controller is
always properly closed. The error still propagates to consumers, but the
observable layer also gets a clean `handleDone`.

**However**, this means `handleDone` AND `handleError` both fire for the same
stream — `onStreamEnd` would be called twice.

## Proposed Test

A unit test that verifies a stream that errors with "Connection closed" still
reports `isSuccess = true` to observers:

```dart
test('SSE stream close after data reports isSuccess true', () async {
  // Simulate: server sends SSE data then closes connection (http package
  // surfaces this as a stream error, not a clean done).
  final sourceController = StreamController<List<int>>();

  when(
    () => mockClient.requestStream(any(), any(),
        headers: any(named: 'headers'), body: any(named: 'body')),
  ).thenAnswer((_) => sourceController.stream);

  final stream = observableClient.requestStream('POST', testUri);
  final received = <List<int>>[];
  final errors = <Object>[];

  stream.listen(
    received.add,
    onError: errors.add,
    onDone: () {},
  );

  // Server sends SSE data
  sourceController.add('data: hello\n\n'.codeUnits);
  await Future<void>.delayed(Duration.zero);

  // Server closes connection — http package reports as error
  sourceController.addError(
    NetworkException(message: 'Connection closed while receiving data'),
  );
  await Future<void>.delayed(Duration.zero);

  // The observer should report this as a successful stream end
  final endEvents = recorder.eventsOfType<HttpStreamEndEvent>();
  expect(endEvents, hasLength(1));
  expect(endEvents.first.isSuccess, isTrue,
      reason: 'SSE connection close is normal protocol behavior');
  expect(endEvents.first.bytesReceived, greaterThan(0));
});
```

## Both HTTP Clients Have the Same Bug

### DartHttpClient (dart_http_client.dart:145-159) — used on web/generic

```dart
subscription = streamedResponse.stream.listen(
  controller.add,
  onError: (Object error, StackTrace stackTrace) {
    controller.addError(
      NetworkException(message: 'Stream error: $error', ...),
    );
  },
  onDone: controller.close,
  cancelOnError: true,  // <-- BUG
);
```

### CupertinoHttpClient (cupertino_http_client.dart:156-173) — used on iOS/macOS

```dart
subscription = streamedResponse.stream.listen(
  controller.add,
  onError: (Object error, StackTrace stackTrace) {
    if (error is http.ClientException) {
      controller.addError(
        NetworkException(message: 'Connection error: ${error.message}', ...),
      );
    } else {
      controller.addError(error, stackTrace);
    }
  },
  onDone: controller.close,
  cancelOnError: true,  // <-- SAME BUG
);
```

Both implementations share the identical structural problem:
1. `cancelOnError: true` prevents `onDone` from firing after an error
2. Neither distinguishes "server closed connection" from "real network error"
3. The Cupertino version has slightly better error typing (checks for
   `ClientException`) but still treats connection close as an error

The `cupertino_http` package (using NSURLSession) may surface the connection
close differently than dart:io's `http` package, but both go through the same
`cancelOnError: true` path. Whether NSURLSession treats a server-initiated
TCP close as an error or a clean completion would need to be tested on device.

## Files Involved

| File | Role |
|------|------|
| `packages/soliplex_client/lib/src/http/dart_http_client.dart` | Creates the stream, sets `cancelOnError: true`, wraps errors |
| `packages/soliplex_client_native/lib/src/clients/cupertino_http_client.dart` | Same pattern as DartHttpClient but using NSURLSession |
| `packages/soliplex_client/lib/src/http/observable_http_client.dart` | Intercepts stream events, notifies observers, sets `isSuccess` |
| `packages/soliplex_client/lib/src/http/http_observer.dart` | Defines `HttpStreamEndEvent.isSuccess` (line 278) |
| `packages/soliplex_client/lib/src/errors/exceptions.dart` | `NetworkException` class |
| `packages/soliplex_cli/lib/src/debug_observer.dart` | Prints `[SSE] END ERROR` based on `isSuccess` |
| `packages/soliplex_cli/lib/src/cli_runner.dart` | `runZonedGuarded` band-aid for connection close errors |
| `packages/soliplex_client/test/http/observable_http_client_test.dart` | Existing observer tests (add new test here) |
| `packages/soliplex_client/test/http/http_client_adapter_test.dart` | Existing adapter tests |

## Questions for Review

1. Which fix option (A/B/C/D) is cleanest given that SSE connections ALWAYS
   close after a run?
2. Should the fix be in `DartHttpClient` (lowest layer) or
   `ObservableHttpClient` (observer layer)?
3. Is string-matching "Connection closed" fragile, or is there a better way to
   distinguish "server closed connection normally" from "network dropped"?
4. Should `cancelOnError` be `true` or `false` for SSE streams? The semantics
   differ: `true` means "stop on first error" which is wrong for SSE close,
   `false` means "keep listening after errors" which could mask real failures.
