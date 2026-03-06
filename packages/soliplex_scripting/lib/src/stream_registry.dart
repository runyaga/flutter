import 'dart:async';

/// Wraps a [StreamIterator] with a cached-future pattern so that
/// `moveNext()` results are never lost when racing multiple streams.
///
/// Uses `peek/consume`: `peek()` starts or returns a cached fetch,
/// `consume()` clears the cache so the next `peek()` fetches fresh.
/// Losers in a `select()` race keep their pending future cached —
/// it resolves in the background and returns instantly next call.
class _BufferedIterator {
  _BufferedIterator(this._inner);

  final StreamIterator<Object?> _inner;
  bool _exhausted = false;

  /// Cached future from a previous `peek()` that hasn't been consumed.
  Future<(bool, Object?)>? _pendingFetch;

  /// Start or return a cached fetch. Safe to call multiple times —
  /// returns the same future if a fetch is already in flight.
  Future<(bool, Object?)> peek() {
    if (_exhausted) return Future.value((false, null));
    return _pendingFetch ??= _inner.moveNext().then((hasNext) {
      if (!hasNext) _exhausted = true;
      return (hasNext, hasNext ? _inner.current : null);
    });
  }

  /// Clear the cached fetch so the next `peek()` advances the stream.
  /// Call this ONLY on the winner of a race.
  void consume() {
    _pendingFetch = null;
  }

  /// Pull the next value (convenience for non-racing single reads).
  Future<(bool, Object?)> moveNext() async {
    final result = await peek();
    consume();
    return result;
  }

  bool get isExhausted => _exhausted;

  Future<void> cancel() => _inner.cancel();
}

/// Manages named stream factories and active subscriptions.
///
/// Python code can subscribe to a named stream by calling
/// [subscribe], pull values one at a time with [next], and
/// close early with [close].
///
/// Each subscription gets a unique integer handle backed by a
/// [_BufferedIterator] that lazily drains the factory-produced stream.
class StreamRegistry {
  final _factories = <String, Stream<Object?> Function()>{};
  final _iterators = <int, _BufferedIterator>{};
  int _nextHandle = 1;

  /// Register a named stream factory.
  ///
  /// The [factory] is invoked each time [subscribe] is called for [name],
  /// producing a fresh stream per subscription.
  void registerFactory(String name, Stream<Object?> Function() factory) {
    _factories[name] = factory;
  }

  /// Subscribe to the named stream [name].
  ///
  /// Returns an integer handle for use with [next] and [close].
  /// Throws [ArgumentError] if no factory is registered for [name].
  int subscribe(String name) {
    final factory = _factories[name];
    if (factory == null) {
      throw ArgumentError.value(name, 'name', 'No stream factory registered.');
    }
    final handle = _nextHandle++;
    _iterators[handle] = _BufferedIterator(StreamIterator(factory()));
    return handle;
  }

  /// Pull the next value from the subscription identified by [handle].
  ///
  /// Returns `null` when the stream is done (and automatically cleans up
  /// the iterator). Throws [ArgumentError] for unknown handles.
  Future<Object?> next(int handle) async {
    final iterator = _iterators[handle];
    if (iterator == null) {
      throw ArgumentError.value(handle, 'handle', 'Unknown stream handle.');
    }
    final (hasValue, data) = await iterator.moveNext();
    if (hasValue) return data;
    // Stream exhausted — clean up.
    await iterator.cancel();
    _iterators.remove(handle);
    return null;
  }

  /// Race multiple subscriptions and return whichever yields a value first.
  ///
  /// Calls `peek()` on each handle concurrently. Returns
  /// `{"handle": int, "data": Object?}` for whichever stream fires first,
  /// or `null` when **all** streams are exhausted.
  ///
  /// Only the winner's cached future is consumed (via `consume()`). Losers
  /// keep their pending future cached — it resolves in the background and
  /// returns instantly on the next `peek()` or `next()` call. No data loss.
  ///
  /// Exhausted streams are cleaned up automatically.
  ///
  /// Throws [ArgumentError] if [handles] is empty or contains an unknown
  /// handle.
  Future<Map<String, Object?>?> select(List<int> handles) async {
    if (handles.isEmpty) {
      throw ArgumentError.value(handles, 'handles', 'Must not be empty.');
    }
    // Filter out handles that have already been exhausted and cleaned up,
    // rather than throwing — the caller's loop may naturally retry with
    // stale handles after a previous select() exhausted them.
    final liveHandles = handles.where(_iterators.containsKey).toList();
    if (liveHandles.isEmpty) return null;

    // peek() on every live handle — starts or returns a cached fetch.
    final pending = <Future<(int, bool, Object?)>>[];
    for (final h in liveHandles) {
      final iterator = _iterators[h]!;
      pending.add(
        iterator.peek().then((result) => (h, result.$1, result.$2)),
      );
    }

    // Race: first with data wins.
    final completer = Completer<(int, bool, Object?)>();
    var completed = 0;

    for (final future in pending) {
      unawaited(
        future.then((result) {
          completed++;
          final (handle, hasValue, _) = result;
          if (hasValue && !completer.isCompleted) {
            completer.complete(result);
          } else if (!hasValue) {
            // Clean up exhausted iterator.
            final iter = _iterators.remove(handle);
            if (iter != null) unawaited(iter.cancel());
          }
          // If all completed and none had a value, resolve sentinel.
          if (completed == pending.length && !completer.isCompleted) {
            completer.complete((-1, false, null));
          }
        }),
      );
    }

    final (winnerHandle, hasValue, winnerData) = await completer.future;
    if (!hasValue) return null;

    // Consume ONLY the winner so its next peek() fetches fresh.
    // Losers keep their cached future — no data loss, no blocking.
    _iterators[winnerHandle]?.consume();

    return {'handle': winnerHandle, 'data': winnerData};
  }

  /// Close the subscription identified by [handle] early.
  ///
  /// Returns `true` if the handle existed and was closed, `false` otherwise.
  Future<bool> close(int handle) async {
    final iterator = _iterators.remove(handle);
    if (iterator == null) return false;
    await iterator.cancel();
    return true;
  }

  /// Dispose all active subscriptions.
  Future<void> dispose() async {
    for (final iterator in _iterators.values) {
      await iterator.cancel();
    }
    _iterators.clear();
  }
}
