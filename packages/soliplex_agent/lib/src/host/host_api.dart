/// Interface for operations that cross the platform boundary.
///
/// Two categories of things the pure Dart runtime cannot do:
/// 1. Render Flutter widgets (DataFrames, charts)
/// 2. Access native platform APIs (location, camera, file picker,
///    clipboard, biometrics) that require OS permissions or hardware
///
/// The Flutter app implements this. Tests use `FakeHostApi`.
abstract interface class HostApi {
  // ── Visual rendering ─────────────────────────────────────────────

  /// Register a DataFrame for display in the host UI.
  ///
  /// Returns an integer handle for later retrieval.
  int registerDataFrame(Map<String, List<Object?>> columns);

  /// Retrieve a registered DataFrame by handle.
  ///
  /// Returns `null` if the handle is not found.
  Map<String, List<Object?>>? getDataFrame(int handle);

  /// Register a chart configuration for rendering.
  ///
  /// Returns an integer handle for later retrieval.
  int registerChart(Map<String, Object?> chartConfig);

  // ── Platform services + extensibility ────────────────────────────

  /// Invoke a host operation by namespaced name.
  ///
  /// Covers both platform services (location, camera, file picker)
  /// and extensible host functions (future GUI operations).
  /// The host handles permission requests, hardware access, and OS
  /// dialogs. Returns the result or throws on denial/unavailability.
  ///
  /// Naming convention:
  ///   `native.location`     — GPS coordinates
  ///   `native.clipboard`    — clipboard read/write
  ///   `native.file_picker`  — file picker dialog
  ///   `ui.show_dialog`      — Flutter dialog
  ///   `ui.navigate`         — GoRouter navigation
  Future<Object?> invoke(String name, Map<String, Object?> args);
}
