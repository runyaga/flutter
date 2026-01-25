// To parse this JSON data, do
//
//     final taskList = taskListFromJson(jsonString);

import 'package:meta/meta.dart';
import 'dart:convert';

TaskList taskListFromJson(String str) => TaskList.fromJson(json.decode(str));

String taskListToJson(TaskList data) => json.encode(data.toJson());


///List of tasks for a mission
class TaskList {
    String missionId;
    List<TaskItem> tasks;

    TaskList({
        required this.missionId,
        required this.tasks,
    });

    factory TaskList.fromJson(Map<String, dynamic> json) => TaskList(
        missionId: json["mission_id"],
        tasks: List<TaskItem>.from(json["tasks"].map((x) => TaskItem.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "mission_id": missionId,
        "tasks": List<dynamic>.from(tasks.map((x) => x.toJson())),
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
