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

/// Domain wrapper for ApprovalRequest.
class ApprovalRequest {
  final gen.ApprovalRequest _dto;

  ApprovalRequest(this._dto);

  /// Unique identifier for this approval request.
  String get id => _dto.approvalId;

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
