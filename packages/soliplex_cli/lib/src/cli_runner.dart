import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_cli/src/client_factory.dart';
import 'package:soliplex_cli/src/result_printer.dart';
import 'package:soliplex_cli/src/tool_definitions.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_logging/soliplex_logging.dart';

Future<void> runCli(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'host',
      abbr: 'H',
      help: 'Backend base URL.',
      defaultsTo:
          Platform.environment['SOLIPLEX_BASE_URL'] ?? 'http://localhost:8000',
    )
    ..addOption(
      'room',
      abbr: 'r',
      help: 'Default room ID.',
      defaultsTo: Platform.environment['SOLIPLEX_ROOM_ID'] ?? 'plain',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');

  final parsed = parser.parse(args);

  if (parsed.flag('help')) {
    stdout
      ..writeln('Usage: soliplex_cli [options]')
      ..writeln(parser.usage);
    return;
  }

  final host = parsed.option('host')!;
  final room = parsed.option('room')!;

  final bundle = createClients(host);
  final logManager = LogManager.instance
    ..minimumLevel = LogLevel.debug
    ..addSink(StdoutSink(useColors: true));
  final logger = logManager.getLogger('cli');

  final toolRegistry = buildDemoToolRegistry();
  final runtime = AgentRuntime(
    api: bundle.api,
    agUiClient: bundle.agUiClient,
    toolRegistryResolver: (_) async => toolRegistry,
    platform: const NativePlatformConstraints(),
    logger: logger,
  );

  final tracked = <AgentSession>[];

  stdout
    ..writeln('soliplex-cli connected to $host (room: $room)')
    ..writeln('tools: [secret_number, echo]')
    ..writeln();
  _printHelp();

  var forceQuit = false;

  ProcessSignal.sigint.watch().listen((_) async {
    if (forceQuit) exit(1);
    forceQuit = true;
    stdout.writeln('\nCancelling all sessions... (^C again to force)');
    await runtime.cancelAll();
  });

  await _readLoop(
    runtime: runtime,
    api: bundle.api,
    room: room,
    tracked: tracked,
  );

  await runtime.dispose();
  bundle.close();
}

Future<void> _readLoop({
  required AgentRuntime runtime,
  required SoliplexApi api,
  required String room,
  required List<AgentSession> tracked,
}) async {
  stdout.write('> ');
  await for (final line in stdin.transform(const SystemEncoding().decoder)) {
    final input = line.trim();
    if (input.isEmpty) {
      stdout.write('> ');
      continue;
    }

    if (input == '/quit' || input == '/q') break;

    await _dispatch(
      input: input,
      runtime: runtime,
      api: api,
      room: room,
      tracked: tracked,
    );

    stdout.write('> ');
  }
}

Future<void> _dispatch({
  required String input,
  required AgentRuntime runtime,
  required SoliplexApi api,
  required String room,
  required List<AgentSession> tracked,
}) async {
  if (input == '/help' || input == '/?') {
    _printHelp();
    return;
  }

  if (input == '/examples') {
    _printExamples();
    return;
  }

  if (input == '/clear') {
    stdout.write('\x1B[2J\x1B[H');
    return;
  }

  if (input == '/rooms') {
    await _listRooms(api);
    return;
  }

  if (input == '/sessions') {
    _printSessions(runtime);
    return;
  }

  if (input == '/waitall') {
    await _waitAll(runtime, tracked);
    return;
  }

  if (input == '/waitany') {
    await _waitAny(runtime, tracked);
    return;
  }

  if (input == '/cancel') {
    await runtime.cancelAll();
    tracked.clear();
    stdout.writeln('All sessions cancelled.');
    return;
  }

  if (input.startsWith('/spawn ')) {
    final prompt = input.substring('/spawn '.length).trim();
    if (prompt.isEmpty) {
      stdout.writeln('Usage: /spawn <prompt>');
      return;
    }
    await _spawnBackground(runtime, room, prompt, tracked);
    return;
  }

  if (input.startsWith('/room ')) {
    final prompt = input.substring('/room '.length).trim();
    await _sendToRoom(runtime, prompt);
    return;
  }

  // Bare text → send prompt, wait for result.
  await _sendAndWait(runtime, room, input);
}

Future<void> _sendAndWait(
  AgentRuntime runtime,
  String room,
  String prompt,
) async {
  stdout.writeln('Spawning session...');
  try {
    final session = await runtime.spawn(
      roomId: room,
      prompt: prompt,
    );
    final result = await session.awaitResult(
      timeout: const Duration(seconds: 120),
    );
    stdout.writeln(formatResult(result));
  } on Object catch (e) {
    stdout.writeln('Error: $e');
  }
}

Future<void> _spawnBackground(
  AgentRuntime runtime,
  String room,
  String prompt,
  List<AgentSession> tracked,
) async {
  try {
    final session = await runtime.spawn(
      roomId: room,
      prompt: prompt,
    );
    tracked.add(session);
    stdout.writeln(
      'Spawned session ${session.id} '
      '(${tracked.length} tracked)',
    );
  } on Object catch (e) {
    stdout.writeln('Error spawning: $e');
  }
}

Future<void> _sendToRoom(AgentRuntime runtime, String input) async {
  // Parse: <room> <prompt>
  final spaceIdx = input.indexOf(' ');
  if (spaceIdx == -1) {
    stdout.writeln('Usage: /room <roomId> <prompt>');
    return;
  }
  final targetRoom = input.substring(0, spaceIdx);
  final prompt = input.substring(spaceIdx + 1).trim();
  if (prompt.isEmpty) {
    stdout.writeln('Usage: /room <roomId> <prompt>');
    return;
  }
  stdout.writeln('Sending to room "$targetRoom"...');
  try {
    final session = await runtime.spawn(
      roomId: targetRoom,
      prompt: prompt,
    );
    final result = await session.awaitResult(
      timeout: const Duration(seconds: 120),
    );
    stdout.writeln(formatResult(result));
  } on Object catch (e) {
    stdout.writeln('Error: $e');
  }
}

Future<void> _waitAll(
  AgentRuntime runtime,
  List<AgentSession> tracked,
) async {
  if (tracked.isEmpty) {
    stdout.writeln('No tracked sessions.');
    return;
  }
  stdout.writeln('Waiting for ${tracked.length} session(s)...');
  try {
    final results = await runtime.waitAll(
      tracked,
      timeout: const Duration(seconds: 120),
    );
    for (final result in results) {
      stdout.writeln(formatResult(result));
    }
  } on Object catch (e) {
    stdout.writeln('Error: $e');
  }
  tracked.clear();
}

Future<void> _waitAny(
  AgentRuntime runtime,
  List<AgentSession> tracked,
) async {
  if (tracked.isEmpty) {
    stdout.writeln('No tracked sessions.');
    return;
  }
  stdout.writeln('Waiting for first of ${tracked.length} session(s)...');
  try {
    final result = await runtime.waitAny(
      tracked,
      timeout: const Duration(seconds: 120),
    );
    stdout.writeln(formatResult(result));
    tracked.removeWhere(
      (s) => s.threadKey == result.threadKey,
    );
    stdout.writeln('${tracked.length} session(s) remaining.');
  } on Object catch (e) {
    stdout.writeln('Error: $e');
  }
}

Future<void> _listRooms(SoliplexApi api) async {
  try {
    final rooms = await api.getRooms();
    if (rooms.isEmpty) {
      stdout.writeln('No rooms found.');
      return;
    }
    for (final room in rooms) {
      stdout.writeln('  ${room.id}  ${room.name}');
    }
  } on Object catch (e) {
    stdout.writeln('Error listing rooms: $e');
  }
}

void _printSessions(AgentRuntime runtime) {
  final sessions = runtime.activeSessions;
  if (sessions.isEmpty) {
    stdout.writeln('No active sessions.');
    return;
  }
  for (final s in sessions) {
    stdout.writeln(
      '  ${s.id}  state=${s.state}  '
      'room=${s.threadKey.roomId}',
    );
  }
}

void _printHelp() {
  stdout.writeln('''
Commands:
  <text>                   Send prompt to default room, wait for result
  /spawn <text>            Spawn background session in default room
  /room <roomId> <text>    Send prompt to a specific room
  /sessions                List active sessions
  /waitall                 Wait for all background sessions
  /waitany                 Wait for first to complete
  /cancel                  Cancel all sessions
  /rooms                   List available rooms
  /examples                Show usage examples
  /clear                   Clear terminal
  /help                    Show commands
  /quit                    Exit
''');
}

void _printExamples() {
  stdout.writeln('''
--- 1. Basic prompt (echo lifecycle) ---
  > Hello, how are you?
  Spawns a session, waits, prints SUCCESS with the response.

--- 2. Tool call (secret_number) ---
  > Call the secret_number tool and tell me what it returns
  Agent calls secret_number, CLI auto-executes it (returns "42"),
  agent incorporates the result.

--- 3. Multi-tool (chained) ---
  > First echo "hello world", then call secret_number, summarize both
  Agent chains echo + secret_number, CLI auto-executes each.

--- 4. Target a different room ---
  > /room echo-room Just say hi
  > /room tool-call-room Use the secret_number tool

--- 5. Parallel spawn + waitAll ---
  > /spawn Tell me a joke
  > /spawn What is 2+2?
  > /spawn Echo the word "alpha"
  > /sessions
  > /waitall
  Spawns 3 background sessions, /sessions shows them,
  /waitall blocks until all complete.

--- 6. Parallel spawn + waitAny (race) ---
  > /spawn Write a haiku about the ocean
  > /spawn Say hello
  > /waitany
  > /waitany
  First /waitany returns whichever finishes first.
  Second /waitany returns the remaining one.

--- 7. Cancel ---
  > /spawn Write a very long essay about computing
  > /spawn Another long essay about marine biology
  > /sessions
  > /cancel
  > /sessions
  Shows sessions active, cancels all, confirms empty.

--- 8. List rooms ---
  > /rooms
  Prints all backend rooms with id + name.

--- 9. SIGINT cancel ---
  > /spawn Some long running task
  Press Ctrl+C once to cancel gracefully.
  Press Ctrl+C again to force-exit.
''');
}
