// To parse this JSON data, do
//
//     final missionArtifact = missionArtifactFromJson(jsonString);

import 'package:meta/meta.dart';
import 'dart:convert';

MissionArtifact missionArtifactFromJson(String str) =>
    MissionArtifact.fromJson(json.decode(str));

String missionArtifactToJson(MissionArtifact data) =>
    json.encode(data.toJson());

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

  factory MissionArtifact.fromJson(Map<String, dynamic> json) =>
      MissionArtifact(
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
