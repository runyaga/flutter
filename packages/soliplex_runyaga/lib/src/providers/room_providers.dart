import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart';

import 'agent_providers.dart';

/// All rooms from the backend.
final roomsProvider = FutureProvider<List<Room>>((ref) async {
  final api = ref.watch(apiProvider);
  return api.getRooms();
});

/// Currently selected room ID.
final currentRoomIdProvider =
    NotifierProvider<_CurrentRoomId, String?>(_CurrentRoomId.new);

class _CurrentRoomId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? roomId) => state = roomId;
}

/// The current Room object (derived).
final currentRoomProvider = Provider<Room?>((ref) {
  final roomId = ref.watch(currentRoomIdProvider);
  if (roomId == null) return null;
  final roomsAsync = ref.watch(roomsProvider);
  final rooms = roomsAsync.value;
  if (rooms == null) return null;
  for (final room in rooms) {
    if (room.id == roomId) return room;
  }
  return null;
});

/// Threads for a given room.
final threadsProvider =
    FutureProvider.family<List<ThreadInfo>, String>((ref, roomId) async {
  final api = ref.watch(apiProvider);
  final threads = await api.getThreads(roomId);
  threads.sort((a, b) {
    final cmp = b.createdAt.compareTo(a.createdAt);
    return cmp != 0 ? cmp : a.id.compareTo(b.id);
  });
  return threads;
});

/// Per-room thread selection: `roomId → threadId`.
final threadSelectionProvider =
    NotifierProvider<_ThreadSelection, Map<String, String?>>(
  _ThreadSelection.new,
);

class _ThreadSelection extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() => {};

  void select(String roomId, String? threadId) {
    state = {...state, roomId: threadId};
  }
}

/// Currently selected thread ID (derived from room + selection map).
final currentThreadIdProvider = Provider<String?>((ref) {
  final roomId = ref.watch(currentRoomIdProvider);
  if (roomId == null) return null;
  final selections = ref.watch(threadSelectionProvider);
  return selections[roomId];
});

/// Nicknames/users in the current room (placeholder).
final nickListProvider = Provider<List<String>>((ref) {
  return const ['@engineer1', '+operator1', 'worker1'];
});
