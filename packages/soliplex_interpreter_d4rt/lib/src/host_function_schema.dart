import 'package:meta/meta.dart';
import 'package:soliplex_interpreter_d4rt/src/host_param.dart';

/// Schema for a host function callable from interpreted Dart code.
///
/// Defines the function's name, description, and ordered parameters.
/// Handles mapping positional arguments to named parameters and validates
/// types before the handler runs.
@immutable
class HostFunctionSchema {
  const HostFunctionSchema({
    required this.name,
    required this.description,
    this.params = const [],
  });

  /// Function name as registered with the d4rt runtime.
  final String name;

  /// Human-readable description.
  final String description;

  /// Ordered parameter definitions.
  ///
  /// Positional args from d4rt are mapped to params by insertion order.
  /// Named args overlay by name.
  final List<HostParam> params;

  /// Maps positional + named args from a d4rt host function call
  /// to a validated named parameter map.
  ///
  /// 1. Positional args are matched to [params] by order.
  /// 2. Named args overlay by name.
  /// 3. Each param is validated via [HostParam.validate].
  ///
  /// Throws [FormatException] if required params are missing or types mismatch.
  Map<String, Object?> mapAndValidate(
    List<Object?> positionalArgs,
    Map<String, Object?> namedArgs,
  ) {
    final raw = <String, Object?>{};

    // Positional args → named params by schema order
    for (var i = 0; i < params.length && i < positionalArgs.length; i++) {
      raw[params[i].name] = positionalArgs[i];
    }

    // Named args overlay
    for (final entry in namedArgs.entries) {
      raw[entry.key] = entry.value;
    }

    // Validate all params
    final validated = <String, Object?>{};
    for (final param in params) {
      validated[param.name] = param.validate(raw[param.name]);
    }

    return validated;
  }
}
