import 'dart:async';

import 'package:soliplex_agent/soliplex_agent.dart'
    show
        AgentApi,
        AgentFailure,
        AgentResult,
        AgentSuccess,
        AgentTimedOut,
        FailureReason,
        FakeAgentApi;
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('AgentPlugin', () {
    late FakeAgentApi agentApi;
    late AgentPlugin plugin;

    setUp(() {
      agentApi = FakeAgentApi(
        spawnResult: 10,
        getResultResult: 'agent output',
        waitAllResult: ['r1', 'r2'],
      );
      plugin = AgentPlugin(agentApi: agentApi);
    });

    test('namespace is agent', () {
      expect(plugin.namespace, 'agent');
    });

    test('provides 7 functions', () {
      expect(plugin.functions, hasLength(7));
      final names = plugin.functions.map((f) => f.schema.name).toSet();
      expect(
        names,
        containsAll([
          'agent_spawn',
          'agent_wait_all',
          'agent_get_result',
          'agent_watch',
          'agent_cancel',
          'agent_status',
          'agent_ask_llm',
        ]),
      );
    });

    test('registers onto bridge via PluginRegistry', () async {
      final bridge = RecordingBridge();
      final registry = PluginRegistry()..register(plugin);
      await registry.attachTo(bridge);

      final names = bridge.registered.map((f) => f.schema.name).toSet();
      expect(names, containsAll(['agent_spawn', 'agent_ask_llm']));
    });

    group('handler delegation', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        byName = {for (final f in plugin.functions) f.schema.name: f};
      });

      test('agent_spawn delegates to AgentApi.spawnAgent', () async {
        final result = await byName['agent_spawn']!.handler({
          'room': 'weather',
          'prompt': 'Is it raining?',
        });

        expect(result, 10);
        expect(agentApi.calls['spawnAgent']![0], 'weather');
        expect(agentApi.calls['spawnAgent']![1], 'Is it raining?');
      });

      test('agent_spawn passes thread_id when provided', () async {
        await byName['agent_spawn']!.handler({
          'room': 'weather',
          'prompt': 'Continue',
          'thread_id': 'tid-456',
        });

        expect(agentApi.calls['spawnAgent']![2], 'tid-456');
      });

      test('agent_wait_all delegates to AgentApi.waitAll', () async {
        final result = await byName['agent_wait_all']!.handler({
          'handles': <Object?>[1, 2],
        });

        expect(result, ['r1', 'r2']);
      });

      test('agent_get_result delegates to AgentApi.getResult', () async {
        final result = await byName['agent_get_result']!.handler({'handle': 5});

        expect(result, 'agent output');
      });

      test('agent_ask_llm spawns agent and gets result', () async {
        final result = await byName['agent_ask_llm']!.handler({
          'prompt': 'What is 2+2?',
          'room': 'math',
        });

        expect(result, isA<Map<String, Object?>>());
        final map = result! as Map<String, Object?>;
        expect(map['text'], 'agent output');
        expect(map['thread_id'], 'fake-thread-id');
      });

      test('agent_ask_llm uses "general" as default room', () async {
        await byName['agent_ask_llm']!.handler({
          'prompt': 'Hello',
          'room': 'general',
        });

        expect(agentApi.calls['spawnAgent']![0], 'general');
      });

      test('agent_ask_llm passes thread_id for continuity', () async {
        await byName['agent_ask_llm']!.handler({
          'prompt': 'Continue',
          'room': 'math',
          'thread_id': 'tid-123',
        });

        expect(agentApi.calls['spawnAgent']![2], 'tid-123');
      });

      test('agent_watch returns success dict', () async {
        agentApi.watchResult = const AgentSuccess(
          threadKey: (serverId: 's', roomId: 'r', threadId: 't'),
          output: 'done!',
          runId: 'run-1',
        );

        final result = await byName['agent_watch']!.handler({'handle': 10});

        final map = result! as Map<String, Object?>;
        expect(map['status'], 'success');
        expect(map['output'], 'done!');
      });

      test('agent_watch returns failed dict', () async {
        agentApi.watchResult = const AgentFailure(
          threadKey: (serverId: 's', roomId: 'r', threadId: 't'),
          reason: FailureReason.serverError,
          error: 'boom',
          partialOutput: 'partial',
        );

        final result = await byName['agent_watch']!.handler({'handle': 5});

        final map = result! as Map<String, Object?>;
        expect(map['status'], 'failed');
        expect(map['reason'], 'serverError');
        expect(map['error'], 'boom');
        expect(map['partial_output'], 'partial');
      });

      test('agent_watch returns timed_out dict', () async {
        agentApi.watchResult = const AgentTimedOut(
          threadKey: (serverId: 's', roomId: 'r', threadId: 't'),
          elapsed: Duration(seconds: 15),
        );

        final result = await byName['agent_watch']!.handler({'handle': 3});

        final map = result! as Map<String, Object?>;
        expect(map['status'], 'timed_out');
        expect(map['elapsed_seconds'], 15);
      });

      test('agent_cancel delegates to AgentApi.cancelAgent', () async {
        final result = await byName['agent_cancel']!.handler({'handle': 8});

        expect(result, isTrue);
      });

      test('agent_status delegates to AgentApi.agentStatus', () async {
        agentApi.statusResult = 'completed';

        final result = await byName['agent_status']!.handler({'handle': 3});

        expect(result, 'completed');
      });
    });

    group('schemas', () {
      late Map<String, HostFunction> byName;

      setUp(() {
        byName = {for (final f in plugin.functions) f.schema.name: f};
      });

      test('agent_spawn has room, prompt, thread_id', () {
        final schema = byName['agent_spawn']!.schema;
        expect(schema.params, hasLength(3));
        expect(schema.params[0].name, 'room');
        expect(schema.params[1].name, 'prompt');
        expect(schema.params[2].name, 'thread_id');
        expect(schema.params[2].isRequired, isFalse);
      });

      test('ask_llm has prompt, room, thread_id', () {
        final schema = byName['agent_ask_llm']!.schema;
        expect(schema.params, hasLength(3));
        expect(schema.params[0].name, 'prompt');
        expect(schema.params[1].name, 'room');
        expect(schema.params[1].defaultValue, 'general');
        expect(schema.params[2].name, 'thread_id');
      });

      test('agent_watch has handle and optional timeout', () {
        final schema = byName['agent_watch']!.schema;
        expect(schema.params, hasLength(2));
        expect(schema.params[0].name, 'handle');
        expect(schema.params[1].name, 'timeout_seconds');
        expect(schema.params[1].isRequired, isFalse);
      });

      test('agent_cancel has handle param', () {
        final schema = byName['agent_cancel']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'handle');
      });

      test('agent_status has handle param', () {
        final schema = byName['agent_status']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].name, 'handle');
      });

      test('agent_wait_all has list param', () {
        final schema = byName['agent_wait_all']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].type, HostParamType.list);
      });

      test('agent_get_result has integer param', () {
        final schema = byName['agent_get_result']!.schema;
        expect(schema.params, hasLength(1));
        expect(schema.params[0].type, HostParamType.integer);
      });
    });

    group('timeout', () {
      test('ask_llm times out with configured agentTimeout', () async {
        final slowApi = _NeverResolvingAgentApi();
        final p = AgentPlugin(
          agentApi: slowApi,
          agentTimeout: const Duration(milliseconds: 50),
        );
        final byName = {for (final f in p.functions) f.schema.name: f};

        await expectLater(
          byName['agent_ask_llm']!
              .handler({'prompt': 'slow', 'room': 'general'}),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('agent_get_result times out', () async {
        final slowApi = _NeverResolvingAgentApi();
        final p = AgentPlugin(
          agentApi: slowApi,
          agentTimeout: const Duration(milliseconds: 50),
        );
        final byName = {for (final f in p.functions) f.schema.name: f};

        await expectLater(
          byName['agent_get_result']!.handler({'handle': 1}),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('agent_wait_all times out', () async {
        final slowApi = _NeverResolvingAgentApi();
        final p = AgentPlugin(
          agentApi: slowApi,
          agentTimeout: const Duration(milliseconds: 50),
        );
        final byName = {for (final f in p.functions) f.schema.name: f};

        await expectLater(
          byName['agent_wait_all']!.handler({
            'handles': <Object?>[1, 2],
          }),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('agent_watch times out', () async {
        final slowApi = _NeverResolvingAgentApi();
        final p = AgentPlugin(
          agentApi: slowApi,
          agentTimeout: const Duration(milliseconds: 50),
        );
        final byName = {for (final f in p.functions) f.schema.name: f};

        await expectLater(
          byName['agent_watch']!.handler({'handle': 1}),
          throwsA(isA<TimeoutException>()),
        );
      });
    });
  });
}

class _NeverResolvingAgentApi implements AgentApi {
  @override
  Future<int> spawnAgent(
    String roomId,
    String prompt, {
    String? threadId,
    Duration? timeout,
  }) =>
      Completer<int>().future;

  @override
  String getThreadId(int handle) => 'never';

  @override
  Future<List<String>> waitAll(List<int> handles, {Duration? timeout}) =>
      Completer<List<String>>().future;

  @override
  Future<String> getResult(int handle, {Duration? timeout}) =>
      Completer<String>().future;

  @override
  Future<AgentResult> watchAgent(int handle, {Duration? timeout}) =>
      Completer<AgentResult>().future;

  @override
  Future<void> cancelAgent(int handle) => Completer<void>().future;

  @override
  String agentStatus(int handle) => 'running';
}
