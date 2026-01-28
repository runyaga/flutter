import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show ChatMessage, Streaming, ToolExecution;
import 'package:soliplex_frontend/core/models/active_run_state.dart';

import 'package:soliplex_frontend/core/providers/active_run_provider.dart';
import 'package:soliplex_frontend/core/providers/rooms_provider.dart';
import 'package:soliplex_frontend/core/providers/tool_execution_providers.dart';
import 'package:soliplex_frontend/design/theme/theme_extensions.dart';
import 'package:soliplex_frontend/design/tokens/spacing.dart';
import 'package:soliplex_frontend/features/chat/widgets/chat_message_widget.dart';
import 'package:soliplex_frontend/features/chat/widgets/tool_execution_card.dart';
import 'package:soliplex_frontend/shared/widgets/empty_state.dart';
import 'package:soliplex_frontend/shared/widgets/error_display.dart';

/// Union type for items in the chat list.
///
/// Can be either a [ChatMessage] or a [ToolExecution], both rendered inline
/// in the message list sorted by timestamp.
sealed class ChatListItem {
  DateTime get timestamp;
}

/// A chat message item in the list.
class MessageItem extends ChatListItem {
  final ChatMessage message;
  MessageItem(this.message);

  @override
  DateTime get timestamp => message.createdAt;
}

/// A tool execution item in the list.
class ToolExecutionItem extends ChatListItem {
  final ToolExecution execution;
  ToolExecutionItem(this.execution);

  @override
  DateTime get timestamp => execution.startedAt;
}

/// Widget that displays the list of messages in the current thread.
///
/// Features:
/// - Scrollable list of messages using ListView.builder
/// - Auto-scrolls to bottom when new messages arrive
/// - Shows activity indicator at bottom during streaming
/// - Empty state when no messages exist
///
/// The list uses [allMessagesProvider] which merges historical messages
/// (from API) with active run messages (streaming).
///
/// Example:
/// ```dart
/// MessageList()
/// ```
class MessageList extends ConsumerStatefulWidget {
  /// Creates a message list widget.
  const MessageList({super.key});

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScrollEnabled = true;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    ref.listenManual(activeRunNotifierProvider, (previous, next) {
      if (previous == null ||
          (previous is! RunningState && next is RunningState) ||
          (previous is RunningState && next is! RunningState)) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToBottom(),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Scroll listener to manage auto-scroll state.
  /// Disables auto-scroll if user scrolls up.
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const threshold = 50.0; // Pixels from bottom to consider "at bottom"

    final isAtBottom = (maxScroll - currentScroll) <= threshold;

    if (isAtBottom && !_autoScrollEnabled) {
      setState(() {
        _autoScrollEnabled = true;
      });
    } else if (!isAtBottom && _autoScrollEnabled) {
      setState(() {
        _autoScrollEnabled = false;
      });
    }
  }

  /// Scrolls to the bottom of the list.
  /// Can be forced to scroll even if auto-scroll is disabled.
  void _scrollToBottom({bool force = false, bool animate = false}) {
    if (!force && !_autoScrollEnabled) return;

    if (!_scrollController.hasClients) return;

    // If forced, re-enable auto-scroll state
    if (force && !_autoScrollEnabled) {
      if (mounted) {
        setState(() {
          _autoScrollEnabled = true;
        });
      }
    }

    // Use a post-frame callback to ensure the list has been built/updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animate) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(allMessagesProvider);
    final messagesNow =
        messagesAsync.hasValue ? messagesAsync.value! : <ChatMessage>[];
    final isStreaming = ref.watch(isStreamingProvider);
    final runState = ref.watch(activeRunNotifierProvider);
    final roomId = ref.watch(currentRoomIdProvider);

    // Watch tool executions for the current room
    final toolExecutions = roomId != null
        ? ref.watch(toolExecutionsProvider(roomId))
        : <ToolExecution>[];

    // Build combined list of messages and tool executions, sorted by timestamp
    final chatItems = _buildChatItems(messagesNow, toolExecutions);

    // Show loading overlay, not different widget tree
    return Stack(
      children: [
        _buildMessageList(context, chatItems, isStreaming, runState, roomId),
        if (messagesAsync.isLoading && messagesNow.isEmpty)
          const Center(child: CircularProgressIndicator()),
        if (messagesAsync.hasError && messagesNow.isEmpty)
          Center(child: ErrorDisplay(error: messagesAsync.error!)),
      ],
    );
  }

  /// Builds a combined list of messages and tool executions sorted by timestamp.
  List<ChatListItem> _buildChatItems(
    List<ChatMessage> messages,
    List<ToolExecution> toolExecutions,
  ) {
    final items = <ChatListItem>[
      ...messages.map(MessageItem.new),
      ...toolExecutions.map(ToolExecutionItem.new),
    ];
    // Sort by timestamp ascending (oldest first)
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return items;
  }

  Widget _buildMessageList(
    BuildContext context,
    List<ChatListItem> items,
    bool isStreaming,
    ActiveRunState runState,
    String? roomId,
  ) {
    final soliplexTheme = SoliplexTheme.of(context);

    // Empty state
    if (items.isEmpty && !isStreaming) {
      return const EmptyState(
        message: 'No messages yet. Send one below!',
        icon: Icons.chat_bubble_outline,
      );
    }

    final streamingMessageId = switch (runState) {
      RunningState(streaming: Streaming(:final messageId)) => messageId,
      _ => null,
    };

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: SoliplexSpacing.s4),
          itemCount: items.length + (isStreaming ? 1 : 0),
          itemBuilder: (context, index) {
            // Show streaming indicator at the bottom
            if (index == items.length) {
              return Semantics(
                label: 'Assistant is thinking',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Assistant is thinking...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final item = items[index];

            // Render appropriate widget based on item type
            return switch (item) {
              MessageItem(:final message) => ChatMessageWidget(
                  key: ValueKey('msg-${message.id}'),
                  message: message,
                  roomId: roomId ?? '',
                  isStreaming: streamingMessageId == message.id,
                ),
              ToolExecutionItem(:final execution) => ToolExecutionCard(
                  key: ValueKey('tool-${execution.id}'),
                  execution: execution,
                ),
            };
          },
        ),

        // "Scroll to Bottom" button
        if (!_autoScrollEnabled)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(soliplexTheme.radii.xl),
                child: InkWell(
                  borderRadius: BorderRadius.circular(soliplexTheme.radii.xl),
                  onTap: () => _scrollToBottom(force: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(
                        soliplexTheme.radii.xl,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_downward,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Scroll to bottom',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
