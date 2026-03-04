import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_client/soliplex_client.dart';

import 'agent_providers.dart';
import 'room_providers.dart';

/// Active run state for the current thread.
final activeRunStateProvider =
    NotifierProvider<ActiveRunNotifier, RunState>(ActiveRunNotifier.new);

/// Whether the system is currently streaming.
final isStreamingProvider = Provider<bool>((ref) {
  return ref.watch(activeRunStateProvider).isRunning;
});

/// Whether the user can send a message right now.
final canSendMessageProvider = Provider<bool>((ref) {
  final roomId = ref.watch(currentRoomIdProvider);
  final isStreaming = ref.watch(isStreamingProvider);
  return roomId != null && !isStreaming;
});

/// All messages for the current thread.
final messagesProvider = FutureProvider<List<ChatMessage>>((ref) async {
  final roomId = ref.watch(currentRoomIdProvider);
  final threadId = ref.watch(currentThreadIdProvider);
  if (roomId == null || threadId == null) return [];

  final api = ref.watch(apiProvider);
  final history = await api.getThreadHistory(roomId, threadId);
  return history.messages;
});

/// Simplified run state for the Boiler Room client.
sealed class RunState {
  const RunState();
  bool get isRunning => false;
}

class IdleState extends RunState {
  const IdleState();
}

class StreamingRunState extends RunState {
  const StreamingRunState({
    required this.runId,
    this.currentText = '',
    this.thinkingText = '',
  });

  final String runId;
  final String currentText;
  final String thinkingText;

  @override
  bool get isRunning => true;
}

class CompletedRunState extends RunState {
  const CompletedRunState();
}

class FailedRunState extends RunState {
  const FailedRunState({required this.error});
  final String error;
}

class ActiveRunNotifier extends Notifier<RunState> {
  StreamSubscription<BaseEvent>? _subscription;

  @override
  RunState build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    return const IdleState();
  }

  /// Send a message: create thread if needed, then stream AG-UI events.
  Future<void> sendMessage({
    required String roomId,
    required String message,
    String? threadId,
  }) async {
    final api = ref.read(apiProvider);
    final agUiClient = ref.read(agUiClientProvider);

    try {
      // Create thread if none selected
      String effectiveThreadId;
      String? existingRunId;

      if (threadId != null) {
        effectiveThreadId = threadId;
      } else {
        final result = await api.createThread(roomId);
        effectiveThreadId = result.$1.id;
        existingRunId = result.$1.hasInitialRun ? result.$1.initialRunId : null;
      }

      // Update selected thread
      ref.read(currentThreadIdProvider.notifier).select(effectiveThreadId);

      // Create run (or use initial run from thread creation)
      final String runId;
      if (existingRunId != null && existingRunId.isNotEmpty) {
        runId = existingRunId;
      } else {
        final runInfo = await api.createRun(roomId, effectiveThreadId);
        runId = runInfo.id;
      }

      state = StreamingRunState(runId: runId);

      // Build the AG-UI endpoint and input
      final endpoint = 'rooms/$roomId/agui/$effectiveThreadId/$runId';

      // Get existing messages for context
      final history = await api.getThreadHistory(roomId, effectiveThreadId);
      final existingMessages = history.messages;

      // Add user message
      final userMsg = TextMessage.create(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        user: ChatUser.user,
        text: message,
      );

      final allMessages = [...existingMessages, userMsg];
      final aguiMessages = convertToAgui(allMessages);

      final input = SimpleRunAgentInput(
        threadId: effectiveThreadId,
        runId: runId,
        messages: aguiMessages,
        state: history.aguiState,
      );

      // Start streaming
      final eventStream = agUiClient.runAgent(endpoint, input);

      _subscription?.cancel();
      _subscription = eventStream.listen(
        _onEvent,
        onError: (Object error) {
          state = FailedRunState(error: error.toString());
          _onStreamDone();
        },
        onDone: _onStreamDone,
      );
    } on SoliplexException catch (e) {
      state = FailedRunState(error: e.message);
    } catch (e) {
      state = FailedRunState(error: e.toString());
    }
  }

  void _onEvent(BaseEvent event) {
    final current = state;
    if (current is! StreamingRunState) return;

    if (event is TextMessageContentEvent) {
      state = StreamingRunState(
        runId: current.runId,
        currentText: current.currentText + event.delta,
        thinkingText: current.thinkingText,
      );
    } else if (event is RunFinishedEvent) {
      state = const CompletedRunState();
      _refreshMessages();
    } else if (event is RunErrorEvent) {
      state = FailedRunState(error: event.message);
    }
  }

  void _onStreamDone() {
    _subscription = null;
    if (state is StreamingRunState) {
      state = const CompletedRunState();
      _refreshMessages();
    }
  }

  void _refreshMessages() {
    ref.invalidate(messagesProvider);
    // Return to idle after a short delay for UI feedback
    Future<void>.delayed(const Duration(milliseconds: 500)).then((_) {
      if (state is CompletedRunState) {
        state = const IdleState();
      }
    });
  }

  void cancel() {
    _subscription?.cancel();
    _subscription = null;
    state = const IdleState();
  }
}
