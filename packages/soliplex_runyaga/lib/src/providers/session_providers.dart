import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

import 'agent_providers.dart';
import 'room_providers.dart';
import 'signal_bridge.dart';

/// Shared [AgentRuntime] — one per server connection lifetime.
final runtimeProvider = Provider<AgentRuntime>((ref) {
  final connection = ref.watch(connectionProvider);
  final runtime = AgentRuntime.fromConnection(
    connection: connection,
    toolRegistryResolver: (_) async => const ToolRegistry(),
    platform: const NativePlatformConstraints(),
    logger: LogManager.instance.getLogger('runyaga.runtime'),
  );
  ref.onDispose(runtime.dispose);
  return runtime;
});

/// The active [AgentSession] for the current chat interaction.
final activeSessionProvider =
    NotifierProvider<_ActiveSession, AgentSession?>(_ActiveSession.new);

class _ActiveSession extends Notifier<AgentSession?> {
  @override
  AgentSession? build() => null;

  void set(AgentSession? session) => state = session;
}

/// Run state stream bridged from the active session's signal.
final activeRunStateProvider = StreamProvider<RunState>((ref) {
  final session = ref.watch(activeSessionProvider);
  if (session == null) return Stream.value(const IdleState());
  return session.runState.toStream();
});

/// Session lifecycle state stream bridged from the active session's signal.
final activeSessionStateProvider = StreamProvider<AgentSessionState>((ref) {
  final session = ref.watch(activeSessionProvider);
  if (session == null) return Stream.value(AgentSessionState.spawning);
  return session.sessionState.toStream();
});

/// Whether the system is currently streaming.
final isStreamingProvider = Provider<bool>((ref) {
  final runState = ref.watch(activeRunStateProvider).value;
  return runState is RunningState;
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
  return (await api.getThreadHistory(roomId, threadId)).messages;
});

/// Sends a message via [AgentRuntime.spawn], setting the active session.
///
/// Creates a new thread if [threadId] is null. After spawning, the session
/// is set as active and its thread is auto-selected. When the run completes,
/// messages are refreshed and the thread list is invalidated.
Future<void> sendMessage(
  WidgetRef ref, {
  required String roomId,
  required String message,
  String? threadId,
}) async {
  final runtime = ref.read(runtimeProvider);

  final AgentSession session;
  try {
    session = await runtime.spawn(
      roomId: roomId,
      prompt: message,
      threadId: threadId,
      ephemeral: false,
    );
  } on Object {
    // spawn failed (network error, thread creation, etc.) — stay idle.
    return;
  }

  ref.read(activeSessionProvider.notifier).set(session);

  // Auto-select the thread created by spawn.
  final newThreadId = session.threadKey.threadId;
  ref.read(threadSelectionProvider.notifier).select(roomId, newThreadId);

  // Wait for completion (success or failure), then refresh.
  session.result.whenComplete(() {
    ref.invalidate(messagesProvider);
    ref.invalidate(threadsProvider(roomId));
    ref.read(activeSessionProvider.notifier).set(null);
  });
}

/// Cancels the active session, if any.
void cancelActiveSession(WidgetRef ref) {
  ref.read(activeSessionProvider)?.cancel();
}
