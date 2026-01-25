import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';

// Re-export MissionStatus for consumers who import this file
export 'package:soliplex_client/soliplex_client.dart' show MissionStatus;

/// Family provider for task list from a room's AG-UI state.
///
/// Returns the current task list for a given room, or null if not available.
/// The task list is extracted from the mission state snapshot received via
/// STATE_DELTA events.
///
/// **Note**: The roomId parameter is currently unused but kept for API
/// compatibility. The mission state is scoped to the active run.
///
/// **Usage**:
/// ```dart
/// final taskList = ref.watch(taskListProvider(roomId));
/// ```
final taskListProvider = Provider.family<TaskList?, String>((ref, roomId) {
  final missionState = ref.watch(missionStateProvider);
  if (missionState == null) return null;

  final taskListJson = missionState['task_list'];
  if (taskListJson == null) return null;

  try {
    return TaskList.fromJson(taskListJson as Map<String, dynamic>);
  } catch (e) {
    // Log but don't crash on malformed data
    return null;
  }
});

/// Family provider for task list summary.
///
/// Derives summary statistics from the task list for progress display.
///
/// **Usage**:
/// ```dart
/// final summaryAsync = ref.watch(taskListSummaryProvider(roomId));
/// summaryAsync?.progressPercent; // 0.0 to 100.0
/// ```
final taskListSummaryProvider =
    Provider.family<TaskListSummary?, String>((ref, roomId) {
  final tasks = ref.watch(taskListProvider(roomId));
  return tasks?.summary;
});

/// Family provider for the currently executing task.
///
/// Returns the first task with status `inProgress`, or null if none.
///
/// **Usage**:
/// ```dart
/// final currentTask = ref.watch(currentTaskProvider(roomId));
/// if (currentTask != null) {
///   Text(currentTask.activeForm); // "Running tests..."
/// }
/// ```
final currentTaskProvider = Provider.family<TaskItem?, String>((ref, roomId) {
  final tasks = ref.watch(taskListProvider(roomId));
  return tasks?.currentTask;
});

/// Family provider for pending approval requests.
///
/// Returns all approval requests with status `pending` from the mission state.
/// The list automatically updates when STATE_DELTA events modify the
/// `pending_approvals` field in the mission state.
///
/// **Note**: The roomId parameter is currently unused but kept for API
/// compatibility. The mission state is scoped to the active run.
///
/// **Usage**:
/// ```dart
/// final approvals = ref.watch(pendingApprovalsProvider(roomId));
/// if (approvals.isNotEmpty) {
///   // Show approval UI
/// }
/// ```
final pendingApprovalsProvider =
    Provider.family<List<ApprovalRequest>, String>((ref, roomId) {
  final missionState = ref.watch(missionStateProvider);
  if (missionState == null) return [];

  final approvalsJson = missionState['pending_approvals'] as List?;
  if (approvalsJson == null) return [];

  try {
    return approvalsJson
        .whereType<Map<String, dynamic>>()
        .map((json) => ApprovalRequest.fromJson(json))
        .where((a) => a.isPending)
        .toList();
  } catch (e) {
    // Log but don't crash on malformed data
    return [];
  }
});

/// Family provider for the first pending approval.
///
/// Convenience provider for showing a single approval banner/dialog.
/// Automatically updates when approvals are added/removed via STATE_DELTA.
///
/// **Usage**:
/// ```dart
/// final firstApproval = ref.watch(firstPendingApprovalProvider(roomId));
/// if (firstApproval != null) {
///   showApprovalDialog(context, firstApproval);
/// }
/// ```
final firstPendingApprovalProvider =
    Provider.family<ApprovalRequest?, String>((ref, roomId) {
  final approvals = ref.watch(pendingApprovalsProvider(roomId));
  return approvals.isEmpty ? null : approvals.first;
});

/// Family provider for current mission status.
///
/// Returns the current mission status for a given room, or null if no active mission.
/// The status is derived from the mission state snapshot received via STATE_DELTA events.
///
/// **Note**: The roomId parameter is currently unused but kept for API
/// compatibility. The mission state is scoped to the active run.
///
/// **Usage**:
/// ```dart
/// final status = ref.watch(missionStatusProvider(roomId));
/// if (status == MissionStatus.executing) {
///   // Show execution controls
/// }
/// ```
final missionStatusProvider =
    Provider.family<MissionStatus?, String>((ref, roomId) {
  final missionState = ref.watch(missionStateProvider);
  if (missionState == null) return null;

  final statusStr = missionState['status'] as String?;
  if (statusStr == null) return null;

  try {
    return MissionStatus.fromString(statusStr);
  } catch (e) {
    return null;
  }
});
