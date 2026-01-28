import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';

import '../../../core/providers/mission_providers.dart';
import 'approval_dialog.dart';

/// Banner widget that shows when an approval request is pending.
///
/// Displays the first pending approval in the queue with a warning icon,
/// the action title, and a button to open the approval dialog.
///
/// When no approvals are pending, this widget renders as [SizedBox.shrink].
///
/// **Usage**:
/// ```dart
/// ApprovalBanner(threadId: threadId)
/// ```
class ApprovalBanner extends ConsumerWidget {
  /// The thread ID to watch for pending approvals.
  final String threadId;

  const ApprovalBanner({
    required this.threadId,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approval = ref.watch(firstPendingApprovalProvider(threadId));

    if (approval == null) {
      return const SizedBox.shrink();
    }

    return MaterialBanner(
      backgroundColor: Colors.amber[100],
      leading: const Icon(Icons.warning_amber, color: Colors.orange),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Action Required: ${approval.title}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'The agent needs your approval to continue.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _showApprovalDialog(context, approval),
          child: const Text('Review & Approve'),
        ),
      ],
    );
  }

  void _showApprovalDialog(BuildContext context, ApprovalRequest approval) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ApprovalDialog(
        approval: approval,
        threadId: threadId,
      ),
    );
  }
}
