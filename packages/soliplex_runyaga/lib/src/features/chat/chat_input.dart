import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../../design/theme/steampunk_theme_extension.dart';
import '../../painters/hex_bolt_painter.dart';

/// Steampunk chat input — pipe-styled text field with send lever.
class ChatInput extends StatefulWidget {
  const ChatInput({
    required this.onSend,
    this.enabled = true,
    super.key,
  });

  final void Function(String message) onSend;
  final bool enabled;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final sp = SteampunkTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(BoilerSpacing.s2),
      color: BoilerColors.surface,
      child: Row(
        children: [
          // Left bolt decoration
          CustomPaint(
            size: const Size(16, 16),
            painter: HexBoltPainter(
              color: sp.iron,
              highlightColor: sp.ironLight,
            ),
          ),
          const SizedBox(width: BoilerSpacing.s2),

          // Input pipe
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _send();
                }
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                style: BoilerTypography.sourceCodePro(fontSize: 14),
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: widget.enabled
                      ? 'Type your dispatch...'
                      : 'Boilers running...',
                  filled: true,
                  fillColor: BoilerColors.codeBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: BoilerSpacing.s3,
                    vertical: BoilerSpacing.s2,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: const BorderSide(color: BoilerColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: const BorderSide(color: BoilerColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: const BorderSide(
                      color: BoilerColors.furnaceOrange,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: BoilerSpacing.s2),

          // Send lever
          _SendLever(
            onPressed: widget.enabled ? _send : null,
            sp: sp,
          ),

          const SizedBox(width: BoilerSpacing.s2),
          // Right bolt decoration
          CustomPaint(
            size: const Size(16, 16),
            painter: HexBoltPainter(
              color: sp.iron,
              highlightColor: sp.ironLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lever-styled send button.
class _SendLever extends StatelessWidget {
  const _SendLever({required this.onPressed, required this.sp});

  final VoidCallback? onPressed;
  final SteampunkTheme sp;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: onPressed != null
              ? BoilerColors.rust
              : BoilerColors.iron.withAlpha(80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: BoilerSpacing.s4),
        ),
        child: Text(
          'SEND',
          style: BoilerTypography.oswald(
            fontSize: 14,
            color: onPressed != null ? sp.steamWhite : sp.steamDim,
          ),
        ),
      ),
    );
  }
}
