import 'dart:async';

/// Manages named stream factories and active subscriptions.
///
/// Python code can subscribe to a named stream by calling
/// [subscribe], pull values one at a time with [next], and
/// close early with [close].
///
/// Each subscription gets a unique integer handle backed by a
/// [StreamIterator] that lazily drains the factory-produced stream.
class StreamRegistry {
  final _factories = <String, Stream<Object?> Function()>{};
  final _iterators = <int, StreamIterator<Object?>>{};
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
    _iterators[handle] = StreamIterator(factory());
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
    if (await iterator.moveNext()) {
      return iterator.current;
    }
    // Stream exhausted — clean up.
    await iterator.cancel();
    _iterators.remove(handle);
    return null;
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
