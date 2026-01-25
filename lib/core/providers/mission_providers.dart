import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';

/// Family provider for task list from a room's AG-UI state.
///
/// Returns the current task list for a given room, or null if not available.
/// The task list is extracted from the AG-UI state snapshot.
///
/// **Note**: This provider requires AG-UI state integration (M09).
/// Until M09 is complete, this will return null.
///
/// **Usage**:
/// ```dart
/// final taskListAsync = ref.watch(taskListProvider(roomId));
/// ```
final taskListProvider = Provider.family<TaskList?, String>((ref, roomId) {
  // TODO(M09): Extract from AG-UI state snapshot once event processing is implemented.
  // final conversation = ref.watch(conversationProvider(roomId));
  // final stateSnapshot = conversation?.stateSnapshot;
  // if (stateSnapshot == null) return null;
  //
  // final taskListJson = stateSnapshot['task_list'];
  // if (taskListJson == null) return null;
  //
  // return TaskList.fromJson(taskListJson);
  return null;
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
/// Returns all approval requests with status `pending`.
///
/// **Note**: This provider requires AG-UI state integration (M09).
/// Until M09 is complete, this will return an empty list.
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
  // TODO(M09): Extract from AG-UI state snapshot once event processing is implemented.
  // final conversation = ref.watch(conversationProvider(roomId));
  // final stateSnapshot = conversation?.stateSnapshot;
  // if (stateSnapshot == null) return [];
  //
  // final approvalsJson = stateSnapshot['pending_approvals'] as List?;
  // if (approvalsJson == null) return [];
  //
  // return approvalsJson
  //     .map((json) => ApprovalRequest.fromJson(json))
  //     .where((a) => a.isPending)
  //     .toList();
  return [];
});

/// Family provider for the first pending approval.
///
/// Convenience provider for showing a single approval banner/dialog.
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
