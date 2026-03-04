import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/typography.dart';
import '../../painters/steam_particle_painter.dart';
import '../../providers/room_providers.dart';
import '../../providers/session_providers.dart';
import 'chat_input.dart';
import 'message_list.dart';

/// Main chat panel combining message list, steam particles, and input.
class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({super.key});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _steamController = SteamParticleController();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  Duration _lastTick = Duration.zero;

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    final dt = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMilliseconds / 1000.0;
    _lastTick = elapsed;

    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      _steamController.emitAmbient(renderObject.size);
    }
    _steamController.tick(dt);
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onSend(String message) {
    final roomId = ref.read(currentRoomIdProvider);
    final threadId = ref.read(currentThreadIdProvider);
    if (roomId == null) return;

    // Burst steam on send
    final size = context.size;
    if (size != null) {
      _steamController.burst(
        Offset(size.width / 2, size.height - 60),
      );
    }

    sendMessage(
      ref,
      roomId: roomId,
      message: message,
      threadId: threadId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomId = ref.watch(currentRoomIdProvider);
    final isStreaming = ref.watch(isStreamingProvider);

    if (roomId == null) {
      return Center(
        child: Text(
          'SELECT A CONDUIT TO BEGIN',
          style: BoilerTypography.oswald(
            fontSize: 16,
            color: BoilerColors.steamDim,
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Chat content
        Column(
          children: [
            const Expanded(child: MessageList()),
            Container(height: 1, color: BoilerColors.border),
            ChatInput(
              onSend: _onSend,
              enabled: !isStreaming,
            ),
          ],
        ),

        // Steam particles overlay
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: SteamParticlePainter(
                particles: _steamController.particles,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
