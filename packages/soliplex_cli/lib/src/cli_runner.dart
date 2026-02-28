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

  final ctx = _CliContext(
    runtime: runtime,
    api: bundle.api,
    defaultRoom: room,
  );

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

  await _readLoop(ctx);

  await runtime.dispose();
  bundle.close();
}

class _CliContext {
  _CliContext({
    required this.runtime,
    required this.api,
    required this.defaultRoom,
  });

  final AgentRuntime runtime;
  final SoliplexApi api;
  final String defaultRoom;
  final List<AgentSession> tracked = [];

  /// Active thread per room: roomId → threadId.
  final Map<String, String> threads = {};

  String? threadFor(String roomId) => threads[roomId];

  void setThread(String roomId, String threadId) {
    threads[roomId] = threadId;
  }

  void clearThread(String roomId) {
    threads.remove(roomId);
  }
}

Future<void> _readLoop(_CliContext ctx) async {
  stdout.write('> ');
  await for (final line in stdin.transform(const SystemEncoding().decoder)) {
    final input = line.trim();
    if (input.isEmpty) {
      stdout.write('> ');
      continue;
    }

    if (input == '/quit' || input == '/q') break;

    await _dispatch(ctx: ctx, input: input);

    stdout.write('> ');
  }
}

Future<void> _dispatch({
  required _CliContext ctx,
  required String input,
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
    await _listRooms(ctx.api);
    return;
  }

  if (input == '/sessions') {
    _printSessions(ctx.runtime);
    return;
  }

  if (input == '/thread') {
    _printThread(ctx);
    return;
  }

  if (input == '/new') {
    ctx.clearThread(ctx.defaultRoom);
    stdout.writeln('Cleared thread for room "${ctx.defaultRoom}".');
    return;
  }

  if (input.startsWith('/new ')) {
    final rest = input.substring('/new '.length).trim();
    if (rest.isEmpty) {
      stdout.writeln('Usage: /new [roomId] [prompt]');
      return;
    }
    final spaceIdx = rest.indexOf(' ');
    if (spaceIdx == -1) {
      // /new <roomId> — just clear the thread.
      ctx.clearThread(rest);
      stdout.writeln('Cleared thread for room "$rest".');
      return;
    }
    // /new <roomId> <prompt> — clear thread and send prompt.
    final roomId = rest.substring(0, spaceIdx);
    final prompt = rest.substring(spaceIdx + 1).trim();
    if (prompt.isEmpty) {
      ctx.clearThread(roomId);
      stdout.writeln('Cleared thread for room "$roomId".');
      return;
    }
    ctx.clearThread(roomId);
    stdout.writeln('New thread in room "$roomId".');
    await _sendAndWait(ctx, roomId, prompt);
    return;
  }

  if (input == '/waitall') {
    await _waitAll(ctx.runtime, ctx.tracked);
    return;
  }

  if (input == '/waitany') {
    await _waitAny(ctx.runtime, ctx.tracked);
    return;
  }

  if (input == '/cancel') {
    await ctx.runtime.cancelAll();
    ctx.tracked.clear();
    stdout.writeln('All sessions cancelled.');
    return;
  }

  if (input.startsWith('/spawn ')) {
    final prompt = input.substring('/spawn '.length).trim();
    if (prompt.isEmpty) {
      stdout.writeln('Usage: /spawn <prompt>');
      return;
    }
    await _spawnBackground(ctx, prompt);
    return;
  }

  if (input.startsWith('/room ')) {
    final rest = input.substring('/room '.length).trim();
    await _sendToRoom(ctx, rest);
    return;
  }

  // Bare text → send to default room, reuse thread.
  await _sendAndWait(ctx, ctx.defaultRoom, input);
}

Future<void> _sendAndWait(
  _CliContext ctx,
  String room,
  String prompt,
) async {
  final existingThread = ctx.threadFor(room);
  final label = existingThread != null
      ? 'Continuing thread ${_short(existingThread)}...'
      : 'Starting new thread...';
  stdout.writeln(label);

  try {
    final session = await ctx.runtime.spawn(
      roomId: room,
      prompt: prompt,
      threadId: existingThread,
      ephemeral: false,
    );
    ctx.setThread(room, session.threadKey.threadId);
    final result = await session.awaitResult(
      timeout: const Duration(seconds: 120),
    );
    stdout.writeln(formatResult(result));
  } on Object catch (e) {
    stdout.writeln('Error: $e');
  }
}

Future<void> _spawnBackground(_CliContext ctx, String prompt) async {
  try {
    final session = await ctx.runtime.spawn(
      roomId: ctx.defaultRoom,
      prompt: prompt,
    );
    ctx.tracked.add(session);
    stdout.writeln(
      'Spawned session ${_short(session.threadKey.threadId)} '
      '(${ctx.tracked.length} tracked)',
    );
  } on Object catch (e) {
    stdout.writeln('Error spawning: $e');
  }
}

Future<void> _sendToRoom(_CliContext ctx, String input) async {
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
  await _sendAndWait(ctx, targetRoom, prompt);
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
      '  ${_short(s.threadKey.threadId)}  '
      'state=${s.state}  room=${s.threadKey.roomId}',
    );
  }
}

void _printThread(_CliContext ctx) {
  if (ctx.threads.isEmpty) {
    stdout.writeln('No active threads.');
    return;
  }
  for (final entry in ctx.threads.entries) {
    stdout.writeln('  ${entry.key} → ${_short(entry.value)}');
  }
}

String _short(String id) => id.length > 12 ? '${id.substring(0, 12)}...' : id;

void _printHelp() {
  stdout.writeln('''
Commands:
  <text>                   Send prompt (continues current thread)
  /spawn <text>            Spawn background session (new thread)
  /room <roomId> <text>    Send prompt to a specific room
  /new [roomId] [prompt]   Start a fresh thread (optionally send prompt)
  /thread                  Show active threads per room
  /sessions                List active background sessions
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
--- 1. Conversational thread (runs reuse the same thread) ---
  > Hello, how are you?
  > What did I just say?
  Second prompt continues on the same thread.

--- 2. Start a fresh thread ---
  > /new
  > Hello again!
  Clears the thread for the default room, next prompt creates a new one.

--- 2b. New thread with immediate prompt ---
  > /new plain What is the meaning of life?
  Clears the thread for "plain" and sends the prompt in one step.

--- 3. Tool call (secret_number) ---
  > Call the secret_number tool and tell me what it returns
  Agent calls secret_number, CLI auto-executes it (returns "42"),
  agent incorporates the result.

--- 4. Multi-tool (chained) ---
  > First echo "hello world", then call secret_number, summarize both
  Agent chains echo + secret_number, CLI auto-executes each.

--- 5. Target a different room ---
  > /room echo-room Just say hi
  > /room echo-room What did I just say?
  Both prompts share the same thread in echo-room.

--- 6. Parallel spawn + waitAll ---
  > /spawn Tell me a joke
  > /spawn What is 2+2?
  > /spawn Echo the word "alpha"
  > /sessions
  > /waitall
  Each /spawn gets its own ephemeral thread.

--- 7. Parallel spawn + waitAny (race) ---
  > /spawn Write a haiku about the ocean
  > /spawn Say hello
  > /waitany
  > /waitany

--- 8. Cancel ---
  > /spawn Write a very long essay about computing
  > /sessions
  > /cancel
  > /sessions

--- 9. Show active threads ---
  > Hello!
  > /room echo-room Hi there
  > /thread
  Shows: plain -> <threadId>, echo-room -> <threadId>

--- 10. SIGINT cancel ---
  > /spawn Some long running task
  Press Ctrl+C once to cancel gracefully.
  Press Ctrl+C again to force-exit.
''');
}
