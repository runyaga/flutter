import 'package:mocktail/mocktail.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

/// Integration test: [ChatFnLlmProvider] + [RunOrchestrator].
///
/// Proves the full tool-yield/resume cycle works without a server.
void main() {
  const key = (
    serverId: 'local',
    roomId: 'test-room',
    threadId: 'test-thread',
  );

  late RunOrchestrator orchestrator;
  late _MockLogger logger;

  setUp(() {
    logger = _MockLogger();
  });

  tearDown(() {
    orchestrator.dispose();
  });

  ChatFnLlmProvider providerWith(ChatFn chatFn) =>
      ChatFnLlmProvider(chatFn: chatFn);

  group('ChatFnLlmProvider + RunOrchestrator', () {
    test('text response → CompletedState', () async {
      orchestrator = RunOrchestrator(
        llmProvider: providerWith(
          (messages, {systemPrompt, maxTokens}) async =>
              'Hello from local LLM!',
        ),
        toolRegistry: const ToolRegistry(),
        logger: logger,
      );

      final result = await orchestrator.runToCompletion(
        key: key,
        userMessage: 'Hi',
        toolExecutor: (pending) async => pending,
      );

      expect(result, isA<CompletedState>());
      final completed = result as CompletedState;
      expect(completed.threadKey, equals(key));
    });

    test('tool call → yield → resume → CompletedState', () async {
      var callCount = 0;

      orchestrator = RunOrchestrator(
        llmProvider: providerWith(
          (messages, {systemPrompt, maxTokens}) async {
            callCount++;
            if (callCount == 1) {
              return '''
```tool_call
{"name": "get_weather", "arguments": {"city": "NYC"}}
```'''
                  .trim();
            }
            return 'The weather in NYC is 72°F and sunny.';
          },
        ),
        toolRegistry: const ToolRegistry().register(
          ClientTool(
            definition: const Tool(
              name: 'get_weather',
              description: 'Gets weather for a city',
            ),
            executor: (_, __) async => '72°F, sunny',
          ),
        ),
        logger: logger,
      );

      final states = <RunState>[];
      orchestrator.stateChanges.listen(states.add);

      final result = await orchestrator.runToCompletion(
        key: key,
        userMessage: 'What is the weather in NYC?',
        toolExecutor: (pending) async {
          return pending
              .map(
                (tc) => tc.copyWith(
                  status: ToolCallStatus.completed,
                  result: '72°F, sunny',
                ),
              )
              .toList();
        },
      );

      expect(result, isA<CompletedState>());
      expect(callCount, 2);
      expect(states.whereType<ToolYieldingState>(), hasLength(1));
    });

    test('LLM error → FailedState', () async {
      orchestrator = RunOrchestrator(
        llmProvider: providerWith(
          (messages, {systemPrompt, maxTokens}) async =>
              throw Exception('Model unavailable'),
        ),
        toolRegistry: const ToolRegistry(),
        logger: logger,
      );

      final result = await orchestrator.runToCompletion(
        key: key,
        userMessage: 'Hi',
        toolExecutor: (pending) async => pending,
      );

      expect(result, isA<FailedState>());
      final failed = result as FailedState;
      expect(failed.error, contains('Model unavailable'));
    });

    test('tool results passed back to LLM in conversation', () async {
      var callCount = 0;
      List<({String role, String content})>? resumeMessages;

      orchestrator = RunOrchestrator(
        llmProvider: providerWith(
          (messages, {systemPrompt, maxTokens}) async {
            callCount++;
            if (callCount == 1) {
              return '''
```tool_call
{"name": "lookup", "arguments": {"id": "42"}}
```'''
                  .trim();
            }
            resumeMessages = messages;
            return 'Found item 42.';
          },
        ),
        toolRegistry: const ToolRegistry().register(
          ClientTool(
            definition: const Tool(
              name: 'lookup',
              description: 'Looks up an item',
            ),
            executor: (_, __) async => 'Item 42: Widget',
          ),
        ),
        logger: logger,
      );

      final result = await orchestrator.runToCompletion(
        key: key,
        userMessage: 'Find item 42',
        toolExecutor: (pending) async {
          return pending
              .map(
                (tc) => tc.copyWith(
                  status: ToolCallStatus.completed,
                  result: 'Item 42: Widget',
                ),
              )
              .toList();
        },
      );

      expect(result, isA<CompletedState>());
      expect(resumeMessages, isNotNull);

      final toolResultMsg = resumeMessages!.firstWhere(
        (m) => m.content.contains('Tool result'),
      );
      expect(toolResultMsg.content, contains('Item 42: Widget'));
    });

    test('system prompt includes tool definitions', () async {
      String? capturedSystemPrompt;

      orchestrator = RunOrchestrator(
        llmProvider: ChatFnLlmProvider(
          chatFn: (messages, {systemPrompt, maxTokens}) async {
            capturedSystemPrompt = systemPrompt;
            return 'Done.';
          },
          systemPrompt: 'You are a helpful assistant.',
        ),
        toolRegistry: const ToolRegistry().register(
          ClientTool(
            definition: const Tool(
              name: 'search',
              description: 'Searches the web',
            ),
            executor: (_, __) async => 'results',
          ),
        ),
        logger: logger,
      );

      await orchestrator.runToCompletion(
        key: key,
        userMessage: 'Search for something',
        toolExecutor: (pending) async => pending,
      );

      expect(capturedSystemPrompt, isNotNull);
      expect(
        capturedSystemPrompt,
        startsWith('You are a helpful assistant.'),
      );
      expect(capturedSystemPrompt, contains('### search'));
      expect(capturedSystemPrompt, contains('```tool_call'));
    });
  });
}
