// To parse this JSON data, do
//
//     final missionSummary = missionSummaryFromJson(jsonString);

import 'package:meta/meta.dart';
import 'dart:convert';

MissionSummary missionSummaryFromJson(String str) =>
    MissionSummary.fromJson(json.decode(str));

String missionSummaryToJson(MissionSummary data) => json.encode(data.toJson());

///Summary of a mission for list views
class MissionSummary {
  DateTime createdAt;
  String goal;
  String missionId;
  int progressPct;
  String status;
  String threadId;
  DateTime updatedAt;

  MissionSummary({
    required this.createdAt,
    required this.goal,
    required this.missionId,
    required this.progressPct,
    required this.status,
    required this.threadId,
    required this.updatedAt,
  });

  factory MissionSummary.fromJson(Map<String, dynamic> json) => MissionSummary(
        createdAt: DateTime.parse(json["created_at"]),
        goal: json["goal"],
        missionId: json["mission_id"],
        progressPct: json["progress_pct"],
        status: json["status"],
        threadId: json["thread_id"],
        updatedAt: DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "created_at": createdAt.toIso8601String(),
        "goal": goal,
        "mission_id": missionId,
        "progress_pct": progressPct,
        "status": status,
        "thread_id": threadId,
        "updated_at": updatedAt.toIso8601String(),
      };
}
