import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_tui/src/state/tui_chat_cubit.dart';
import 'package:soliplex_tui/src/state/tui_chat_state.dart';
import 'package:test/test.dart';

import '../helpers/fake_event_stream.dart';
import '../helpers/test_helpers.dart';

void main() {
  late MockSoliplexApi mockApi;
  late FakeAgUiClient fakeClient;
  late ToolRegistry toolRegistry;

  const roomId = 'room_1';
  const threadId = 'thread_1';

  setUp(() {
    mockApi = MockSoliplexApi();
    fakeClient = FakeAgUiClient();
    toolRegistry = const ToolRegistry();
  });

  TuiChatCubit buildCubit() => TuiChatCubit(
        api: mockApi,
        agUiClient: fakeClient,
        toolRegistry: toolRegistry,
        roomId: roomId,
        threadId: threadId,
      );

  void stubCreateRun({String runId = 'run_1'}) {
    when(() => mockApi.createRun(roomId, threadId))
        .thenAnswer((_) async => TestData.createRun(id: runId));
  }

  group('TuiChatCubit', () {
    test('initial state is TuiIdleState', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<TuiIdleState>());
      expect(cubit.state.messages, isEmpty);
      addTearDown(cubit.close);
    });

    blocTest<TuiChatCubit, TuiChatState>(
      'emits streaming states then idle on text response',
      setUp: () {
        stubCreateRun();
        fakeClient.onRunAgent = (_, __) => buildMockEventStream(
              textResponseEvents(),
            );
      },
      build: buildCubit,
      act: (cubit) => cubit.sendMessage('Hello'),
      expect: () => [
        isA<TuiStreamingState>(),
        isA<TuiStreamingState>(),
        isA<TuiStreamingState>(),
        isA<TuiStreamingState>(),
        isA<TuiStreamingState>(),
        isA<TuiIdleState>(),
      ],
      verify: (cubit) {
        expect(cubit.state.messages, hasLength(2));
        final assistantMsg = cubit.state.messages.last as TextMessage;
        expect(assistantMsg.text, 'Hello from assistant!');
        expect(assistantMsg.user, ChatUser.assistant);
        expect(fakeClient.runAgentCallCount, 1);
      },
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'extracts reasoning text from thinking events',
      setUp: () {
        stubCreateRun();
        fakeClient.onRunAgent = (_, __) => buildMockEventStream(
              thinkingThenTextEvents(),
            );
      },
      build: buildCubit,
      act: (cubit) => cubit.sendMessage('Think about this'),
      verify: (cubit) {
        expect(cubit.state, isA<TuiIdleState>());
        final msg = cubit.state.messages.last as TextMessage;
        expect(msg.thinkingText, 'Let me think...');
        expect(msg.text, 'Here is my answer.');
      },
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'executes tool calls and starts continuation run',
      setUp: () {
        var callCount = 0;
        when(() => mockApi.createRun(roomId, threadId))
            .thenAnswer((_) async => TestData.createRun(id: 'run_$callCount'));

        toolRegistry = const ToolRegistry().register(
          ClientTool(
            definition: const Tool(name: 'get_time', description: 'Gets time'),
            executor: (_) async => '2025-01-01T00:00:00Z',
          ),
        );

        fakeClient.onRunAgent = (_, __) {
          callCount++;
          if (callCount == 1) {
            return buildMockEventStream(
              toolCallEvents(runId: 'run_0'),
            );
          }
          return buildMockEventStream(
            textResponseEvents(text: 'The time is 2025.'),
          );
        };
      },
      build: () => TuiChatCubit(
        api: mockApi,
        agUiClient: fakeClient,
        toolRegistry: toolRegistry,
        roomId: roomId,
        threadId: threadId,
      ),
      act: (cubit) => cubit.sendMessage('What time is it?'),
      verify: (cubit) {
        expect(cubit.state, isA<TuiIdleState>());
        // user + tool call message + assistant
        expect(cubit.state.messages, hasLength(3));
        expect(fakeClient.runAgentCallCount, 2);
      },
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'circuit breaker trips after max depth',
      setUp: () {
        stubCreateRun();
        toolRegistry = const ToolRegistry().register(
          ClientTool(
            definition: const Tool(
              name: 'get_time',
              description: 'Gets time',
            ),
            executor: (_) async => 'result',
          ),
        );

        // Always return tool calls to trigger infinite continuation.
        fakeClient.onRunAgent = (_, __) => buildMockEventStream(
              toolCallEvents(),
            );
      },
      build: () => TuiChatCubit(
        api: mockApi,
        agUiClient: fakeClient,
        toolRegistry: toolRegistry,
        roomId: roomId,
        threadId: threadId,
      ),
      act: (cubit) => cubit.sendMessage('Loop forever'),
      verify: (cubit) {
        expect(cubit.state, isA<TuiErrorState>());
        expect(
          (cubit.state as TuiErrorState).errorMessage,
          contains('Circuit breaker'),
        );
        expect(fakeClient.runAgentCallCount, maxContinuationDepth);
      },
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'handles run error events',
      setUp: () {
        stubCreateRun();
        fakeClient.onRunAgent = (_, __) => buildMockEventStream(
              errorEvents(),
            );
      },
      build: buildCubit,
      act: (cubit) => cubit.sendMessage('Trigger error'),
      verify: (cubit) {
        // After RunErrorEvent the stream ends. Conversation status is Failed
        // but no pending tools, so it transitions to idle.
        expect(cubit.state, isA<TuiIdleState>());
      },
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'handles stream error',
      setUp: () {
        stubCreateRun();
        fakeClient.onRunAgent =
            (_, __) => Stream.error(Exception('Network error'));
      },
      build: buildCubit,
      act: (cubit) => cubit.sendMessage('Trigger stream error'),
      verify: (cubit) {
        expect(cubit.state, isA<TuiErrorState>());
        expect(
          (cubit.state as TuiErrorState).errorMessage,
          contains('Network error'),
        );
      },
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'cancelRun cancels active stream and returns to idle',
      setUp: () {
        stubCreateRun();
        fakeClient.onRunAgent = (_, __) => buildMockEventStream(
              textResponseEvents(),
              interEventDelay: const Duration(milliseconds: 100),
            );
      },
      build: buildCubit,
      act: (cubit) async {
        _unawaited(cubit.sendMessage('Hello'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await cubit.cancelRun();
      },
      verify: (cubit) {
        expect(cubit.state, isA<TuiIdleState>());
      },
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'toggleReasoning flips showReasoning during streaming',
      setUp: () {
        stubCreateRun();
        fakeClient.onRunAgent = (_, __) => buildMockEventStream(
              textResponseEvents(),
              interEventDelay: const Duration(milliseconds: 50),
            );
      },
      build: buildCubit,
      act: (cubit) async {
        _unawaited(cubit.sendMessage('Hello'));
        // Wait for at least one event so we're in streaming state.
        await Future<void>.delayed(const Duration(milliseconds: 120));
        cubit.toggleReasoning();
        // Wait for stream to finish.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      },
      verify: (cubit) {
        expect(cubit.state, isA<TuiIdleState>());
      },
    );

    blocTest<TuiChatCubit, TuiChatState>(
      'ignores sendMessage while already running',
      setUp: () {
        stubCreateRun();
        fakeClient.onRunAgent = (_, __) => buildMockEventStream(
              textResponseEvents(),
              interEventDelay: const Duration(milliseconds: 50),
            );
      },
      build: buildCubit,
      act: (cubit) async {
        _unawaited(cubit.sendMessage('First'));
        // Brief yield to ensure _isRunning is set.
        await Future<void>.delayed(Duration.zero);
        await cubit.sendMessage('Second');
        // Wait for first message to complete.
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      verify: (cubit) {
        expect(fakeClient.runAgentCallCount, 1);
      },
    );

    test('handles createRun API failure', () async {
      when(() => mockApi.createRun(roomId, threadId))
          .thenThrow(Exception('API down'));

      final cubit = buildCubit();
      await cubit.sendMessage('Hello');

      expect(cubit.state, isA<TuiErrorState>());
      expect(
        (cubit.state as TuiErrorState).errorMessage,
        contains('API down'),
      );

      await cubit.close();
    });
  });
}

/// Suppresses unawaited future lint for fire-and-forget calls.
void _unawaited(Future<void>? _) {}
