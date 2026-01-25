// To parse this JSON data, do
//
//     final stateDeltaEvent = stateDeltaEventFromJson(jsonString);

import 'package:meta/meta.dart';
import 'dart:convert';

StateDeltaEvent stateDeltaEventFromJson(String str) => StateDeltaEvent.fromJson(json.decode(str));

String stateDeltaEventToJson(StateDeltaEvent data) => json.encode(data.toJson());


///Event sent when mission state changes
///
///This is streamed via SSE to update the frontend in real-time.
class StateDeltaEvent {
    String deltaPath;
    String deltaType;
    dynamic deltaValue;
    String eventType;
    String missionId;
    String timestamp;

    StateDeltaEvent({
        required this.deltaPath,
        required this.deltaType,
        required this.deltaValue,
        required this.eventType,
        required this.missionId,
        required this.timestamp,
    });

    factory StateDeltaEvent.fromJson(Map<String, dynamic> json) => StateDeltaEvent(
        deltaPath: json["delta_path"],
        deltaType: json["delta_type"],
        deltaValue: json["delta_value"],
        eventType: json["event_type"],
        missionId: json["mission_id"],
        timestamp: json["timestamp"],
    );

    Map<String, dynamic> toJson() => {
        "delta_path": deltaPath,
        "delta_type": deltaType,
        "delta_value": deltaValue,
        "event_type": eventType,
        "mission_id": missionId,
        "timestamp": timestamp,
    };
}
