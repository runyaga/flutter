import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';

/// Service for sending steering messages to guide running agents.
class SteeringService {
  final http.Client _client;
  final String _baseUrl;

  SteeringService(this._client, this._baseUrl);

  /// Send a steering message to the currently running mission.
  ///
  /// Steering messages are injected into the agent context mid-flight,
  /// allowing users to guide or correct the agent without starting a new turn.
  Future<void> sendSteering({
    required String roomId,
    required String missionId,
    required String message,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/rooms/$roomId/missions/$missionId/steer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode != 200) {
      throw SteeringException('Failed to send steering: ${response.body}');
    }
  }

  /// Send steering to the current (active) mission in a room.
  Future<void> sendSteeringToCurrent({
    required String roomId,
    required String message,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/v1/rooms/$roomId/missions/current/steer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode != 200) {
      throw SteeringException('Failed to send steering: ${response.body}');
    }
  }
}

/// Service for mission control operations: pause, resume, cancel.
class MissionControlService {
  final http.Client _client;
  final String _baseUrl;

  MissionControlService(this._client, this._baseUrl);

  /// Pause a running mission.
  ///
  /// The agent will complete its current operation and then halt.
  /// State is preserved for later resumption.
  Future<void> pause(String roomId, {String? missionId}) async {
    final path = missionId != null
        ? '/v1/rooms/$roomId/missions/$missionId/pause'
        : '/v1/rooms/$roomId/missions/current/pause';
    final response = await _client.post(Uri.parse('$_baseUrl$path'));
    if (response.statusCode != 200) {
      throw MissionControlException(
        'Failed to pause mission: ${response.body}',
      );
    }
  }

  /// Resume a paused mission.
  ///
  /// The agent will continue from where it left off.
  Future<void> resume(String roomId, {String? missionId}) async {
    final path = missionId != null
        ? '/v1/rooms/$roomId/missions/$missionId/resume'
        : '/v1/rooms/$roomId/missions/current/resume';
    final response = await _client.post(Uri.parse('$_baseUrl$path'));
    if (response.statusCode != 200) {
      throw MissionControlException(
        'Failed to resume mission: ${response.body}',
      );
    }
  }

  /// Cancel a running or paused mission.
  ///
  /// The agent will stop immediately. Any in-progress work may be lost.
  Future<void> cancel(String roomId, {String? missionId}) async {
    final path = missionId != null
        ? '/v1/rooms/$roomId/missions/$missionId/cancel'
        : '/v1/rooms/$roomId/missions/current/cancel';
    final response = await _client.post(Uri.parse('$_baseUrl$path'));
    if (response.statusCode != 200) {
      throw MissionControlException(
        'Failed to cancel mission: ${response.body}',
      );
    }
  }
}

/// Exception thrown when steering operations fail.
class SteeringException implements Exception {
  final String message;

  SteeringException(this.message);

  @override
  String toString() => 'SteeringException: $message';
}

/// Exception thrown when mission control operations fail.
class MissionControlException implements Exception {
  final String message;

  MissionControlException(this.message);

  @override
  String toString() => 'MissionControlException: $message';
}

// Riverpod providers

final steeringServiceProvider = Provider<SteeringService>((ref) {
  final client = ref.watch(httpClientProvider);
  final config = ref.watch(configProvider);
  return SteeringService(client, '${config.baseUrl}/api');
});

final missionControlServiceProvider = Provider<MissionControlService>((ref) {
  final client = ref.watch(httpClientProvider);
  final config = ref.watch(configProvider);
  return MissionControlService(client, '${config.baseUrl}/api');
});

/// Convenience provider that combines control operations with room context.
final missionControlProvider = Provider<MissionControlActions>((ref) {
  final controlService = ref.watch(missionControlServiceProvider);
  return MissionControlActions(controlService);
});

/// Actions wrapper for mission control with simpler API.
class MissionControlActions {
  final MissionControlService _service;

  MissionControlActions(this._service);

  Future<void> pause(String roomId) => _service.pause(roomId);
  Future<void> resume(String roomId) => _service.resume(roomId);
  Future<void> cancel(String roomId) => _service.cancel(roomId);
}
