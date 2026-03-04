import 'dart:async';

import 'package:soliplex_agent/soliplex_agent.dart';

/// Bridges a [ReadonlySignal] into a [Stream] for Riverpod consumption.
///
/// Emits the current value immediately, then every subsequent change.
/// The subscription is cancelled when the stream listener is cancelled.
extension SignalToStream<T> on ReadonlySignal<T> {
  /// Converts this signal to a broadcast stream.
  ///
  /// The stream emits the current value synchronously on listen, then
  /// emits every subsequent value change.
  Stream<T> toStream() {
    late StreamController<T> controller;
    void Function()? unsubscribe;

    controller = StreamController<T>.broadcast(
      onListen: () {
        controller.add(value);
        unsubscribe = subscribe((val) {
          if (!controller.isClosed) {
            controller.add(val);
          }
        });
      },
      onCancel: () {
        unsubscribe?.call();
        unsubscribe = null;
        controller.close();
      },
    );

    return controller.stream;
  }
}
