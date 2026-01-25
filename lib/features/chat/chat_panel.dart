import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/core/models/active_run_state.dart';
import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/core/providers/mission_providers.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/threads_provider.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_input.dart';
import 'package:soliplex_frontend/features/chat/widgets/execution_controls.dart';
import 'package:soliplex_frontend/features/chat/widgets/message_list.dart';
import 'package:soliplex_frontend/features/chat/widgets/steering_input.dart';
import 'package:soliplex_frontend/features/mission/widgets/approval_banner.dart';
import 'package:soliplex_frontend/features/mission/widgets/task_progress_compact.dart';
import 'package:soliplex_frontend/features/mission/widgets/task_progress_expanded.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';

/// Main chat panel that combines message list and input.
///
/// This panel:
/// - Displays messages from the current thread
/// - Provides input for sending new messages
/// - Handles thread creation for new conversations
/// - Handles errors with ErrorDisplay
/// - Supports document selection for narrowing RAG searches
///
/// The panel integrates with:
/// - [currentThreadProvider] for the active thread
/// - [activeRunNotifierProvider] for streaming state
/// - [threadSelectionProvider] for thread selection state
///
/// Example:
/// ```dart
/// ChatPanel()
/// ```
class ChatPanel extends ConsumerStatefulWidget {
  /// Creates a chat panel.
  const ChatPanel({super.key});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  Set<RagDocument> _selectedDocuments = {};
  bool _taskProgressExpanded = false;

  @override
  Widget build(BuildContext context) {
    final runState = ref.watch(activeRunNotifierProvider);
    final room = ref.watch(currentRoomProvider);
    final messagesAsync = ref.watch(allMessagesProvider);
    final isStreaming = ref.watch(isStreamingProvider);
    final thread = ref.watch(currentThreadProvider);
    final threadId = thread?.id;

    // Watch task list if we have a thread
    final taskList =
        threadId != null ? ref.watch(taskListProvider(threadId)) : null;
    final hasTasks = taskList != null && taskList.tasks.isNotEmpty;
    final summary =
        threadId != null ? ref.watch(taskListSummaryProvider(threadId)) : null;

    // Show suggestions only when thread is empty and not streaming
    final messages =
        messagesAsync.hasValue ? messagesAsync.value! : <ChatMessage>[];
    final showSuggestions = messages.isEmpty && !isStreaming;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        final maxContentWidth =
            width >= SoliplexBreakpoints.desktop ? width * 2 / 3 : width;

        return Align(
          alignment: AlignmentDirectional.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                children: [
                  // Task Progress Widget (with animated visibility)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: hasTasks && threadId != null
                        ? Semantics(
                            label: _buildProgressLabel(summary),
                            child: _taskProgressExpanded
                                ? SizedBox(
                                    height: 300,
                                    child: TaskProgressExpanded(
                                      threadId: threadId,
                                      onCollapse: () => setState(
                                        () => _taskProgressExpanded = false,
                                      ),
                                    ),
                                  )
                                : TaskProgressCompact(
                                    threadId: threadId,
                                    onTap: () => setState(
                                      () => _taskProgressExpanded = true,
                                    ),
                                  ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Approval Banner (handles its own visibility)
                  if (threadId != null) ApprovalBanner(threadId: threadId),

                  // Message List
                  Expanded(
                    child: switch (runState) {
                      CompletedState(
                        result: FailedResult(:final errorMessage),
                      ) =>
                        ErrorDisplay(
                          error: errorMessage,
                          onRetry: () => _handleRetry(ref),
                        ),
                      _ => const MessageList(),
                    },
                  ),

                  // Steering Input (only visible during execution)
                  if (room != null) SteeringInput(roomId: room.id),

                  // Input with Execution Controls
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ChatInput(
                          onSend: (text) => _handleSend(context, ref, text),
                          roomId: room?.id,
                          selectedDocuments: _selectedDocuments,
                          onDocumentsChanged: (docs) {
                            setState(() {
                              _selectedDocuments = docs;
                            });
                          },
                          suggestions: room?.suggestions ?? const [],
                          showSuggestions: showSuggestions,
                        ),
                      ),
                      // Execution Controls (only visible during execution/paused)
                      if (room != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ExecutionControls(roomId: room.id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Handles sending a message.
  Future<void> _handleSend(
    BuildContext context,
    WidgetRef ref,
    String text,
  ) async {
    final room = ref.read(currentRoomProvider);
    if (room == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No room selected')));
      }
      return;
    }

    final thread = ref.read(currentThreadProvider);
    final selection = ref.read(threadSelectionProvider);

    // Create new thread if needed
    final ThreadInfo effectiveThread;
    if (thread == null || selection is NewThreadIntent) {
      final result = await _withErrorHandling(
        context,
        () => ref.read(apiProvider).createThread(room.id),
        'create thread',
      );
      switch (result) {
        case Ok(:final value):
          effectiveThread = value;
        case Err():
          return;
      }

      // Update selection to the new thread
      ref
          .read(threadSelectionProvider.notifier)
          .set(ThreadSelected(effectiveThread.id));

      // Persist last viewed and update URL
      await setLastViewedThread(
        roomId: room.id,
        threadId: effectiveThread.id,
        invalidate: invalidateLastViewed(ref),
      );
      if (context.mounted) {
        context.go('/rooms/${room.id}?thread=${effectiveThread.id}');
      }

      // Refresh threads list
      ref.invalidate(threadsProvider(room.id));
    } else {
      effectiveThread = thread;
    }

    // Build initial state with filter_documents if documents are selected
    Map<String, dynamic>? initialState;
    if (_selectedDocuments.isNotEmpty) {
      initialState = {
        'filter_documents': {
          'document_ids': _selectedDocuments.map((d) => d.id).toList(),
        },
      };
    }

    // Start the run
    if (!context.mounted) return;
    await _withErrorHandling(
      context,
      () => ref.read(activeRunNotifierProvider.notifier).startRun(
            roomId: room.id,
            threadId: effectiveThread.id,
            userMessage: text,
            existingRunId: effectiveThread.initialRunId,
            initialState: initialState,
          ),
      'send message',
    );
  }

  /// Executes an async action with standardized error handling.
  ///
  /// Shows appropriate SnackBar messages for errors.
  /// Returns [Ok] with value on success, [Err] on error.
  Future<Result<T>> _withErrorHandling<T>(
    BuildContext context,
    Future<T> Function() action,
    String operation,
  ) async {
    try {
      return Ok(await action());
    } on NetworkException catch (e, stackTrace) {
      debugPrint('Failed to $operation: Network error - ${e.message}');
      debugPrint(stackTrace.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Network error: ${e.message}')));
      }
      return Err('Network error: ${e.message}');
    } on AuthException catch (e, stackTrace) {
      debugPrint('Failed to $operation: Auth error - ${e.message}');
      debugPrint(stackTrace.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication error: ${e.message}')),
        );
      }
      return Err('Authentication error: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('Failed to $operation: $e');
      debugPrint(stackTrace.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to $operation: $e')));
      }
      return Err('$e');
    }
  }

  /// Handles retrying after an error.
  Future<void> _handleRetry(WidgetRef ref) async {
    await ref.read(activeRunNotifierProvider.notifier).reset();
  }

  /// Builds the accessibility label for task progress.
  String _buildProgressLabel(TaskListSummary? summary) {
    if (summary == null) return 'Task progress';
    final percent = summary.progressPercent.toStringAsFixed(0);
    return 'Task progress: $percent percent complete';
  }
}

// ---------------------------------------------------------------------------
// Result Type (private to this file)
// ---------------------------------------------------------------------------

/// Result type for operations that can succeed or fail.
sealed class _Result<T> {
  const _Result();
}

/// Successful result containing a value.
class Ok<T> extends _Result<T> {
  const Ok(this.value);
  final T value;
}

/// Failed result containing an error message.
class Err<T> extends _Result<T> {
  const Err(this.message);
  final String message;
}

/// Type alias for external pattern matching.
typedef Result<T> = _Result<T>;
