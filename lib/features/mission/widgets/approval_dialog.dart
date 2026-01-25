import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/core/services/approval_service.dart';

/// Modal dialog for reviewing and submitting approval decisions.
///
/// Shows the action title, human-readable description, optional technical
/// details (expandable JSON), and action buttons for each available option.
/// Destructive options are highlighted in red.
class ApprovalDialog extends ConsumerStatefulWidget {
  final ApprovalRequest approval;
  final String roomId;

  const ApprovalDialog({
    required this.approval,
    required this.roomId,
    super.key,
  });

  @override
  ConsumerState<ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends ConsumerState<ApprovalDialog> {
  bool _isSubmitting = false;
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.approval.action),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Description
            Text(widget.approval.description),

            // Expandable details
            if (widget.approval.details != null) ...[
              const SizedBox(height: 16),
              _DetailsExpander(
                details: widget.approval.details!,
                expanded: _showDetails,
                onToggle: () => setState(() => _showDetails = !_showDetails),
              ),
            ],
          ],
        ),
      ),
      actions: _buildActions(),
    );
  }

  List<Widget> _buildActions() {
    if (_isSubmitting) {
      return [
        // Cancel button allows user to dismiss during long operations
        TextButton(
          onPressed: () {
            setState(() => _isSubmitting = false);
          },
          child: const Text('Cancel'),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ];
    }

    // Build option buttons from approval options
    final optionButtons = widget.approval.options.map((option) {
      return TextButton(
        onPressed: () => _submitApproval(option.id),
        style: option.isDestructive
            ? TextButton.styleFrom(foregroundColor: Colors.red)
            : null,
        child: Text(option.label),
      );
    }).toList();

    // Add a dismiss button as the first action for accessibility
    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Dismiss'),
      ),
      ...optionButtons,
    ];
  }

  Future<void> _submitApproval(String optionId) async {
    setState(() => _isSubmitting = true);

    try {
      await ref.read(approvalServiceProvider).submitApproval(
            roomId: widget.roomId,
            approvalId: widget.approval.id,
            selectedOption: optionId,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }
}

/// Expandable section showing technical details in JSON format.
class _DetailsExpander extends StatelessWidget {
  final Map<String, dynamic> details;
  final bool expanded;
  final VoidCallback onToggle;

  const _DetailsExpander({
    required this.details,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Row(
            children: [
              Icon(expanded ? Icons.expand_less : Icons.expand_more),
              const SizedBox(width: 4),
              const Text('Technical Details'),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(details),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}
