// packages/soliplex_client/lib/src/application/json_patch.dart

/// JSON Patch (RFC 6902) operations for applying state deltas.
///
/// Supports operations: add, remove, replace, move, copy.
/// Handles nested paths (e.g., /task_list/tasks/0/status) and graceful
/// error handling for invalid paths.
library;

import 'dart:collection';

/// Exception thrown when a JSON Patch operation fails.
class JsonPatchException implements Exception {
  /// Creates a JSON Patch exception.
  const JsonPatchException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'JsonPatchException: $message';
}

/// Result of applying a JSON patch to state.
///
/// Contains both the updated state and any errors encountered.
class PatchResult {
  /// Creates a successful patch result.
  const PatchResult.success(this.state) : error = null;

  /// Creates a failed patch result.
  const PatchResult.failure(this.state, this.error);

  /// The state after patch application (unchanged if failed).
  final Map<String, dynamic> state;

  /// Error message if patch failed, null if successful.
  final String? error;

  /// Whether the patch was applied successfully.
  bool get isSuccess => error == null;
}

/// Applies JSON Patch operations to state.
///
/// This class provides a pure functional interface for applying patches:
/// - Input state is not modified
/// - Returns a new state map with the patch applied
/// - Handles errors gracefully without throwing
class JsonPatcher {
  /// Applies a single patch operation to state.
  ///
  /// The [patch] map must contain:
  /// - `op`: The operation (add, remove, replace, move, copy)
  /// - `path`: The target path (e.g., /tasks/0/status)
  /// - `value`: The value for add/replace operations
  /// - `from`: The source path for move/copy operations
  ///
  /// Returns a [PatchResult] with the updated state or error.
  static PatchResult apply(
    Map<String, dynamic> state,
    Map<String, dynamic> patch,
  ) {
    // Deep copy state to avoid mutation
    final newState = _deepCopy(state);

    final op = patch['op'] as String?;
    final path = patch['path'] as String?;

    if (op == null) {
      return PatchResult.failure(state, 'Missing "op" in patch');
    }
    if (path == null) {
      return PatchResult.failure(state, 'Missing "path" in patch');
    }

    try {
      final segments = _parsePath(path);

      switch (op) {
        case 'add':
          _addAtPath(newState, segments, patch['value']);
        case 'remove':
          _removeAtPath(newState, segments);
        case 'replace':
          _replaceAtPath(newState, segments, patch['value']);
        case 'move':
          final from = patch['from'] as String?;
          if (from == null) {
            return PatchResult.failure(state, 'Move operation missing "from"');
          }
          _moveFromTo(newState, _parsePath(from), segments);
        case 'copy':
          final from = patch['from'] as String?;
          if (from == null) {
            return PatchResult.failure(state, 'Copy operation missing "from"');
          }
          _copyFromTo(newState, _parsePath(from), segments);
        default:
          return PatchResult.failure(state, 'Unknown operation: $op');
      }

      return PatchResult.success(newState);
    } on JsonPatchException catch (e) {
      return PatchResult.failure(state, e.message);
    } catch (e) {
      return PatchResult.failure(state, 'Patch error: $e');
    }
  }

  /// Applies multiple patches in sequence.
  ///
  /// Stops on first error and returns the state at that point.
  static PatchResult applyAll(
    Map<String, dynamic> state,
    List<Map<String, dynamic>> patches,
  ) {
    var currentState = state;

    for (final patch in patches) {
      final result = apply(currentState, patch);
      if (!result.isSuccess) {
        return result;
      }
      currentState = result.state;
    }

    return PatchResult.success(currentState);
  }

  /// Applies a state delta event (Soliplex format).
  ///
  /// State delta events use:
  /// - `delta_path`: The path to modify
  /// - `delta_type`: The operation (add, remove, replace, move, copy)
  /// - `delta_value`: The new value (for add/replace)
  /// - `delta_from`: The source path (for move/copy)
  static PatchResult applyDelta(
    Map<String, dynamic> state,
    Map<String, dynamic> delta,
  ) {
    final path = delta['delta_path'] as String?;
    final type = delta['delta_type'] as String?;
    final value = delta['delta_value'];
    final from = delta['delta_from'] as String?;

    if (path == null || type == null) {
      return PatchResult.failure(
        state,
        'Invalid delta: missing delta_path or delta_type',
      );
    }

    // Convert to standard JSON Patch format
    final patch = <String, dynamic>{
      'op': type,
      'path': path,
      if (value != null) 'value': value,
      if (from != null) 'from': from,
    };

    return apply(state, patch);
  }

  /// Parses a JSON Pointer path into segments.
  ///
  /// Examples:
  /// - "/" -> []
  /// - "/foo" -> ["foo"]
  /// - "/foo/0/bar" -> ["foo", "0", "bar"]
  static List<String> _parsePath(String path) {
    if (path.isEmpty || path == '/') return [];
    if (!path.startsWith('/')) {
      throw JsonPatchException('Path must start with /: $path');
    }
    // Remove leading slash and split
    return path.substring(1).split('/').map(_unescapeSegment).toList();
  }

  /// Unescapes JSON Pointer segment.
  ///
  /// Per RFC 6901:
  /// - ~1 -> /
  /// - ~0 -> ~
  static String _unescapeSegment(String segment) {
    return segment.replaceAll('~1', '/').replaceAll('~0', '~');
  }

  /// Deep copies a map to avoid mutation.
  static Map<String, dynamic> _deepCopy(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      result[entry.key] = _deepCopyValue(entry.value);
    }
    return result;
  }

  static dynamic _deepCopyValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _deepCopy(value);
    } else if (value is List) {
      return value.map(_deepCopyValue).toList();
    } else if (value is Map) {
      // Handle Map<dynamic, dynamic>
      return Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), _deepCopyValue(v))),
      );
    }
    return value;
  }

  /// Gets the value at a path, returning both the parent and the key.
  static ({dynamic parent, String key}) _getParentAndKey(
    Map<String, dynamic> state,
    List<String> segments,
  ) {
    if (segments.isEmpty) {
      throw JsonPatchException('Cannot get parent of root');
    }

    dynamic current = state;
    for (var i = 0; i < segments.length - 1; i++) {
      final segment = segments[i];
      current = _navigate(current, segment);
    }

    return (parent: current, key: segments.last);
  }

  /// Navigates to the next level in the structure.
  static dynamic _navigate(dynamic current, String segment) {
    if (current is Map<String, dynamic>) {
      if (!current.containsKey(segment)) {
        throw JsonPatchException('Path not found: $segment');
      }
      return current[segment];
    } else if (current is List) {
      final index = _parseIndex(segment, current.length);
      return current[index];
    } else {
      throw JsonPatchException('Cannot navigate into $current with $segment');
    }
  }

  /// Parses an array index from a segment.
  static int _parseIndex(String segment, int length) {
    if (segment == '-') {
      return length; // Append position
    }
    final index = int.tryParse(segment);
    if (index == null) {
      throw JsonPatchException('Invalid array index: $segment');
    }
    if (index < 0 || index > length) {
      throw JsonPatchException('Array index out of bounds: $index');
    }
    return index;
  }

  /// Adds a value at the specified path.
  static void _addAtPath(
    Map<String, dynamic> state,
    List<String> segments,
    dynamic value,
  ) {
    if (segments.isEmpty) {
      // Replace entire state
      state.clear();
      if (value is Map<String, dynamic>) {
        state.addAll(value);
      } else if (value is Map) {
        state.addAll(Map<String, dynamic>.from(value));
      }
      return;
    }

    final (:parent, :key) = _getParentAndKey(state, segments);

    if (parent is Map<String, dynamic>) {
      parent[key] = value;
    } else if (parent is List) {
      final index = _parseIndex(key, parent.length);
      if (index == parent.length || key == '-') {
        parent.add(value);
      } else {
        parent.insert(index, value);
      }
    } else {
      throw JsonPatchException('Cannot add to $parent');
    }
  }

  /// Removes the value at the specified path.
  static void _removeAtPath(
    Map<String, dynamic> state,
    List<String> segments,
  ) {
    if (segments.isEmpty) {
      state.clear();
      return;
    }

    final (:parent, :key) = _getParentAndKey(state, segments);

    if (parent is Map<String, dynamic>) {
      if (!parent.containsKey(key)) {
        throw JsonPatchException('Cannot remove non-existent key: $key');
      }
      parent.remove(key);
    } else if (parent is List) {
      final index = _parseIndex(key, parent.length);
      if (index >= parent.length) {
        throw JsonPatchException('Cannot remove index $index from list');
      }
      parent.removeAt(index);
    } else {
      throw JsonPatchException('Cannot remove from $parent');
    }
  }

  /// Replaces the value at the specified path.
  static void _replaceAtPath(
    Map<String, dynamic> state,
    List<String> segments,
    dynamic value,
  ) {
    if (segments.isEmpty) {
      state.clear();
      if (value is Map<String, dynamic>) {
        state.addAll(value);
      } else if (value is Map) {
        state.addAll(Map<String, dynamic>.from(value));
      }
      return;
    }

    final (:parent, :key) = _getParentAndKey(state, segments);

    if (parent is Map<String, dynamic>) {
      if (!parent.containsKey(key)) {
        throw JsonPatchException('Cannot replace non-existent key: $key');
      }
      parent[key] = value;
    } else if (parent is List) {
      final index = _parseIndex(key, parent.length);
      if (index >= parent.length) {
        throw JsonPatchException('Cannot replace index $index in list');
      }
      parent[index] = value;
    } else {
      throw JsonPatchException('Cannot replace in $parent');
    }
  }

  /// Gets the value at a path.
  static dynamic _getAtPath(Map<String, dynamic> state, List<String> segments) {
    if (segments.isEmpty) return state;

    dynamic current = state;
    for (final segment in segments) {
      current = _navigate(current, segment);
    }
    return current;
  }

  /// Moves a value from one path to another.
  static void _moveFromTo(
    Map<String, dynamic> state,
    List<String> from,
    List<String> to,
  ) {
    // Get value at source
    final value = _getAtPath(state, from);

    // Remove from source
    _removeAtPath(state, from);

    // Add at destination
    _addAtPath(state, to, _deepCopyValue(value));
  }

  /// Copies a value from one path to another.
  static void _copyFromTo(
    Map<String, dynamic> state,
    List<String> from,
    List<String> to,
  ) {
    // Get value at source
    final value = _getAtPath(state, from);

    // Add copy at destination
    _addAtPath(state, to, _deepCopyValue(value));
  }
}
