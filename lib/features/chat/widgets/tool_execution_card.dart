import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart' hide State;

/// Card widget for displaying tool execution status and details.
///
/// Shows:
/// - Tool name with icon
/// - Status indicator (spinner for running, checkmark/X for complete)
/// - Progress section with bar and items counter (when available)
/// - Collapsible arguments section
/// - Collapsible output section
/// - Duration display
///
/// The card is collapsed by default and expands on tap to show arguments
/// and output.
class ToolExecutionCard extends StatefulWidget {
  final ToolExecution execution;
  final ToolProgress? progress;

  const ToolExecutionCard({
    required this.execution,
    this.progress,
    super.key,
  });

  @override
  State<ToolExecutionCard> createState() => _ToolExecutionCardState();
}

class _ToolExecutionCardState extends State<ToolExecutionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final exec = widget.execution;
    final progress = widget.progress;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ListTile(
            leading: _StatusIcon(status: exec.status),
            title: Text(
              exec.toolName,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            subtitle: exec.description != null ? Text(exec.description!) : null,
            trailing: _StatusBadge(status: exec.status),
            onTap: () => setState(() => _expanded = !_expanded),
          ),

          // Progress section (shown when running and progress available)
          if (exec.isRunning && progress != null)
            _ProgressSection(progress: progress),

          // Expanded content
          if (_expanded) ...[
            const Divider(height: 1),

            // Arguments (truncated for readability)
            if (exec.arguments.isNotEmpty)
              _ArgumentsSection(arguments: exec.arguments, truncate: true),

            // Output/Error
            if (exec.output != null || exec.error != null)
              _OutputSection(output: exec.output, error: exec.error),

            // Duration
            if (exec.duration != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Duration: ${exec.duration!.inMilliseconds}ms',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final ToolExecutionStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ToolExecutionStatus.pending =>
        const Icon(Icons.pending, color: Colors.grey),
      ToolExecutionStatus.running => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ToolExecutionStatus.completed =>
        const Icon(Icons.check_circle, color: Colors.green),
      ToolExecutionStatus.failed =>
        const Icon(Icons.error, color: Colors.red),
    };
  }
}

class _StatusBadge extends StatelessWidget {
  final ToolExecutionStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ToolExecutionStatus.pending => ('Pending', Colors.grey),
      ToolExecutionStatus.running => ('Running', Colors.blue),
      ToolExecutionStatus.completed => ('Done', Colors.green),
      ToolExecutionStatus.failed => ('Failed', Colors.red),
    };

    return Chip(
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Maximum characters for argument values before truncation.
const _maxArgLength = 100;

/// Truncates a JSON-encodable value for display.
///
/// If the JSON representation exceeds [maxLength], truncates to
/// [maxLength] characters and appends '...'.
String _truncateValue(dynamic value, {int maxLength = _maxArgLength}) {
  final str = value is String ? value : const JsonEncoder().convert(value);
  if (str.length <= maxLength) return str;
  return '${str.substring(0, maxLength)}...';
}

/// Truncates argument values for collapsed preview.
Map<String, dynamic> _truncateArguments(Map<String, dynamic> arguments) {
  return arguments.map((key, value) {
    if (value is String && value.length > _maxArgLength) {
      return MapEntry(key, '${value.substring(0, _maxArgLength)}...');
    } else if (value is Map || value is List) {
      final encoded = const JsonEncoder().convert(value);
      if (encoded.length > _maxArgLength) {
        return MapEntry(key, '${encoded.substring(0, _maxArgLength)}...');
      }
    }
    return MapEntry(key, value);
  });
}

class _ArgumentsSection extends StatelessWidget {
  final Map<String, dynamic> arguments;
  final bool truncate;

  const _ArgumentsSection({required this.arguments, this.truncate = false});

  @override
  Widget build(BuildContext context) {
    final displayArgs = truncate ? _truncateArguments(arguments) : arguments;
    final jsonText = const JsonEncoder.withIndent('  ').convert(displayArgs);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Arguments:', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              jsonText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputSection extends StatelessWidget {
  final String? output;
  final String? error;

  const _OutputSection({this.output, this.error});

  @override
  Widget build(BuildContext context) {
    final content = error ?? output ?? '';
    final isError = error != null;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isError ? 'Error:' : 'Output:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isError ? Colors.red : null,
                ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isError ? Colors.red[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isError ? Colors.red[900] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays progress information for a running tool.
///
/// Shows:
/// - Phase icon and message
/// - Progress bar (when progressPct available)
/// - Items counter (when itemsTotal available)
class _ProgressSection extends StatelessWidget {
  final ToolProgress progress;

  const _ProgressSection({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase and message
          Row(
            children: [
              _PhaseIcon(phase: progress.phase),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  progress.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),

          // Progress bar
          if (progress.progressPct != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.progressPct! / 100,
              backgroundColor: Colors.grey[300],
            ),
          ],

          // Items counter
          if (progress.itemsTotal != null) ...[
            const SizedBox(height: 4),
            Text(
              '${progress.itemsDone ?? 0} / ${progress.itemsTotal}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Icon representing the current phase of tool execution.
class _PhaseIcon extends StatelessWidget {
  final String phase;

  const _PhaseIcon({required this.phase});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (phase) {
      'starting' => (Icons.play_circle_outline, Colors.blue),
      'searching' => (Icons.search, Colors.orange),
      'fetching' => (Icons.download, Colors.purple),
      'processing' => (Icons.settings, Colors.indigo),
      'analyzing' => (Icons.analytics, Colors.teal),
      'writing' => (Icons.edit, Colors.green),
      'running' => (Icons.play_arrow, Colors.blue),
      'complete' => (Icons.check_circle, Colors.green),
      'error' => (Icons.error, Colors.red),
      _ => (Icons.hourglass_empty, Colors.grey),
    };

    return Icon(icon, size: 20, color: color);
  }
}
