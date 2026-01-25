// To parse this JSON data, do
//
//     final taskItem = taskItemFromJson(jsonString);

import 'package:meta/meta.dart';
import 'dart:convert';

TaskItem taskItemFromJson(String str) => TaskItem.fromJson(json.decode(str));

String taskItemToJson(TaskItem data) => json.encode(data.toJson());


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
