import 'dart:async';
import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:signals_core/signals_core.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart'
    show DartHttpClient, SoliplexApi;
import 'package:soliplex_logging/soliplex_logging.dart';

import 'package:soliplex_tui/src/components/chat_page.dart';
import 'package:soliplex_tui/src/file_sink.dart';
import 'package:soliplex_tui/src/loggers.dart';

/// Launches the Soliplex TUI application.
///
/// Builds the pure-Dart HTTP stack, resolves the target room and thread,
/// creates the [AgentRuntime], spawns an [AgentSession], and starts the
/// nocterm render loop.
Future<void> launchTui({
  required String serverUrl,
  required String logFile,
  String? roomId,
}) async {
  final fileSink = FileSink(filePath: logFile);
  LogManager.instance
    ..minimumLevel = LogLevel.trace
    ..addSink(fileSink);

  Loggers.app.info('Starting TUI, server=$serverUrl, logFile=$logFile');

  final connection = ServerConnection.create(
    serverId: 'default',
    serverUrl: serverUrl,
    httpClient: DartHttpClient(),
  );

  AgentRuntime? runtime;
  try {
    final resolvedRoomId = await _resolveRoom(connection.api, roomId);
    Loggers.app.info('Resolved room: $resolvedRoomId');

    runtime = AgentRuntime(
      connection: connection,
      toolRegistryResolver: (_) async => const ToolRegistry(),
      platform: const NativePlatformConstraints(),
      logger: Loggers.agui,
    );

    await runApp(
      SoliplexTuiApp(
        runtime: runtime,
        roomId: resolvedRoomId,
      ),
    );
  } on Exception catch (e, s) {
    Loggers.app.error('Fatal error', error: e, stackTrace: s);
    rethrow;
  } finally {
    await runtime?.dispose();
    await LogManager.instance.flush();
    await LogManager.instance.close();
    await connection.close();
  }
}

/// Runs one or more headless interactions on the same thread.
///
/// Each message in [messages] spawns a session sequentially, printing the
/// response before sending the next. This enables multi-turn conversations
/// from the command line:
///
/// ```bash
/// soliplex_tui -p "hello" -p "tell me more" -p "thanks"
/// ```
///
/// Uses [AgentRuntime.spawn] which correctly handles thread creation,
/// initial run ID resolution, and the tool execution loop.
/// All events are logged to [logFile].
Future<void> runHeadless({
  required String serverUrl,
  required String logFile,
  required List<String> messages,
  String? roomId,
  String? threadId,
  bool verbose = false,
}) async {
  final fileSink = FileSink(filePath: logFile);
  LogManager.instance
    ..minimumLevel = LogLevel.trace
    ..addSink(fileSink);
  if (verbose) {
    LogManager.instance.addSink(_StderrSink());
  }

  Loggers.app.info(
    'Starting headless mode, server=$serverUrl, logFile=$logFile',
  );

  final connection = ServerConnection.create(
    serverId: 'default',
    serverUrl: serverUrl,
    httpClient: DartHttpClient(),
  );
  AgentRuntime? runtime;

  try {
    final resolvedRoomId = roomId ?? (await _resolveRoom(connection.api, null));
    Loggers.app.info('Using room: $resolvedRoomId');

    // Resolve or create thread once — all prompts share it.
    final resolvedThreadId =
        threadId ?? (await connection.api.createThread(resolvedRoomId)).$1.id;

    runtime = AgentRuntime(
      connection: connection,
      toolRegistryResolver: (_) async => const ToolRegistry(),
      platform: const NativePlatformConstraints(),
      logger: Loggers.agui,
    );

    for (final message in messages) {
      if (verbose) stderr.writeln('[prompt] $message');

      final session = await runtime.spawn(
        roomId: resolvedRoomId,
        prompt: message,
        threadId: resolvedThreadId,
      );

      if (verbose) {
        effect(() {
          final state = session.runState.value;
          stderr.writeln('[state] ${_describeRunState(state)}');
        });
      }

      final result = await session.result;

      switch (result) {
        case AgentSuccess(:final output):
          stdout.writeln(output);
        case AgentFailure(:final error):
          stderr.writeln('Error: $error');
          exit(1);
        case AgentTimedOut(:final elapsed):
          stderr.writeln('Timed out after $elapsed');
          exit(1);
      }
    }

    // Dispose in a guarded zone to absorb async SSE stream cleanup errors.
    await runZonedGuarded(
      () => runtime!.dispose(),
      (e, s) => Loggers.agui.debug('Ignoring dispose error', error: e),
    );
    runtime = null;
  } on Exception catch (e, s) {
    Loggers.app.error('Headless fatal error', error: e, stackTrace: s);
    stderr.writeln('Error: $e');
    exit(1);
  } finally {
    await runtime?.dispose();
    await LogManager.instance.flush();
    await LogManager.instance.close();
    await connection.close();
  }
}

/// Lists available rooms from the server and prints them to [stdout].
Future<void> listRooms({
  required String serverUrl,
}) async {
  final connection = ServerConnection.create(
    serverId: 'default',
    serverUrl: serverUrl,
    httpClient: DartHttpClient(),
  );
  try {
    final rooms = await connection.api.getRooms();
    for (final room in rooms) {
      stdout.writeln('${room.id}\t${room.name}');
    }
  } finally {
    await connection.close();
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

/// Formats a [RunState] as a concise string for verbose logging.
String _describeRunState(RunState state) {
  return switch (state) {
    IdleState() => 'Idle',
    RunningState(:final streaming) => switch (streaming) {
        AwaitingText() => 'Running (awaiting text)',
        TextStreaming(:final text) => 'Running (${text.length} chars)',
      },
    ToolYieldingState(:final pendingToolCalls) =>
      'ToolYielding (${pendingToolCalls.map((t) => t.name).join(', ')})',
    CompletedState() => 'Completed',
    FailedState(:final error) => 'Failed: $error',
    CancelledState() => 'Cancelled',
  };
}

/// Log sink that writes to stderr for verbose mode.
class _StderrSink implements LogSink {
  @override
  void write(LogRecord record) {
    stderr.writeln(
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

/// Root nocterm application component.
class SoliplexTuiApp extends StatelessComponent {
  const SoliplexTuiApp({
    required this.runtime,
    required this.roomId,
    super.key,
  });

  final AgentRuntime runtime;
  final String roomId;

  @override
  Component build(BuildContext context) {
    return NoctermApp(
      title: 'Soliplex TUI',
      theme: TuiThemeData.dark,
      home: ChatPage(
        runtime: runtime,
        roomId: roomId,
      ),
    );
  }
}
