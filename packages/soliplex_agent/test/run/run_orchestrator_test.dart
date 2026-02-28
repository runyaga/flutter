import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSoliplexApi extends Mock implements SoliplexApi {}

class MockAgUiClient extends Mock implements AgUiClient {}

class MockLogger extends Mock implements Logger {}

class _FakeSimpleRunAgentInput extends Fake implements SimpleRunAgentInput {}

class _FakeCancelToken extends Fake implements CancelToken {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const ThreadKey _key = (
  serverId: 'srv-1',
  roomId: 'room-1',
  threadId: 'thread-1',
);

const _runId = 'run-abc';

RunInfo _runInfo() => RunInfo(
      id: _runId,
      threadId: _key.threadId,
      createdAt: DateTime(2026),
    );

List<BaseEvent> _happyPathEvents() => [
      const RunStartedEvent(threadId: 'thread-1', runId: _runId),
      const TextMessageStartEvent(messageId: 'msg-1'),
      const TextMessageContentEvent(messageId: 'msg-1', delta: 'Hello'),
      const TextMessageEndEvent(messageId: 'msg-1'),
      const RunFinishedEvent(threadId: 'thread-1', runId: _runId),
    ];

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeSimpleRunAgentInput());
    registerFallbackValue(_FakeCancelToken());
  });
  late MockSoliplexApi api;
  late MockAgUiClient agUiClient;
  late MockLogger logger;
  late RunOrchestrator orchestrator;

  setUp(() {
    api = MockSoliplexApi();
    agUiClient = MockAgUiClient();
    logger = MockLogger();
    orchestrator = RunOrchestrator(
      api: api,
      agUiClient: agUiClient,
      toolRegistry: const ToolRegistry(),
      platformConstraints: const NativePlatformConstraints(),
      logger: logger,
    );
  });

  tearDown(() {
    orchestrator.dispose();
  });

  void stubCreateRun() {
    when(() => api.createRun(any(), any())).thenAnswer(
      (_) async => _runInfo(),
    );
  }

  void stubRunAgent({required Stream<BaseEvent> stream}) {
    when(
      () => agUiClient.runAgent(
        any(),
        any(),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) => stream);
  }

  group('happy path', () {
    test('streams to CompletedState', () async {
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      await orchestrator.startRun(key: _key, userMessage: 'Hi');

      // Give stream time to complete
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<CompletedState>());
      final completed = orchestrator.currentState as CompletedState;
      expect(completed.threadKey, equals(_key));
      expect(completed.runId, equals(_runId));
    });

    test('stateChanges emits transitions', () async {
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      final states = <RunState>[];
      orchestrator.stateChanges.listen(states.add);

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      // Expect: RunningState (initial), then updates per event, CompletedState
      expect(states.first, isA<RunningState>());
      expect(states.last, isA<CompletedState>());
    });

    test('currentState matches last emission', () async {
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      RunState? lastEmitted;
      orchestrator.stateChanges.listen((s) => lastEmitted = s);

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, equals(lastEmitted));
    });

    test('existingRunId skips createRun', () async {
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      await orchestrator.startRun(
        key: _key,
        userMessage: 'Hi',
        existingRunId: _runId,
      );
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => api.createRun(any(), any()));
      expect(orchestrator.currentState, isA<CompletedState>());
    });
  });

  group('error', () {
    test('RunErrorEvent transitions to FailedState(serverError)', () async {
      stubCreateRun();
      stubRunAgent(
        stream: Stream.fromIterable([
          const RunStartedEvent(threadId: 'thread-1', runId: _runId),
          const RunErrorEvent(message: 'backend error'),
        ]),
      );

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<FailedState>());
      final failed = orchestrator.currentState as FailedState;
      expect(failed.reason, equals(FailureReason.serverError));
      expect(failed.error, equals('backend error'));
    });

    test('HTTP 401 TransportError transitions to FailedState(authExpired)',
        () async {
      stubCreateRun();
      stubRunAgent(
        stream: Stream.error(
          const TransportError('Unauthorized', statusCode: 401),
        ),
      );

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<FailedState>());
      final failed = orchestrator.currentState as FailedState;
      expect(failed.reason, equals(FailureReason.authExpired));
    });

    test('HTTP 429 TransportError transitions to FailedState(rateLimited)',
        () async {
      stubCreateRun();
      stubRunAgent(
        stream: Stream.error(
          const TransportError('Too many requests', statusCode: 429),
        ),
      );

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<FailedState>());
      final failed = orchestrator.currentState as FailedState;
      expect(failed.reason, equals(FailureReason.rateLimited));
    });

    test('stream ends without terminal event transitions to networkLost',
        () async {
      stubCreateRun();
      stubRunAgent(
        stream: Stream.fromIterable([
          const RunStartedEvent(threadId: 'thread-1', runId: _runId),
          const TextMessageStartEvent(messageId: 'msg-1'),
        ]),
      );

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<FailedState>());
      final failed = orchestrator.currentState as FailedState;
      expect(failed.reason, equals(FailureReason.networkLost));
    });

    test('createRun throws transitions to FailedState', () async {
      when(() => api.createRun(any(), any())).thenThrow(
        const AuthException(message: 'Token expired'),
      );

      await orchestrator.startRun(key: _key, userMessage: 'Hi');

      expect(orchestrator.currentState, isA<FailedState>());
      final failed = orchestrator.currentState as FailedState;
      expect(failed.reason, equals(FailureReason.authExpired));
    });
  });

  group('cancel', () {
    test('cancelRun transitions to CancelledState', () async {
      stubCreateRun();
      final controller = StreamController<BaseEvent>();
      stubRunAgent(stream: controller.stream);

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      controller.add(
        const RunStartedEvent(threadId: 'thread-1', runId: _runId),
      );
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<RunningState>());

      orchestrator.cancelRun();

      expect(orchestrator.currentState, isA<CancelledState>());
      final cancelled = orchestrator.currentState as CancelledState;
      expect(cancelled.threadKey, equals(_key));
      expect(cancelled.conversation, isNotNull);

      await controller.close();
    });

    test('cancelRun while idle is a no-op', () {
      expect(orchestrator.currentState, isA<IdleState>());
      orchestrator.cancelRun();
      expect(orchestrator.currentState, isA<IdleState>());
    });
  });

  group('guard', () {
    test('startRun while running throws StateError', () async {
      stubCreateRun();
      final controller = StreamController<BaseEvent>();
      stubRunAgent(stream: controller.stream);

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      controller.add(
        const RunStartedEvent(threadId: 'thread-1', runId: _runId),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        () => orchestrator.startRun(key: _key, userMessage: 'Again'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already active'),
          ),
        ),
      );

      await controller.close();
    });
  });

  group('reset', () {
    test('reset transitions to IdleState', () async {
      stubCreateRun();
      stubRunAgent(stream: Stream.fromIterable(_happyPathEvents()));

      await orchestrator.startRun(key: _key, userMessage: 'Hi');
      await Future<void>.delayed(Duration.zero);

      expect(orchestrator.currentState, isA<CompletedState>());

      orchestrator.reset();

      expect(orchestrator.currentState, isA<IdleState>());
    });
  });

  group('dispose', () {
    test('cleans up resources', () async {
      orchestrator.dispose();

      expect(
        () => orchestrator.startRun(key: _key, userMessage: 'Hi'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('disposed'),
          ),
        ),
      );
    });

    test('stateChanges stream closes on dispose', () async {
      final done = Completer<void>();
      orchestrator.stateChanges.listen(
        null,
        onDone: done.complete,
      );

      orchestrator.dispose();

      await expectLater(done.future, completes);
    });
  });
}
