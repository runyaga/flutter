/// Interface for form operations exposed to the scripting layer.
///
/// Python code can create forms and set validation errors via
/// host functions that delegate to this interface.
abstract interface class FormApi {
  /// Create a dynamic form with the given field definitions.
  ///
  /// Each entry in [fields] is a map with keys like `name`, `label`, `type`.
  /// Returns an integer handle for the form.
  int createForm(List<Map<String, Object?>> fields);

  /// Set validation errors on a form.
  ///
  /// [errors] maps field names to error messages.
  /// Returns `true` if the form existed and errors were set.
  bool setFormErrors(int handle, Map<String, String> errors);
}
