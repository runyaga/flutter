import 'package:flutter/material.dart';
import 'package:soliplex_client/soliplex_client.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../../design/theme/steampunk_theme_extension.dart';
import '../../markdown/steampunk_markdown_renderer.dart';

/// Single message in mIRC format:
/// ```
/// [14:32] OPS> System online
/// ```
class ChatMessageWidget extends StatelessWidget {
  const ChatMessageWidget({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return switch (message) {
      TextMessage() => _TextMessageRow(message: message as TextMessage),
      ErrorMessage() => _ErrorMessageRow(message: message as ErrorMessage),
      ToolCallMessage() => _ToolCallRow(message: message as ToolCallMessage),
      LoadingMessage() => _LoadingRow(),
      GenUiMessage() => const SizedBox.shrink(),
    };
  }
}

class _TextMessageRow extends StatelessWidget {
  const _TextMessageRow({required this.message});

  final TextMessage message;

  @override
  Widget build(BuildContext context) {
    final sp = SteampunkTheme.of(context);
    final isUser = message.user == ChatUser.user;
    final nick = isUser ? 'YOU' : 'BOILER';
    final nickColor = isUser ? sp.pipeGreen : sp.furnaceOrange;
    final timestamp = _formatTime(message.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          SizedBox(
            width: 50,
            child: Text(
              '[$timestamp]',
              style: BoilerTypography.chatTimestamp,
            ),
          ),
          // Nick
          Text(
            '$nick>',
            style: BoilerTypography.sourceCodePro(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: nickColor,
            ),
          ),
          const SizedBox(width: BoilerSpacing.s2),
          // Message body
          Expanded(
            child: message.text.contains('```') ||
                    message.text.contains('**') ||
                    message.text.contains('# ')
                ? SteampunkMarkdownRenderer(data: message.text)
                : Text(
                    message.text,
                    style: BoilerTypography.chatMessage,
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ErrorMessageRow extends StatelessWidget {
  const _ErrorMessageRow({required this.message});

  final ErrorMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 50),
          const Icon(Icons.warning, size: 14, color: BoilerColors.furnaceRed),
          const SizedBox(width: BoilerSpacing.s2),
          Expanded(
            child: Text(
              'ERROR: ${message.errorText}',
              style: BoilerTypography.sourceCodePro(
                fontSize: 14,
                color: BoilerColors.furnaceRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCallRow extends StatelessWidget {
  const _ToolCallRow({required this.message});

  final ToolCallMessage message;

  @override
  Widget build(BuildContext context) {
    final sp = SteampunkTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 50),
          Icon(Icons.build, size: 14, color: sp.gaugeAmber),
          const SizedBox(width: BoilerSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final tc in message.toolCalls)
                  Text(
                    'TOOL: ${tc.name} [${tc.status.name.toUpperCase()}]',
                    style: BoilerTypography.barlowCondensed(
                      fontSize: 12,
                      color: sp.gaugeAmber,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 50),
          const SizedBox(
            width: 14,
            height: 14,
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
      ),
    );
  }
}
