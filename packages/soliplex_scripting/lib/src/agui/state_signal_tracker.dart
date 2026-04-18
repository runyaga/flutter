import 'dart:convert';

import 'package:ag_ui/ag_ui.dart' hide Tool;
import 'package:signals_core/signals_core.dart';

/// Subscribes to a [ReadonlySignal] and emits ag-ui state frames.
///
/// First emission → [StateSnapshotEvent] with `{key: value}`. Subsequent
/// emissions → [StateDeltaEvent] with a single RFC 6902 `replace` patch
/// at `/<key>`. Skips emissions where the serialized value is unchanged.
///
/// Call [dispose] to cancel the subscription.
class StateSignalTracker<T extends Object?> {
  StateSignalTracker({
    required this.key,
    required ReadonlySignal<T> signal,
    required void Function(BaseEvent) emit,
  }) : _emit = emit {
    _cleanup = signal.subscribe(_onValue);
  }

  final String key;
  final void Function(BaseEvent) _emit;

  late final EffectCleanup _cleanup;
  Object? _previous;
  bool _first = true;

  void _onValue(T value) {
    final encoded = _toJson(value);
    if (_first) {
      _first = false;
      _previous = encoded;
      _emit(StateSnapshotEvent(snapshot: {key: encoded}));
    } else {
      if (encoded == _previous) return;
      _previous = encoded;
      _emit(
        StateDeltaEvent(
          delta: [
            {'op': 'replace', 'path': '/$key', 'value': encoded},
          ],
        ),
      );
    }
  }

  static Object? _toJson(Object? value) {
    if (value == null ||
        value is num ||
        value is bool ||
        value is String ||
        value is List ||
        value is Map) {
      return value;
    }
    try {
      return jsonDecode(jsonEncode(value));
    } on Object {
      return value.toString();
    }
  }

  void dispose() => _cleanup();
}
