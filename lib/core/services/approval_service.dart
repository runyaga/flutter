import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/config_provider.dart';

/// Default timeout for approval API calls.
const _defaultTimeout = Duration(seconds: 30);

/// Exception thrown when an approval operation fails.
class ApprovalException implements Exception {
  ApprovalException(this.message, {this.statusCode, this.isTimeout = false});

  final String message;
  final int? statusCode;
  final bool isTimeout;

  @override
  String toString() => 'ApprovalException: $message';
}

/// Service for handling approval-related API calls.
///
/// This service communicates with the backend to submit user decisions
/// for pending approval requests in the HITL (Human-in-the-Loop) workflow.
class ApprovalService {
  ApprovalService(this._client, this._baseUrl, {Duration? timeout})
      : _timeout = timeout ?? _defaultTimeout;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  /// Submits an approval decision to the backend.
  ///
  /// Parameters:
  /// - [roomId]: The room ID containing the mission
  /// - [approvalId]: The unique identifier of the approval request
  /// - [selectedOption]: The ID of the option selected by the user
  ///
  /// Throws [ApprovalException] if the request fails or times out.
  Future<void> submitApproval({
    required String roomId,
    required String approvalId,
    required String selectedOption,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/rooms/$roomId/missions/current/approve',
    );

    http.Response response;
    try {
      response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'approval_id': approvalId,
              'selected_option': selectedOption,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw ApprovalException(
        'Request timed out. Please try again.',
        isTimeout: true,
      );
    }

    if (response.statusCode != 200) {
      throw ApprovalException(
        'Failed to submit approval: ${_parseErrorMessage(response)}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Parses error message from response body safely.
  String _parseErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final detail = body['detail'];
        final message = body['message'];
        // Handle both string and structured error responses
        if (detail is String) return detail;
        if (message is String) return message;
        if (detail is Map) return detail['message']?.toString() ?? response.body;
        if (message is Map) return message['text']?.toString() ?? response.body;
      }
      return response.body;
    } catch (_) {
      return response.body.isNotEmpty ? response.body : 'Unknown error';
    }
  }
}

/// Provider for the [ApprovalService].
///
/// Uses the authenticated HTTP client and config from the app's provider graph.
final approvalServiceProvider = Provider<ApprovalService>((ref) {
  final client = ref.watch(httpClientProvider);
  final config = ref.watch(configProvider);
  final baseUrl = '${config.baseUrl}/api/v1';
  return ApprovalService(client, baseUrl);
});
