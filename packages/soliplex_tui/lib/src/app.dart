import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:nocterm_bloc/nocterm_bloc.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

import 'package:soliplex_tui/src/components/chat_page.dart';
import 'package:soliplex_tui/src/loggers.dart';
import 'package:soliplex_tui/src/state/tui_chat_cubit.dart';

/// Launches the Soliplex TUI application.
///
/// Builds the pure-Dart HTTP stack, resolves the target room and thread,
/// creates the [TuiChatCubit], and starts the nocterm render loop.
Future<void> launchTui({
  required String serverUrl,
  required String logFile,
  String? roomId,
  String? threadId,
}) async {
  final fileSink = FileSink(filePath: logFile);
  LogManager.instance
    ..minimumLevel = LogLevel.trace
    ..addSink(fileSink);

  Loggers.app.info('Starting TUI, server=$serverUrl, logFile=$logFile');

  final httpClient = DartHttpClient();
  final transport = HttpTransport(client: httpClient);
  final urlBuilder = UrlBuilder('$serverUrl/api/v1');
  final api = SoliplexApi(transport: transport, urlBuilder: urlBuilder);

  // Bridge our HTTP stack into the standard http.Client for AgUiClient.
  final adapter = HttpClientAdapter(client: httpClient);
  final agUiClient = AgUiClient(
    config: AgUiClientConfig(baseUrl: serverUrl),
    httpClient: adapter,
  );

  try {
    // Resolve room.
    final resolvedRoomId = await _resolveRoom(api, roomId);
    Loggers.app.info('Resolved room: $resolvedRoomId');

    // Resolve thread (use provided or create new).
    final resolvedThreadId = await _resolveThread(
      api,
      resolvedRoomId,
      threadId,
    );
    Loggers.app.info('Resolved thread: $resolvedThreadId');

    final cubit = TuiChatCubit(
      api: api,
      agUiClient: agUiClient,
      toolRegistry: const ToolRegistry(),
      roomId: resolvedRoomId,
      threadId: resolvedThreadId,
    );

    await runApp(
      SoliplexTuiApp(
        cubit: cubit,
        roomId: resolvedRoomId,
        threadId: resolvedThreadId,
      ),
    );
  } on Exception catch (e, s) {
    Loggers.app.error('Fatal error', error: e, stackTrace: s);
    rethrow;
  } finally {
    await LogManager.instance.flush();
    await LogManager.instance.close();
    await agUiClient.close();
    api.close();
  }
}

/// Resolves the room ID — uses the provided ID or picks the first available.
Future<String> _resolveRoom(SoliplexApi api, String? roomId) async {
  if (roomId != null) return roomId;

  final rooms = await api.getRooms();
  if (rooms.isEmpty) {
    stderr.writeln('Error: No rooms available on the server.');
    exit(1);
  }
  return rooms.first.id;
}

/// Resolves the thread ID — uses the provided ID or creates a new thread.
Future<String> _resolveThread(
  SoliplexApi api,
  String roomId,
  String? threadId,
) async {
  if (threadId != null) return threadId;

  final (thread, _) = await api.createThread(roomId);
  return thread.id;
}

/// Root nocterm application component.
class SoliplexTuiApp extends StatelessComponent {
  const SoliplexTuiApp({
    required this.cubit,
    required this.roomId,
    required this.threadId,
    super.key,
  });

  final TuiChatCubit cubit;
  final String roomId;
  final String threadId;

  @override
  Component build(BuildContext context) {
    return NoctermApp(
      title: 'Soliplex TUI',
      theme: TuiThemeData.dark,
      home: BlocProvider<TuiChatCubit>.value(
        value: cubit,
        child: ChatPage(roomId: roomId, threadId: threadId),
      ),
    );
  }
}
