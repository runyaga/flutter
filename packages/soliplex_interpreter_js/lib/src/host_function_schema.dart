import 'package:meta/meta.dart';
import 'package:soliplex_interpreter_js/src/host_param.dart';

/// Schema for a host function callable from JavaScript.
///
/// Defines the function's name, description, and ordered parameters.
/// Handles mapping positional args to named parameters and validates
/// types before the handler runs.
@immutable
class HostFunctionSchema {
  const HostFunctionSchema({
    required this.name,
    required this.description,
    this.params = const [],
  });

  final String name;
  final String description;
  final List<HostParam> params;

  /// Maps positional args from [args] to a named parameter map.
  ///
  /// 1. Positional args are matched to [params] by order.
  /// 2. Each param is validated via [HostParam.validate].
  ///
  /// Throws [ArgumentError] if required params are missing or types mismatch.
  Map<String, Object?> mapAndValidate(List<Object?> args) {
    final raw = <String, Object?>{};

    for (var i = 0; i < params.length && i < args.length; i++) {
      raw[params[i].name] = args[i];
    }

    final validated = <String, Object?>{};
    for (final param in params) {
      validated[param.name] = param.validate(raw[param.name]);
    }

    return validated;
  }
}
