import 'package:js_interpreter/js_interpreter.dart';

/// Bidirectional JSValue <-> Dart type coercion.
///
/// js_interpreter passes all values across the boundary as [JSValue] wrappers.
/// This utility converts them to/from native Dart types for host function
/// dispatch.
///
/// Wraps [DartValueConverter] for toDart and [JSValueFactory] for toJs,
/// adding the specific coercions the bridge layer needs.
abstract final class JsValueConverter {
  /// Converts a [JSValue] to a native Dart type.
  ///
  /// Delegates to [DartValueConverter.toDartValue] which handles:
  /// - [JSNumber] -> [int] or [double]
  /// - [JSString] -> [String]
  /// - [JSBoolean] -> [bool]
  /// - [JSArray] -> [List]
  /// - [JSObject] -> [Map]
  /// - [JSNull] / [JSUndefined] -> `null`
  static Object? toDart(JSValue value) {
    return DartValueConverter.toDartValue(value);
  }

  /// Converts a native Dart value to a [JSValue].
  ///
  /// Delegates to [JSValueFactory.fromDart] which handles:
  /// - [int] / [double] / [num] -> [JSNumber]
  /// - [String] -> [JSString]
  /// - [bool] -> [JSBoolean]
  /// - [List] -> [JSArray]
  /// - [Map] -> [JSObject]
  /// - `null` -> [JSNull]
  static JSValue toJs(Object? value) {
    return JSValueFactory.fromDart(value);
  }
}
