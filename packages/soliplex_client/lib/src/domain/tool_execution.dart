// packages/soliplex_client/lib/src/domain/tool_execution.dart

/// Status of a tool execution
enum ToolExecutionStatus {
  pending,
  running,
  completed,
  failed;

  static ToolExecutionStatus fromString(String value) {
    return ToolExecutionStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ToolExecutionStatus.pending,
    );
  }
}

/// Represents a tool execution in the AG-UI protocol
class ToolExecution {
  final String id;
  final String toolName;
  final String? description;
  final Map<String, dynamic> arguments;
  final ToolExecutionStatus status;
  final String? output;
  final String? error;
  final Duration? duration;
  final DateTime startedAt;
  final DateTime? completedAt;

  ToolExecution({
    required this.id,
    required this.toolName,
    this.description,
    required this.arguments,
    required this.status,
    this.output,
    this.error,
    this.duration,
    required this.startedAt,
    this.completedAt,
  });

  factory ToolExecution.fromEvent(Map<String, dynamic> event) {
    return ToolExecution(
      id: event['id'] as String,
      toolName: event['tool_name'] as String,
      description: event['description'] as String?,
      arguments: event['arguments'] as Map<String, dynamic>? ?? {},
      status: ToolExecutionStatus.fromString(
        event['status'] as String? ?? 'pending',
      ),
      output: event['output'] as String?,
      error: event['error'] as String?,
      duration: event['duration_ms'] != null
          ? Duration(milliseconds: event['duration_ms'] as int)
          : null,
      startedAt: DateTime.parse(event['started_at'] as String),
      completedAt: event['completed_at'] != null
          ? DateTime.parse(event['completed_at'] as String)
          : null,
    );
  }

  /// Whether the tool execution is currently running
  bool get isRunning => status == ToolExecutionStatus.running;

  /// Whether the tool execution is complete (either success or failure)
  bool get isComplete =>
      status == ToolExecutionStatus.completed ||
      status == ToolExecutionStatus.failed;

  /// Whether the tool execution has failed
  bool get hasFailed => status == ToolExecutionStatus.failed;

  /// Convert to a map representation
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tool_name': toolName,
      'description': description,
      'arguments': arguments,
      'status': status.name,
      'output': output,
      'error': error,
      'duration_ms': duration?.inMilliseconds,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  ToolExecution copyWith({
    String? id,
    String? toolName,
    String? description,
    Map<String, dynamic>? arguments,
    ToolExecutionStatus? status,
    String? output,
    String? error,
    Duration? duration,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return ToolExecution(
      id: id ?? this.id,
      toolName: toolName ?? this.toolName,
      description: description ?? this.description,
      arguments: arguments ?? this.arguments,
      status: status ?? this.status,
      output: output ?? this.output,
      error: error ?? this.error,
      duration: duration ?? this.duration,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolExecution && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
