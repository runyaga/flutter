import 'package:soliplex_client/soliplex_client.dart';

/// Resolves a room-scoped [ToolRegistry].
///
/// Different rooms have different backend tool definitions and potentially
/// different client-side tool cards. The runtime resolves the right registry
/// per room at spawn time.
///
/// The Flutter app implements this by reading room tool definitions,
/// merging with client-side tools, and returning a [ToolRegistry] with
/// executor closures that may capture Riverpod `ref` internally (opaque
/// to the runtime).
///
/// ```dart
/// final resolver = (String roomId) async {
///   final room = await api.getRoom(roomId);
///   var registry = const ToolRegistry();
///   for (final tool in room.clientTools) {
///     registry = registry.register(tool);
///   }
///   return registry;
/// };
/// ```
typedef ToolRegistryResolver = Future<ToolRegistry> Function(String roomId);
