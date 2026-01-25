// To parse this JSON data, do
//
//     final missionState = missionStateFromJson(jsonString);

import 'package:meta/meta.dart';
import 'dart:convert';

MissionState missionStateFromJson(String str) => MissionState.fromJson(json.decode(str));

String missionStateToJson(MissionState data) => json.encode(data.toJson());


///Full mission state for detail views
class MissionState {
    List<MissionArtifact> artifacts;
    DateTime createdAt;
    String goal;
    String missionId;
    List<ApprovalRequest> pendingApprovals;
    int progressPct;
    String status;
    List<TaskItem> tasks;
    String threadId;
    DateTime updatedAt;

    MissionState({
        required this.artifacts,
        required this.createdAt,
        required this.goal,
        required this.missionId,
        required this.pendingApprovals,
        required this.progressPct,
        required this.status,
        required this.tasks,
        required this.threadId,
        required this.updatedAt,
    });

    factory MissionState.fromJson(Map<String, dynamic> json) => MissionState(
        artifacts: List<MissionArtifact>.from(json["artifacts"].map((x) => MissionArtifact.fromJson(x))),
        createdAt: DateTime.parse(json["created_at"]),
        goal: json["goal"],
        missionId: json["mission_id"],
        pendingApprovals: List<ApprovalRequest>.from(json["pending_approvals"].map((x) => ApprovalRequest.fromJson(x))),
        progressPct: json["progress_pct"],
        status: json["status"],
        tasks: List<TaskItem>.from(json["tasks"].map((x) => TaskItem.fromJson(x))),
        threadId: json["thread_id"],
        updatedAt: DateTime.parse(json["updated_at"]),
    );

    Map<String, dynamic> toJson() => {
        "artifacts": List<dynamic>.from(artifacts.map((x) => x.toJson())),
        "created_at": createdAt.toIso8601String(),
        "goal": goal,
        "mission_id": missionId,
        "pending_approvals": List<dynamic>.from(pendingApprovals.map((x) => x.toJson())),
        "progress_pct": progressPct,
        "status": status,
        "tasks": List<dynamic>.from(tasks.map((x) => x.toJson())),
        "thread_id": threadId,
        "updated_at": updatedAt.toIso8601String(),
    };
}


///An artifact produced during a mission
class MissionArtifact {
    String artifactId;
    String artifactType;
    String createdAt;
    String description;
    String name;
    String producedByTask;
    String url;

    MissionArtifact({
        required this.artifactId,
        required this.artifactType,
        required this.createdAt,
        required this.description,
        required this.name,
        required this.producedByTask,
        required this.url,
    });

    factory MissionArtifact.fromJson(Map<String, dynamic> json) => MissionArtifact(
        artifactId: json["artifact_id"],
        artifactType: json["artifact_type"],
        createdAt: json["created_at"],
        description: json["description"],
        name: json["name"],
        producedByTask: json["produced_by_task"],
        url: json["url"],
    );

    Map<String, dynamic> toJson() => {
        "artifact_id": artifactId,
        "artifact_type": artifactType,
        "created_at": createdAt,
        "description": description,
        "name": name,
        "produced_by_task": producedByTask,
        "url": url,
    };
}


///A request for human approval before proceeding
class ApprovalRequest {
    String actionType;
    String approvalId;
    String createdAt;
    String description;
    String expiresAt;
    String missionId;
    Map<String, dynamic> payload;
    String status;
    String title;

    ApprovalRequest({
        required this.actionType,
        required this.approvalId,
        required this.createdAt,
        required this.description,
        required this.expiresAt,
        required this.missionId,
        required this.payload,
        required this.status,
        required this.title,
    });

    factory ApprovalRequest.fromJson(Map<String, dynamic> json) => ApprovalRequest(
        actionType: json["action_type"],
        approvalId: json["approval_id"],
        createdAt: json["created_at"],
        description: json["description"],
        expiresAt: json["expires_at"],
        missionId: json["mission_id"],
        payload: Map.from(json["payload"]).map((k, v) => MapEntry<String, dynamic>(k, v)),
        status: json["status"],
        title: json["title"],
    );

    Map<String, dynamic> toJson() => {
        "action_type": actionType,
        "approval_id": approvalId,
        "created_at": createdAt,
        "description": description,
        "expires_at": expiresAt,
        "mission_id": missionId,
        "payload": Map.from(payload).map((k, v) => MapEntry<String, dynamic>(k, v)),
        "status": status,
        "title": title,
    };
}


///A single task in a mission's task list
class TaskItem {
    String createdAt;
    String description;
    int progressPct;
    String status;
    String taskId;
    String title;
    String updatedAt;

    TaskItem({
        required this.createdAt,
        required this.description,
        required this.progressPct,
        required this.status,
        required this.taskId,
        required this.title,
        required this.updatedAt,
    });

    factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        createdAt: json["created_at"],
        description: json["description"],
        progressPct: json["progress_pct"],
        status: json["status"],
        taskId: json["task_id"],
        title: json["title"],
        updatedAt: json["updated_at"],
    );

    Map<String, dynamic> toJson() => {
        "created_at": createdAt,
        "description": description,
        "progress_pct": progressPct,
        "status": status,
        "task_id": taskId,
        "title": title,
        "updated_at": updatedAt,
    };
}
