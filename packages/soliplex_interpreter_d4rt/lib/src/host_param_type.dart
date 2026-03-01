/// Parameter types for host function arguments.
enum HostParamType {
  /// String parameter.
  string,

  /// Integer parameter.
  integer,

  /// Floating-point parameter.
  number,

  /// Boolean parameter.
  boolean,

  /// List parameter.
  list,

  /// Map/dict parameter.
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
