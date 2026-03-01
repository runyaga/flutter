import 'package:meta/meta.dart';
import 'package:soliplex_interpreter_js/src/host_param_type.dart';

/// Describes a single parameter of a host function.
///
/// Copied from soliplex_interpreter_monty for spike validation.
@immutable
class HostParam {
  const HostParam({
    required this.name,
    required this.type,
    this.isRequired = true,
    this.description,
    this.defaultValue,
  });

  final String name;
  final HostParamType type;
  final bool isRequired;
  final String? description;
  final Object? defaultValue;

  /// Validates and optionally coerces [value].
  ///
  /// Returns the validated (possibly coerced) value.
  /// Throws [FormatException] if validation fails.
  Object? validate(Object? value) {
    if (value == null) {
      if (isRequired) {
        throw FormatException('Required parameter "$name" is null', value);
      }
      return defaultValue;
    }

    return switch (type) {
      HostParamType.string => _expectType<String>(value),
      HostParamType.integer => _expectType<int>(value),
      HostParamType.number => _coerceNumber(value),
      HostParamType.boolean => _expectType<bool>(value),
      HostParamType.list => _expectType<List<Object?>>(value),
      HostParamType.map => _expectType<Map<String, Object?>>(value),
    };
  }

  T _expectType<T>(Object? value) {
    if (value is T) return value;
    throw FormatException(
      'Parameter "$name": expected $T, got ${value.runtimeType}',
      value,
    );
  }

  num _coerceNumber(Object? value) {
    if (value is num) return value;
    throw FormatException(
      'Parameter "$name": expected num, got ${value.runtimeType}',
      value,
    );
  }
}
