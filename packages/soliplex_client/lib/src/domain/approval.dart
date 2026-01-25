// packages/soliplex_client/lib/src/domain/approval.dart
import '../generated/approval_request.dart' as gen;

/// Approval status enum matching backend.
enum ApprovalStatus {
  pending,
  approved,
  rejected;

  static ApprovalStatus fromString(String value) {
    return ApprovalStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ApprovalStatus.pending,
    );
  }
}

/// Represents an option in an approval dialog.
class ApprovalOption {
  /// Unique identifier for this option.
  final String id;

  /// Display label for the button.
  final String label;

  /// Whether this is a destructive action (should be styled in red).
  final bool isDestructive;

  const ApprovalOption({
    required this.id,
    required this.label,
    this.isDestructive = false,
  });

  /// Creates an ApprovalOption from JSON.
  factory ApprovalOption.fromJson(Map<String, dynamic> json) {
    return ApprovalOption(
      id: json['id'] as String? ?? json['option_id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      isDestructive: json['is_destructive'] as bool? ?? false,
    );
  }
}

/// Domain wrapper for ApprovalRequest.
class ApprovalRequest {
  final gen.ApprovalRequest _dto;

  ApprovalRequest(this._dto);

  /// Factory constructor to create ApprovalRequest from JSON.
  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(gen.ApprovalRequest.fromJson(json));
  }

  /// Unique identifier for this approval request.
  String get id => _dto.approvalId;

  /// Type of action requiring approval (alias for UI compatibility).
  String get action => _dto.title;

  /// Type of action requiring approval.
  String get actionType => _dto.actionType;

  /// Human-readable title.
  String get title => _dto.title;

  /// Detailed description of what's being requested.
  String get description => _dto.description;

  /// Current approval status.
  ApprovalStatus get status => ApprovalStatus.fromString(_dto.status);

  /// Mission this approval belongs to.
  String get missionId => _dto.missionId;

  /// Additional payload/details.
  Map<String, dynamic> get payload => _dto.payload;

  /// Technical details for display in expandable section.
  /// Returns null if no details present in payload.
  /// Only returns explicitly nested 'details' field to prevent data leakage.
  Map<String, dynamic>? get details {
    final detailsData = _dto.payload['details'];
    if (detailsData is Map<String, dynamic>) {
      return detailsData;
    }
    return null;
  }

  /// Available options for this approval.
  /// Defaults to Approve/Reject if not specified in payload or if empty.
  List<ApprovalOption> get options {
    final optionsData = _dto.payload['options'];
    if (optionsData is List && optionsData.isNotEmpty) {
      final parsed = optionsData
          .whereType<Map<String, dynamic>>()
          .map(ApprovalOption.fromJson)
          .toList();
      // Only return parsed options if we got valid ones
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    // Default options if none provided or empty
    return [
      const ApprovalOption(id: 'approve', label: 'Approve'),
      const ApprovalOption(id: 'reject', label: 'Reject', isDestructive: true),
    ];
  }

  /// When the approval request was created.
  String get createdAt => _dto.createdAt;

  /// When the approval request expires.
  String get expiresAt => _dto.expiresAt;

  /// Whether the approval is still pending.
  bool get isPending => status == ApprovalStatus.pending;

  /// Whether the approval was granted.
  bool get isApproved => status == ApprovalStatus.approved;

  /// Whether the approval was rejected.
  bool get isRejected => status == ApprovalStatus.rejected;

  /// Access the underlying DTO.
  gen.ApprovalRequest get dto => _dto;
}
