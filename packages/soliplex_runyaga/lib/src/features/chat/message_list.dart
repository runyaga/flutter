import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../../providers/session_providers.dart';
import 'chat_message_widget.dart';

/// Scrollable message list with mIRC-style rendering.
class MessageList extends ConsumerWidget {
  const MessageList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesProvider);
    final runState = ref.watch(activeRunStateProvider).value;
    final isStreaming = runState is RunningState;

    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty && runState is IdleState?) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 48,
                  color: BoilerColors.iron.withAlpha(80),
                ),
                const SizedBox(height: BoilerSpacing.s4),
                Text(
                  'AWAITING TRANSMISSION',
                  style: BoilerTypography.oswald(
                    fontSize: 16,
                    color: BoilerColors.steamDim,
                  ),
                ),
                const SizedBox(height: BoilerSpacing.s2),
                Text(
                  'Type a message to fire up the boilers',
                  style: BoilerTypography.barlowCondensed(
                    fontSize: 13,
                    color: BoilerColors.steamDim,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: BoilerSpacing.s3,
            vertical: BoilerSpacing.s2,
          ),
          itemCount: messages.length + (isStreaming ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= messages.length) {
              final streaming = runState! as RunningState;
              final text = switch (streaming.streaming) {
                TextStreaming(:final text) => text,
                _ => '',
              };
              return _StreamingIndicator(text: text);
            }
            return ChatMessageWidget(message: messages[index]);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: BoilerColors.furnaceOrange,
          strokeWidth: 2,
        ),
      ),
      error: (e, _) => Center(
        child: Text(
          'BOILER MALFUNCTION: $e',
          style: BoilerTypography.barlowCondensed(
            fontSize: 13,
            color: BoilerColors.furnaceRed,
          ),
        ),
      ),
    );
  }
}

/// Streaming indicator shown while assistant is generating.
class _StreamingIndicator extends StatelessWidget {
  const _StreamingIndicator({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BoilerSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '>>',
              style: BoilerTypography.chatTimestamp,
            ),
          ),
          Text(
            'BOILER',
            style: BoilerTypography.sourceCodePro(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: BoilerColors.furnaceOrange,
            ),
          ),
          const SizedBox(width: BoilerSpacing.s2),
          Expanded(
            child: text.isEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: BoilerColors.furnaceOrange,
                        ),
                      ),
                      const SizedBox(width: BoilerSpacing.s2),
                      Text(
                        'Building pressure...',
                        style: BoilerTypography.sourceCodePro(
                          fontSize: 14,
                          color: BoilerColors.steamDim,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: BoilerTypography.chatMessage,
                  ),
          ),
        ],
      ),
    );
  }
}
