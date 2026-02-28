// Integration tests use print for diagnostic output.
// ignore_for_file: avoid_print
@Tags(['integration'])
library;

import 'dart:async';
import 'dart:io';

import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

/// ------------------------------------------------------------------
/// Integration test: RunOrchestrator ↔ real Soliplex backend
///
/// Validates M4 state machine against a live AG-UI SSE stream.
/// No Monty, no tool yielding — just the orchestrator processing
/// real server events.
///
/// Prerequisites:
///   1. A running Soliplex backend (local or remote, --no-auth-mode OK)
///   2. A room that streams TEXT events (no tool calls required)
///
/// Run:
///   SOLIPLEX_BASE_URL=http://localhost:8000 \
///   SOLIPLEX_ROOM_ID=plain \
///   dart test test/run/run_orchestrator_integration_test.dart -t integration
/// ------------------------------------------------------------------

/// Read env vars with optional default.
String _env(String name, [String? fallback]) {
  final value = Platform.environment[name];
  if (value != null && value.isNotEmpty) return value;
  if (fallback != null) return fallback;
  throw TestFailure(
    'Missing env var $name — set it to run integration tests',
  );
}

void main() {
  late String baseUrl;
  late String roomId;

  // Long-lived — shared across all tests (like the Flutter app does).
  late DartHttpClient restClient;
  late DartHttpClient sseClient;
  late SoliplexApi api;
  late AgUiClient agUiClient;

  // One thread for the whole suite.
  late ThreadKey sharedKey;
  late String? initialRunId;

  // Fresh per test.
  late RunOrchestrator orchestrator;

  setUpAll(() async {
    baseUrl = _env('SOLIPLEX_BASE_URL', 'http://localhost:8000');
    roomId = _env('SOLIPLEX_ROOM_ID', 'plain');

    // Wire once — same lifecycle as the Flutter app.
    restClient = DartHttpClient();
    sseClient = DartHttpClient();

    api = SoliplexApi(
      transport: HttpTransport(client: restClient),
      urlBuilder: UrlBuilder('$baseUrl/api/v1'),
    );

    agUiClient = AgUiClient(
      config: AgUiClientConfig(baseUrl: '$baseUrl/api/v1'),
      httpClient: HttpClientAdapter(client: sseClient),
    );

    // Create one thread for the entire suite.
    final (threadInfo, _) = await api.createThread(roomId);
    print('Created shared thread: ${threadInfo.id}');
    sharedKey = (
      serverId: 'default',
      roomId: roomId,
      threadId: threadInfo.id,
    );
    initialRunId = threadInfo.hasInitialRun ? threadInfo.initialRunId : null;
  });

  setUp(() {
    orchestrator = RunOrchestrator(
      api: api,
      agUiClient: agUiClient,
      toolRegistry: const ToolRegistry(),
      platformConstraints: const NativePlatformConstraints(),
      logger: _createTestLogger('integration-test'),
    );
  });

  tearDown(() {
    orchestrator.dispose();
  });

  tearDownAll(() {
    api.close();
  });

  group('M4 integration: real backend', () {
    test('Idle → Running → Completed', () async {
      final states = <RunState>[];
      orchestrator.stateChanges.listen(states.add);

      print('Starting run: room=$roomId, thread=${sharedKey.threadId}');
      await orchestrator.startRun(
        key: sharedKey,
        userMessage: 'Hello, what time is it?',
        existingRunId: initialRunId,
      );
      // Consume the initial run ID so subsequent tests create their own.
      initialRunId = null;

      await _waitForTerminalState(orchestrator, timeout: 60);

      print('States observed: ${states.map((s) => s.runtimeType).toList()}');
      expect(states.first, isA<RunningState>(), reason: 'Should start running');

      expect(
        orchestrator.currentState,
        isA<CompletedState>(),
        reason: 'Should complete successfully',
      );

      final completed = orchestrator.currentState as CompletedState;
      expect(completed.threadKey, equals(sharedKey));
      expect(completed.runId, isNotEmpty);
      expect(
        completed.conversation.messages,
        hasLength(greaterThan(1)),
        reason: 'Should have user message + agent response',
      );

      // Verify multiple RunningState emissions (streaming updates).
      final runningCount = states.whereType<RunningState>().length;
      print('RunningState emissions: $runningCount');
      expect(
        runningCount,
        greaterThan(1),
        reason: 'Should emit multiple RunningState updates as events arrive',
      );

      print(
        'Run completed. Messages: ${completed.conversation.messages.length}',
      );
      print('Final message: ${_lastAssistantText(completed.conversation)}');
    });

    test('subsequent run in same thread', () async {
      // Run 2 in the shared thread (no existingRunId — creates a new run).
      await orchestrator.startRun(
        key: sharedKey,
        userMessage: 'Now say "goodbye".',
      );
      await _waitForTerminalState(orchestrator, timeout: 60);

      expect(orchestrator.currentState, isA<CompletedState>());
      final completed = orchestrator.currentState as CompletedState;
      print('Run 2 completed: ${_lastAssistantText(completed.conversation)}');
    });

    test('reset returns to IdleState and can run again', () async {
      // Run 3.
      await orchestrator.startRun(
        key: sharedKey,
        userMessage: 'Say "ok".',
      );
      await _waitForTerminalState(orchestrator, timeout: 60);
      expect(orchestrator.currentState, isA<CompletedState>());

      final run3 = orchestrator.currentState as CompletedState;
      print('Run 3 completed: ${_lastAssistantText(run3.conversation)}');

      orchestrator.reset();
      expect(orchestrator.currentState, isA<IdleState>());

      // Run 4 — same thread, after reset.
      await orchestrator.startRun(
        key: sharedKey,
        userMessage: 'Say "ok" again.',
      );
      await _waitForTerminalState(orchestrator, timeout: 60);
      expect(orchestrator.currentState, isA<CompletedState>());

      final run4 = orchestrator.currentState as CompletedState;
      print('Run 4 completed: ${_lastAssistantText(run4.conversation)}');

      expect(run4.runId, isNot(equals(run3.runId)));
    });

    test('cancel mid-stream transitions to CancelledState',
        skip: 'Backend does not support cancellation yet', () async {
      await orchestrator.startRun(
        key: sharedKey,
        userMessage: 'Write a detailed 500 word essay about the history '
            'of computing.',
      );

      await _waitForState<RunningState>(orchestrator, timeout: 15);
      expect(orchestrator.currentState, isA<RunningState>());

      print('Cancelling mid-stream...');
      orchestrator.cancelRun();

      expect(orchestrator.currentState, isA<CancelledState>());
      final cancelled = orchestrator.currentState as CancelledState;
      expect(cancelled.threadKey, equals(sharedKey));
      print('Cancelled. Partial messages: '
          '${cancelled.conversation?.messages.length ?? 0}');
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Waits until the orchestrator reaches a terminal state (Completed, Failed,
/// or Cancelled), or throws on timeout.
Future<void> _waitForTerminalState(
  RunOrchestrator orchestrator, {
  required int timeout,
}) async {
  final completer = Completer<void>();
  final sub = orchestrator.stateChanges.listen((state) {
    if (state is CompletedState ||
        state is FailedState ||
        state is CancelledState) {
      if (!completer.isCompleted) completer.complete();
    }
  });

  try {
    await completer.future.timeout(
      Duration(seconds: timeout),
      onTimeout: () {
        throw TimeoutException(
          'Orchestrator did not reach terminal state within ${timeout}s. '
          'Current state: ${orchestrator.currentState.runtimeType}',
        );
      },
    );
  } finally {
    await sub.cancel();
  }
}

/// Waits until the orchestrator reaches a specific state type.
Future<void> _waitForState<T extends RunState>(
  RunOrchestrator orchestrator, {
  required int timeout,
}) async {
  if (orchestrator.currentState is T) return;
  final completer = Completer<void>();
  final sub = orchestrator.stateChanges.listen((state) {
    if (state is T && !completer.isCompleted) completer.complete();
  });

  try {
    await completer.future.timeout(
      Duration(seconds: timeout),
      onTimeout: () {
        throw TimeoutException(
          'Orchestrator did not reach $T within ${timeout}s. '
          'Current state: ${orchestrator.currentState.runtimeType}',
        );
      },
    );
  } finally {
    await sub.cancel();
  }
}

/// Extracts the last assistant message text for debug output.
String _lastAssistantText(Conversation conversation) {
  for (final msg in conversation.messages.reversed) {
    if (msg is TextMessage && msg.user == ChatUser.assistant) {
      return msg.text.length > 100
          ? '${msg.text.substring(0, 100)}...'
          : msg.text;
    }
  }
  return '(no assistant message found)';
}

/// Creates a real [Logger] backed by [StdoutSink] for integration output.
Logger _createTestLogger(String name) {
  final manager = LogManager.instance
    ..minimumLevel = LogLevel.debug
    ..addSink(StdoutSink());
  return manager.getLogger(name);
}
