import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_frontend/core/providers/mission_providers.dart';
import 'package:soliplex_frontend/core/services/steering_service.dart';

/// Widget for injecting steering messages during agent execution.
///
/// Allows users to provide mid-flight guidance to the agent without
/// starting a new conversation turn.
class SteeringInput extends ConsumerStatefulWidget {
  final String roomId;

  const SteeringInput({required this.roomId, super.key});

  @override
  ConsumerState<SteeringInput> createState() => _SteeringInputState();
}

class _SteeringInputState extends ConsumerState<SteeringInput> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final missionStatus = ref.watch(missionStatusProvider(widget.roomId));
    final isExecuting = missionStatus == MissionStatus.executing;

    if (!isExecuting) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(top: BorderSide(color: Colors.blue[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Agent is working...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Guide or correct the agent...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendSteering(),
                  enabled: !_isSending,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                onPressed: _isSending ? null : _sendSteering,
                tooltip: 'Send steering message',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendSteering() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await ref.read(steeringServiceProvider).sendSteeringToCurrent(
            roomId: widget.roomId,
            message: message,
          );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
