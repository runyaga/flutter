import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';

// Re-export ToolExecution for consumers who import this file
export 'package:soliplex_client/soliplex_client.dart'
    show ToolExecution, ToolExecutionStatus;

/// Notifier for managing tool execution state.
///
/// Accumulates tool executions as they are started and completed.
/// The state is cleared when the run ends.
class ToolExecutionNotifier extends Notifier<List<ToolExecution>> {
  @override
  List<ToolExecution> build() => [];

  /// Adds a new tool execution in running state.
  void startToolExecution({
    required String id,
    required String toolName,
    String? description,
    Map<String, dynamic> arguments = const {},
  }) {
    final execution = ToolExecution(
      id: id,
      toolName: toolName,
      description: description,
      arguments: arguments,
      status: ToolExecutionStatus.running,
      startedAt: DateTime.now(),
    );
    state = [...state, execution];
  }

  /// Appends argument data to a tool execution (from streamed ToolCallArgsEvent).
  void appendArguments({required String id, required String argsDelta}) {
    state = state.map((exec) {
      if (exec.id != id) return exec;
      // Accumulate argument deltas as a string in the 'args' key
      final currentArgs = Map<String, dynamic>.from(exec.arguments);
      final existingArgs = currentArgs['_raw'] as String? ?? '';
      currentArgs['_raw'] = existingArgs + argsDelta;
      return exec.copyWith(arguments: currentArgs);
    }).toList();
  }

  /// Parses accumulated argument deltas into proper JSON arguments.
  void finalizeArguments({required String id}) {
    state = state.map((exec) {
      if (exec.id != id) return exec;
      final rawArgs = exec.arguments['_raw'] as String?;
      if (rawArgs == null || rawArgs.isEmpty) return exec;
      try {
        final parsed = Map<String, dynamic>.from(
          (jsonDecode(rawArgs) as Map?) ?? {},
        );
        return exec.copyWith(arguments: parsed);
      } catch (_) {
        // If parsing fails, keep raw as display
        return exec.copyWith(arguments: {'raw': rawArgs});
      }
    }).toList();
  }

  /// Updates an existing tool execution with completion data.
  ///
  /// If [durationMs] is not provided, computes duration from [startedAt].
  void completeToolExecution({
    required String id,
    required bool success,
    String? output,
    String? error,
    int? durationMs,
  }) {
    final completedAt = DateTime.now();
    state = state.map((exec) {
      if (exec.id != id) return exec;
      // Compute duration from startedAt if not provided
      final duration = durationMs != null
          ? Duration(milliseconds: durationMs)
          : completedAt.difference(exec.startedAt);
      return exec.copyWith(
        status: success
            ? ToolExecutionStatus.completed
            : ToolExecutionStatus.failed,
        output: output,
        error: error,
        duration: duration,
        completedAt: completedAt,
      );
    }).toList();
  }

  /// Clears all tool executions.
  void clear() => state = [];
}

/// Provider for the tool execution notifier.
final toolExecutionNotifierProvider =
    NotifierProvider<ToolExecutionNotifier, List<ToolExecution>>(
  ToolExecutionNotifier.new,
);

/// Family provider for tool executions in a specific room.
///
/// Returns all tool executions tracked for the current active run.
/// The list includes both running and completed executions.
///
/// **Note**: The roomId parameter is currently unused but kept for API
/// compatibility with other mission providers.
///
/// **Usage**:
/// ```dart
/// final executions = ref.watch(toolExecutionsProvider(roomId));
/// for (final exec in executions) {
///   print('${exec.toolName}: ${exec.status}');
/// }
/// ```
final toolExecutionsProvider =
    Provider.family<List<ToolExecution>, String>((ref, roomId) {
  final runState = ref.watch(activeRunNotifierProvider);

  // Track previous state to detect new run starts
  ref.listen(activeRunNotifierProvider, (previous, current) {
    // Clear executions when starting a NEW run (not on every state change)
    final wasNotRunning = previous?.isRunning != true;
    final isNowRunning = current.isRunning;
    if (wasNotRunning && isNowRunning) {
      ref.read(toolExecutionNotifierProvider.notifier).clear();
    }
  });

  // Return empty when idle (no active or completed run)
  if (runState is IdleState) {
    return [];
  }
  return ref.watch(toolExecutionNotifierProvider);
});

/// Family provider for the currently running tool execution.
///
/// Returns the first tool execution with status `running`, or null if none.
///
/// **Note**: The roomId parameter is currently unused but kept for API
/// compatibility.
///
/// **Usage**:
/// ```dart
/// final activeExec = ref.watch(activeToolExecutionProvider(roomId));
/// if (activeExec != null) {
///   Text('Running: ${activeExec.toolName}');
/// }
/// ```
final activeToolExecutionProvider =
    Provider.family<ToolExecution?, String>((ref, roomId) {
  final executions = ref.watch(toolExecutionsProvider(roomId));
  for (final exec in executions) {
    if (exec.isRunning) return exec;
  }
  return null;
});

/// Family provider for recently completed tool executions.
///
/// Returns tool executions that have completed (success or failure),
/// ordered by completion time (most recent first).
///
/// **Usage**:
/// ```dart
/// final completed = ref.watch(completedToolExecutionsProvider(roomId));
/// ```
final completedToolExecutionsProvider =
    Provider.family<List<ToolExecution>, String>((ref, roomId) {
  final executions = ref.watch(toolExecutionsProvider(roomId));
  return executions.where((e) => e.isComplete).toList().reversed.toList();
});
