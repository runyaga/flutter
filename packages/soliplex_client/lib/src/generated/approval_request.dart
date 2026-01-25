// To parse this JSON data, do
//
//     final approvalRequest = approvalRequestFromJson(jsonString);

import 'package:meta/meta.dart';
import 'dart:convert';

ApprovalRequest approvalRequestFromJson(String str) => ApprovalRequest.fromJson(json.decode(str));

String approvalRequestToJson(ApprovalRequest data) => json.encode(data.toJson());


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
