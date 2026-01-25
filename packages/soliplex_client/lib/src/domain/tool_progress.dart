// packages/soliplex_client/lib/src/domain/tool_progress.dart

/// Progress update for a long-running tool.
///
/// Contains information about the current phase of execution,
/// progress percentage, and items processed.
class ToolProgress {
  final String toolId;
  final String phase;
  final String message;
  final double? progressPct;
  final int? itemsDone;
  final int? itemsTotal;
  final DateTime updatedAt;

  ToolProgress({
    required this.toolId,
    required this.phase,
    required this.message,
    this.progressPct,
    this.itemsDone,
    this.itemsTotal,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory ToolProgress.fromJson(Map<String, dynamic> json) {
    return ToolProgress(
      toolId: json['tool_id'] as String,
      phase: json['phase'] as String,
      message: json['message'] as String,
      progressPct: json['progress_pct'] != null
          ? (json['progress_pct'] as num).toDouble()
          : null,
      itemsDone: json['items_done'] as int?,
      itemsTotal: json['items_total'] as int?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tool_id': toolId,
      'phase': phase,
      'message': message,
      'progress_pct': progressPct,
      'items_done': itemsDone,
      'items_total': itemsTotal,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Human-readable progress text
  String get progressText {
    if (itemsTotal != null && itemsDone != null) {
      return '$itemsDone/$itemsTotal';
    }
    if (progressPct != null) {
      return '${progressPct!.toStringAsFixed(0)}%';
    }
    return phase;
  }

  /// Whether this represents an error state
  bool get isError => phase == 'error';

  /// Whether this represents a completed state
  bool get isComplete => phase == 'complete';

  /// Whether this is still in progress
  bool get isInProgress => !isComplete && !isError;

  ToolProgress copyWith({
    String? toolId,
    String? phase,
    String? message,
    double? progressPct,
    int? itemsDone,
    int? itemsTotal,
    DateTime? updatedAt,
  }) {
    return ToolProgress(
      toolId: toolId ?? this.toolId,
      phase: phase ?? this.phase,
      message: message ?? this.message,
      progressPct: progressPct ?? this.progressPct,
      itemsDone: itemsDone ?? this.itemsDone,
      itemsTotal: itemsTotal ?? this.itemsTotal,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolProgress &&
        other.toolId == toolId &&
        other.phase == phase &&
        other.message == message &&
        other.progressPct == progressPct &&
        other.itemsDone == itemsDone &&
        other.itemsTotal == itemsTotal;
  }

  @override
  int get hashCode =>
      Object.hash(toolId, phase, message, progressPct, itemsDone, itemsTotal);

  @override
  String toString() =>
      'ToolProgress(toolId: $toolId, phase: $phase, message: $message, '
      'progressPct: $progressPct, itemsDone: $itemsDone, itemsTotal: $itemsTotal)';
}
