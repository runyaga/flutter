// packages/soliplex_client/lib/src/domain/mission.dart
import '../generated/mission_state.dart' as gen;

/// Converts snake_case to camelCase.
String _snakeToCamel(String value) {
  final parts = value.split('_');
  if (parts.isEmpty) return value;
  return parts.first +
      parts.skip(1).map((p) => p.isNotEmpty ? '${p[0].toUpperCase()}${p.substring(1)}' : '').join();
}

/// Mission status enum matching backend.
enum MissionStatus {
  planning,
  executing,
  awaitingApproval,
  paused,
  completed,
  failed;

  static MissionStatus fromString(String value) {
    // Handle both snake_case (from backend) and camelCase
    final normalized = _snakeToCamel(value.toLowerCase());
    return MissionStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == normalized.toLowerCase(),
      orElse: () => MissionStatus.planning,
    );
  }
}

/// Domain model wrapping generated MissionState.
class Mission {
  final gen.MissionState _dto;

  Mission(this._dto);

  /// Factory to create Mission from JSON map.
  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(gen.MissionState.fromJson(json));
  }

  /// Unique mission identifier.
  String get id => _dto.missionId;

  /// Thread/room this mission belongs to.
  String get threadId => _dto.threadId;

  /// Current mission status.
  MissionStatus get status => MissionStatus.fromString(_dto.status);

  /// Mission goal/objective.
  String get goal => _dto.goal;

  /// When the mission was created.
  DateTime get createdAt => _dto.createdAt;

  /// When the mission was last updated.
  DateTime get updatedAt => _dto.updatedAt;

  /// Overall progress percentage (0-100).
  int get progressPct => _dto.progressPct;

  /// Raw task items from the DTO.
  List<gen.TaskItem> get rawTasks => _dto.tasks;

  /// Raw artifacts from the DTO.
  List<gen.MissionArtifact> get rawArtifacts => _dto.artifacts;

  /// Raw pending approvals from the DTO.
  List<gen.ApprovalRequest> get rawPendingApprovals => _dto.pendingApprovals;

  /// Whether the mission is actively executing.
  bool get isActive => status == MissionStatus.executing;

  /// Whether the mission requires human approval to proceed.
  bool get needsApproval => status == MissionStatus.awaitingApproval;

  /// Whether the mission has reached a terminal state.
  bool get isComplete =>
      status == MissionStatus.completed || status == MissionStatus.failed;

  /// Whether the mission is paused.
  bool get isPaused => status == MissionStatus.paused;

  /// Whether the mission is in the planning phase.
  bool get isPlanning => status == MissionStatus.planning;

  /// Number of tasks in this mission.
  int get taskCount => _dto.tasks.length;

  /// Number of artifacts produced.
  int get artifactCount => _dto.artifacts.length;

  /// Number of pending approval requests.
  int get pendingApprovalCount => _dto.pendingApprovals.length;

  /// Access the underlying DTO if needed.
  gen.MissionState get dto => _dto;

  @override
  String toString() =>
      'Mission(id: $id, status: $status, goal: $goal, progress: $progressPct%)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Mission && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
