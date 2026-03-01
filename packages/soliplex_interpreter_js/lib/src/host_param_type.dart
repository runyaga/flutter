/// Parameter types for host function arguments.
///
/// Copied from soliplex_interpreter_monty for spike validation.
enum HostParamType {
  string,
  integer,
  number,
  boolean,
  list,
  map;

  /// JSON Schema type name for tool export.
  String get jsonSchemaType => switch (this) {
        string => 'string',
        integer => 'integer',
        number => 'number',
        boolean => 'boolean',
        list => 'array',
        map => 'object',
      };
}
