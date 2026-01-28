import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'package:soliplex_frontend/core/providers/citation_providers.dart';
import 'package:soliplex_frontend/design/design.dart';
import 'package:soliplex_frontend/features/chat/widgets/citation_chip.dart';
import 'package:soliplex_frontend/features/chat/widgets/citation_panel.dart';
import 'package:soliplex_frontend/features/chat/widgets/code_block_builder.dart';

/// Widget that displays a single chat message.
class ChatMessageWidget extends ConsumerWidget {
  const ChatMessageWidget({
    required this.message,
    required this.roomId,
    this.isStreaming = false,
    super.key,
  });

  final ChatMessage message;
  final String roomId;
  final bool isStreaming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final soliplexTheme = SoliplexTheme.of(context);

    if (message.user == ChatUser.system) {
      return _buildSystemMessage(context, theme);
    }

    final isUser = message.user == ChatUser.user;
    final text = switch (message) {
      TextMessage(:final text) => text,
      ErrorMessage(:final errorText) => errorText,
      _ => '',
    };

    // Get citations for assistant messages (not user, not streaming)
    // Note: citationsForMessageProvider returns a list directly (not a Provider)
    // Full reactive citation support will be added when ask_history state is wired
    final citations = (!isUser && !isStreaming)
        ? citationsForMessageProvider(roomId, message.id)
        : <Citation>[];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        spacing: SoliplexSpacing.s2,
        children: [
          SelectionArea(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: min(600, MediaQuery.of(context).size.width * 0.8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(soliplexTheme.radii.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    TextSelectionTheme(
                      data: TextSelectionThemeData(
                        selectionColor:
                            theme.colorScheme.onPrimaryContainer.withAlpha(
                          (0.4 * 255).toInt(),
                        ),
                        selectionHandleColor:
                            theme.colorScheme.onPrimaryContainer,
                      ),
                      child: Text(
                        text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: message is ErrorMessage
                              ? theme.colorScheme.error
                              : theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    )
                  else
                    // NOTE: Do not set selectable: true here
                    // The markdown is rendered as separate widgets,
                    // if you set selectable: true, you'll have to select
                    // each widget separately.
                    MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: theme.textTheme.bodyLarge?.copyWith(
                          color: message is ErrorMessage
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurface,
                        ),
                        code: context.monospace.copyWith(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHigh,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            soliplexTheme.radii.sm,
                          ),
                        ),
                      ),
                      builders: {
                        'code': CodeBlockBuilder(
                          preferredStyle: context.monospace.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      },
                    ),
                  if (isStreaming) ...[
                    const SizedBox(height: 8),
                    _buildStreamingIndicator(context, theme),
                  ],
                ],
              ),
            ),
          ),
          // Citations row (only for assistant messages with citations)
          if (citations.isNotEmpty) _CitationRow(citations: citations),
          if (isUser)
            _buildUserMessageActionsRow(
              context,
              messageText: text,
            )
          else if (!isUser && !isStreaming)
            _buildAgentMessageActionsRow(
              context,
              messageText: text,
            ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context, ThemeData theme) {
    final text = switch (message) {
      TextMessage(:final text) => text,
      ErrorMessage(:final errorText) => errorText,
      _ => '',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(
              SoliplexTheme.of(context).radii.md,
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserMessageActionsRow(
    BuildContext context, {
    required String messageText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        top: SoliplexSpacing.s1,
        right: SoliplexSpacing.s3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: SoliplexSpacing.s2,
        children: [
          _ActionButton(
            tooltip: 'Copy message',
            icon: Icons.copy,
            onTap: () => _copyToClipboard(context, messageText),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentMessageActionsRow(
    BuildContext context, {
    required String messageText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        top: SoliplexSpacing.s1,
        left: SoliplexSpacing.s3,
      ),
      child: Row(
        spacing: SoliplexSpacing.s2,
        children: [
          _ActionButton(
            tooltip: 'Copy message',
            icon: Icons.copy,
            onTap: () => _copyToClipboard(context, messageText),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    void showSnackBar(String message) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    try {
      await Clipboard.setData(ClipboardData(text: text));
      showSnackBar('Copied to clipboard');
    } on PlatformException catch (e, stackTrace) {
      debugPrint('Clipboard copy failed: $e\n$stackTrace');
      showSnackBar('Could not copy to clipboard');
    }
  }

  Widget _buildStreamingIndicator(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Typing...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Icon(
            icon,
            size: _iconSize,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Horizontal scrollable row of citation chips.
class _CitationRow extends StatelessWidget {
  const _CitationRow({required this.citations});

  final List<Citation> citations;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: citations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return CitationChip(
            citation: citations[index],
            onTap: () => _showCitationPanel(context, citations[index]),
          );
        },
      ),
    );
  }

  void _showCitationPanel(BuildContext context, Citation citation) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => CitationPanel(
        citation: citation,
        onClose: () => Navigator.pop(context),
      ),
    );
  }
}
