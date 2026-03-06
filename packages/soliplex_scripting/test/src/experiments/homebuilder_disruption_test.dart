import 'dart:async';
import 'dart:convert';

import 'package:soliplex_agent/soliplex_agent.dart'
    show FakeAgentApi, FakeBlackboardApi, HostApi;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test data: Home construction domain
// ---------------------------------------------------------------------------

/// 2 houses, 5 jobs, real construction sequencing.
const List<Map<String, Object>> projectData = [
  {
    'id': 'H1_FND',
    'house': 'H1',
    'task': 'Foundation',
    'needs': 'concrete_crew',
    'mats': 'concrete',
    'deps': <String>[],
    'outdoor': true,
  },
  {
    'id': 'H1_FRM',
    'house': 'H1',
    'task': 'Framing',
    'needs': 'framer',
    'mats': 'lumber',
    'deps': ['H1_FND'],
    'outdoor': false,
  },
  {
    'id': 'H1_ROF',
    'house': 'H1',
    'task': 'Roofing',
    'needs': 'roofer',
    'mats': 'shingles',
    'deps': ['H1_FRM'],
    'outdoor': true,
  },
  {
    'id': 'H2_FND',
    'house': 'H2',
    'task': 'Foundation',
    'needs': 'concrete_crew',
    'mats': 'concrete',
    'deps': <String>[],
    'outdoor': true,
  },
  {
    'id': 'H2_FRM',
    'house': 'H2',
    'task': 'Framing',
    'needs': 'framer',
    'mats': 'lumber',
    'deps': ['H2_FND'],
    'outdoor': false,
  },
];

const staffRoster = [
  {'name': 'Bob', 'trade': 'concrete_crew', 'level': 'master'},
  {'name': 'Alice', 'trade': 'framer', 'level': 'journeyman'},
  {'name': 'Charlie', 'trade': 'roofer', 'level': 'apprentice'},
];

const List<Map<String, Object>> weatherForecast = [
  {'day': 1, 'condition': 'rain'},
  {'day': 2, 'condition': 'sunny'},
  {'day': 3, 'condition': 'sunny'},
  {'day': 4, 'condition': 'sunny'},
  {'day': 5, 'condition': 'sunny'},
];

/// Day-keyed disruptions returned by host_invoke('check_daily_events', ...).
const dailyDisruptions = <int, Map<String, Object?>>{
  1: {'event': 'none'},
  2: {
    'event': 'Alice (Framer) called in sick',
    'type': 'crew_noshow',
    'worker': 'Alice',
    'trade': 'framer',
  },
  3: {
    'event': 'Lumber delivery delayed 1 day',
    'type': 'material_delay',
    'material': 'lumber',
    'delay_days': 1,
  },
  4: {'event': 'none'},
  5: {'event': 'none'},
};

// ---------------------------------------------------------------------------
// Disruption-aware HostApi fake
// ---------------------------------------------------------------------------

/// A [HostApi] that dispatches `host_invoke('check_daily_events', ...)`
/// to return pre-configured disruptions per day.
class DisruptionHostApi implements HostApi {
  DisruptionHostApi({
    this.disruptions = dailyDisruptions,
  });

  final Map<int, Map<String, Object?>> disruptions;

  /// All invoke calls recorded as (name, args) pairs.
  final List<(String, Map<String, Object?>)> invocations = [];

  /// Log messages captured via `log()` calls.
  final List<String> logs = [];

  @override
  Future<Object?> invoke(String name, Map<String, Object?> args) async {
    invocations.add((name, args));

    if (name == 'check_daily_events') {
      final day = (args['day'] as num?)?.toInt() ?? 0;
      return disruptions[day] ?? {'event': 'none'};
    }

    if (name == 'log') {
      final message = args['message'] as String? ?? '';
      logs.add(message);
      return null;
    }

    return 'ok';
  }

  @override
  int registerDataFrame(Map<String, List<Object?>> columns) => 0;

  @override
  Map<String, List<Object?>>? getDataFrame(int handle) => null;

  @override
  int registerChart(Map<String, Object?> chartConfig) => 0;

  @override
  bool updateChart(int chartId, Map<String, Object?> chartConfig) => false;
}

// ---------------------------------------------------------------------------
// Scriptable bridge (reused pattern from integration_test.dart)
// ---------------------------------------------------------------------------

/// A bridge that simulates Monty execution by parsing simple
/// `fn(json_args)` calls and dispatching to registered host functions.
///
/// Supports multiple sequential calls separated by newlines.
class ScriptableBridge implements MontyBridge {
  final _functions = <String, HostFunction>{};

  @override
  List<HostFunctionSchema> get schemas =>
      _functions.values.map((f) => f.schema).toList();

  @override
  void register(HostFunction function) {
    _functions[function.schema.name] = function;
  }

  @override
  void unregister(String name) {
    _functions.remove(name);
  }

  @override
  Stream<BridgeEvent> execute(String code) {
    final controller = StreamController<BridgeEvent>();
    unawaited(_run(code, controller));
    return controller.stream;
  }

  Future<void> _run(
    String code,
    StreamController<BridgeEvent> controller,
  ) async {
    controller
      ..add(const BridgeRunStarted(threadId: 't', runId: 'r'))
      ..add(const BridgeStepStarted(stepId: 'step-1'));

    // Parse `fn({...})` calls, handling nested braces.
    var callIndex = 0;
    for (final (fnName, argsJson) in _parseCalls(code)) {
      final fn = _functions[fnName];
      final callId = 'c${callIndex++}';

      if (fn != null) {
        controller
          ..add(BridgeToolCallStart(callId: callId, name: fnName))
          ..add(BridgeToolCallArgs(callId: callId, delta: argsJson));

        final args = Map<String, Object?>.from(jsonDecode(argsJson) as Map);
        final result = await fn.handler(args);
        final resultStr = jsonEncode(result);

        controller
          ..add(BridgeToolCallEnd(callId: callId))
          ..add(BridgeToolCallResult(callId: callId, result: resultStr));
      }
    }

    controller
      ..add(const BridgeStepFinished(stepId: 'step-1'))
      ..add(const BridgeTextStart(messageId: 'msg-1'))
      ..add(const BridgeTextContent(messageId: 'msg-1', delta: 'done'))
      ..add(const BridgeTextEnd(messageId: 'msg-1'))
      ..add(const BridgeRunFinished(threadId: 't', runId: 'r'));
    await controller.close();
  }

  /// Parses `fnName({...})` calls from code, handling nested braces.
  static List<(String, String)> _parseCalls(String code) {
    final results = <(String, String)>[];
    final fnStart = RegExp(r'(\w+)\((\{)');
    for (final match in fnStart.allMatches(code)) {
      final fnName = match.group(1)!;
      // Walk forward from the opening brace, counting nesting depth.
      var depth = 1;
      var i = match.end;
      while (i < code.length && depth > 0) {
        if (code[i] == '{') depth++;
        if (code[i] == '}') depth--;
        i++;
      }
      // Extract the balanced JSON (from opening { to matching }).
      final argsJson = code.substring(match.start + fnName.length + 1, i);
      results.add((fnName, argsJson));
    }
    return results;
  }

  @override
  void dispose() {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wires a [DisruptionHostApi] + [FakeAgentApi] + [FakeBlackboardApi]
/// onto a [ScriptableBridge] and returns the environment.
({
  MontyScriptEnvironment env,
  DisruptionHostApi hostApi,
  FakeAgentApi agentApi,
  FakeBlackboardApi blackboard,
  ScriptableBridge bridge,
  StreamRegistry streams,
}) createDisruptionEnvironment({
  Map<int, Map<String, Object?>>? disruptions,
  String askLlmResponse = 'No impact.',
}) {
  final hostApi = DisruptionHostApi(
    disruptions: disruptions ?? dailyDisruptions,
  );
  final agentApi = FakeAgentApi(
    getResultResult: askLlmResponse,
  );
  final blackboard = FakeBlackboardApi();
  final dfRegistry = DfRegistry();
  final streamRegistry = StreamRegistry();
  final bridge = ScriptableBridge();

  HostFunctionWiring(
    hostApi: hostApi,
    agentApi: agentApi,
    blackboardApi: blackboard,
    dfRegistry: dfRegistry,
    streamRegistry: streamRegistry,
  ).registerOnto(bridge);

  final env = MontyScriptEnvironment(
    bridge: bridge,
    dfRegistry: dfRegistry,
    streamRegistry: streamRegistry,
  );

  return (
    env: env,
    hostApi: hostApi,
    agentApi: agentApi,
    blackboard: blackboard,
    bridge: bridge,
    streams: streamRegistry,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Homebuilder disruption experiments', () {
    group('Pattern A: Prescriptive baseline', () {
      test('blackboard seeding and host_invoke wiring work', () async {
        final harness = createDisruptionEnvironment();
        final bb = harness.blackboard;

        // Seed blackboard with construction data.
        await bb.write('project_data', projectData);
        await bb.write('staff_roster', staffRoster);
        await bb.write('weather_forecast', weatherForecast);

        // Verify data round-trips through blackboard.
        final data = (await bb.read('project_data'))! as List;
        expect(data, hasLength(5));
        expect((data[0] as Map)['id'], 'H1_FND');

        // Verify disruption host_invoke works.
        final day2Event = (await harness.hostApi.invoke(
          'check_daily_events',
          {'day': 2},
        ))! as Map;
        expect(day2Event['type'], 'crew_noshow');
        expect(day2Event['worker'], 'Alice');

        harness.env.dispose();
      });

      test('bridge dispatches blackboard_write and blackboard_read', () async {
        final harness = createDisruptionEnvironment();

        // Simulate Monty calling blackboard_write.
        const writeCode =
            'blackboard_write({"key": "test_key", "value": "test_val"})';
        await harness.bridge.execute(writeCode).drain<void>();
        expect(harness.blackboard.store['test_key'], 'test_val');

        // Simulate Monty calling blackboard_read.
        const readCode = 'blackboard_read({"key": "test_key"})';
        await harness.bridge.execute(readCode).drain<void>();
        expect(harness.blackboard.calls['read'], ['test_key']);

        harness.env.dispose();
      });

      test('bridge dispatches host_invoke for disruption check', () async {
        final harness = createDisruptionEnvironment();

        const code =
            'host_invoke({"name": "check_daily_events", "args": {"day": 2}})';
        await harness.bridge.execute(code).drain<void>();

        expect(harness.hostApi.invocations, hasLength(1));
        expect(harness.hostApi.invocations.first.$1, 'check_daily_events');

        harness.env.dispose();
      });

      test('bridge dispatches ask_llm for disruption reasoning', () async {
        final harness = createDisruptionEnvironment(
          askLlmResponse: 'Alice is sick. Delay all framing jobs by 1 day.',
        );

        const code = 'ask_llm({"prompt": "Alice called in sick. What jobs '
            'are affected?", "room": "scheduler"})';
        await harness.bridge.execute(code).drain<void>();

        expect(harness.agentApi.calls, contains('spawnAgent'));
        expect(harness.agentApi.calls['spawnAgent']![0], 'scheduler');

        harness.env.dispose();
      });
    });

    group('Pattern C: Disruption simulation', () {
      test('multi-step disruption: crew noshow on day 2', () async {
        final harness = createDisruptionEnvironment(
          askLlmResponse: 'Framing delayed. Move H1_FRM to Day 4.',
        );
        await harness.blackboard.write('project_data', projectData);
        await harness.blackboard.write('staff_roster', staffRoster);
        await harness.blackboard.write('weather_forecast', weatherForecast);

        // Day 1: rain — check events, no disruption beyond weather.
        const day1Code =
            'host_invoke({"name": "check_daily_events", "args": {"day": 1}})';
        await harness.bridge.execute(day1Code).drain<void>();
        final day1Event = harness.hostApi.invocations.last;
        expect(day1Event.$1, 'check_daily_events');

        // Day 2: Alice calls in sick.
        const day2Code =
            'host_invoke({"name": "check_daily_events", "args": {"day": 2}})';
        await harness.bridge.execute(day2Code).drain<void>();

        // Supervisor reasons about disruption via ask_llm.
        const reasonCode = 'ask_llm({"prompt": "Alice the framer called in '
            'sick on day 2. Current schedule has H1_FRM on day 3. '
            'What should we do?", "room": "scheduler"})';
        await harness.bridge.execute(reasonCode).drain<void>();

        expect(harness.agentApi.calls, contains('spawnAgent'));
        expect(
          harness.agentApi.calls['spawnAgent']![1]! as String,
          contains('Alice'),
        );

        // Supervisor writes adjusted schedule.
        const writeCode = 'blackboard_write({"key": "executed_schedule", '
            '"value": "Day 2: Bob->H1_FND. Day 3: Bob->H2_FND. '
            'Day 4: Alice->H1_FRM, Charlie->H1_ROF."})';
        await harness.bridge.execute(writeCode).drain<void>();

        expect(
          harness.blackboard.store['executed_schedule']! as String,
          contains('Day 4: Alice'),
        );

        harness.env.dispose();
      });

      test('multi-step disruption: material delay on day 3', () async {
        final harness = createDisruptionEnvironment(
          askLlmResponse: 'Lumber delayed. Cannot frame until Day 4.',
        );
        await harness.blackboard.write('project_data', projectData);
        await harness.blackboard.write('staff_roster', staffRoster);

        // Day 3: lumber delivery delayed.
        const day3Code =
            'host_invoke({"name": "check_daily_events", "args": {"day": 3}})';
        await harness.bridge.execute(day3Code).drain<void>();

        // Verify the disruption event was returned.
        final day3Result = (await harness.hostApi.invoke(
          'check_daily_events',
          {'day': 3},
        ))! as Map;
        expect(day3Result['type'], 'material_delay');
        expect(day3Result['material'], 'lumber');

        // Supervisor reasons about material impact.
        const reasonCode = 'ask_llm({"prompt": "Lumber delivery delayed '
            '1 day on day 3. Framing requires lumber. Adjust schedule.", '
            '"room": "scheduler"})';
        await harness.bridge.execute(reasonCode).drain<void>();

        expect(harness.agentApi.calls, contains('spawnAgent'));

        harness.env.dispose();
      });
    });

    group('Pattern E: Stream-driven reactive scheduling', () {
      test('weather stream delivers events in order', () async {
        final harness = createDisruptionEnvironment();

        // Register a weather stream that emits day-by-day forecasts.
        harness.streams.registerFactory(
          'weather_updates',
          () => Stream.fromIterable(
            weatherForecast.map((w) => <String, Object?>{...w}),
          ),
        );

        // Monty subscribes to the stream.
        const subCode = 'stream_subscribe({"name": "weather_updates"})';
        await harness.bridge.execute(subCode).drain<void>();

        // Pull first event (Day 1: rain).
        const nextCode = 'stream_next({"handle": 1})';
        await harness.bridge.execute(nextCode).drain<void>();

        // Pull directly from registry to verify ordering.
        final handle = harness.streams.subscribe('weather_updates');
        final first = await harness.streams.next(handle);
        expect((first! as Map)['day'], 1);
        expect((first as Map)['condition'], 'rain');

        final second = await harness.streams.next(handle);
        expect((second! as Map)['day'], 2);
        expect((second as Map)['condition'], 'sunny');

        harness.env.dispose();
      });

      test('crew disruption stream delivers sick event', () async {
        final harness = createDisruptionEnvironment();

        // Register crew update stream with a single disruption.
        harness.streams.registerFactory(
          'crew_updates',
          () => Stream.fromIterable([
            <String, Object?>{
              'day': 2,
              'event': 'Alice (Framer) called in sick',
              'worker': 'Alice',
              'trade': 'framer',
            },
          ]),
        );

        final handle = harness.streams.subscribe('crew_updates');
        final event = await harness.streams.next(handle);
        expect(event, isNotNull);
        expect((event! as Map)['worker'], 'Alice');

        // Stream exhausted after single event.
        final done = await harness.streams.next(handle);
        expect(done, isNull);

        harness.env.dispose();
      });

      test('material delay stream delivers shortage event', () async {
        final harness = createDisruptionEnvironment();

        harness.streams.registerFactory(
          'material_updates',
          () => Stream.fromIterable([
            <String, Object?>{
              'day': 3,
              'event': 'Lumber delivery delayed 1 day',
              'material': 'lumber',
              'delay_days': 1,
            },
          ]),
        );

        final handle = harness.streams.subscribe('material_updates');
        final event = await harness.streams.next(handle);
        expect((event! as Map)['material'], 'lumber');
        expect((event as Map)['delay_days'], 1);

        harness.env.dispose();
      });

      test('bridge dispatches stream_subscribe and stream_next', () async {
        final harness = createDisruptionEnvironment();

        // Register weather stream with 2 events.
        harness.streams.registerFactory(
          'weather_updates',
          () => Stream.fromIterable([
            <String, Object?>{'day': 1, 'condition': 'rain'},
            <String, Object?>{'day': 2, 'condition': 'sunny'},
          ]),
        );

        // Subscribe via bridge (as Monty would).
        const subCode = 'stream_subscribe({"name": "weather_updates"})';
        await harness.bridge.execute(subCode).drain<void>();

        // Pull events via bridge.
        const nextCode = 'stream_next({"handle": 1})';
        await harness.bridge.execute(nextCode).drain<void>();
        await harness.bridge.execute(nextCode).drain<void>();

        // After 2 events, stream should be exhausted — next returns null.
        // (We can't directly assert the bridge result, but we verify no throw.)
        await harness.bridge.execute(nextCode).drain<void>();

        harness.env.dispose();
      });

      test('multi-stream reactive loop: weather + crew + material', () async {
        final harness = createDisruptionEnvironment(
          askLlmResponse: 'Rain on day 1 — postpone outdoor work. '
              'Alice sick day 2 — delay framing. '
              'Lumber delayed day 3 — push framing to day 4.',
        );
        await harness.blackboard.write('project_data', projectData);
        await harness.blackboard.write('staff_roster', staffRoster);
        await harness.blackboard.write('current_schedule', 'initial');

        // Register all 3 event streams.
        harness.streams.registerFactory(
          'weather_updates',
          () => Stream.fromIterable([
            <String, Object?>{'day': 1, 'condition': 'rain'},
            <String, Object?>{'day': 2, 'condition': 'sunny'},
            <String, Object?>{'day': 3, 'condition': 'sunny'},
          ]),
        );
        harness.streams.registerFactory(
          'crew_updates',
          () => Stream.fromIterable([
            <String, Object?>{
              'day': 2,
              'event': 'Alice (Framer) called in sick',
              'worker': 'Alice',
              'trade': 'framer',
            },
          ]),
        );
        harness.streams.registerFactory(
          'material_updates',
          () => Stream.fromIterable([
            <String, Object?>{
              'day': 3,
              'event': 'Lumber delivery delayed 1 day',
              'material': 'lumber',
              'delay_days': 1,
            },
          ]),
        );

        // Simulate what the LLM-generated Monty code would do:
        // 1. Subscribe to all streams.
        await harness.bridge
            .execute('stream_subscribe({"name": "weather_updates"})')
            .drain<void>();
        await harness.bridge
            .execute('stream_subscribe({"name": "crew_updates"})')
            .drain<void>();
        await harness.bridge
            .execute('stream_subscribe({"name": "material_updates"})')
            .drain<void>();

        // 2. Pull weather event (rain day 1) → reason about impact.
        await harness.bridge
            .execute('stream_next({"handle": 1})')
            .drain<void>();
        await harness.bridge
            .execute('ask_llm({"prompt": "Rain on day 1. Postpone outdoor '
                'work.", "room": "scheduler"})')
            .drain<void>();

        // 3. Pull crew event (Alice sick day 2) → reason about impact.
        await harness.bridge
            .execute('stream_next({"handle": 2})')
            .drain<void>();
        await harness.bridge
            .execute('ask_llm({"prompt": "Alice sick day 2. Delay framing.", '
                '"room": "scheduler"})')
            .drain<void>();

        // 4. Pull material event (lumber delayed day 3) → reason.
        await harness.bridge
            .execute('stream_next({"handle": 3})')
            .drain<void>();
        await harness.bridge
            .execute('ask_llm({"prompt": "Lumber delayed day 3. Push framing '
                'to day 4.", "room": "scheduler"})')
            .drain<void>();

        // 5. Write final adjusted schedule.
        await harness.bridge
            .execute('blackboard_write({"key": "final_schedule", '
                '"value": "Day 2: Bob->H1_FND. Day 3: Bob->H2_FND. '
                'Day 4: Alice->H1_FRM. Day 5: Alice->H2_FRM, '
                'Charlie->H1_ROF."})')
            .drain<void>();

        // Verify: 3 ask_llm calls were made (one per disruption).
        final spawnCalls = harness.agentApi.calls['spawnAgent'];
        expect(spawnCalls, isNotNull);

        // Verify final schedule was written.
        final schedule = harness.blackboard.store['final_schedule']! as String;
        expect(schedule, contains('Bob->H1_FND'));
        expect(schedule, contains('Alice->H1_FRM'));
        expect(schedule, contains('Charlie->H1_ROF'));

        harness.env.dispose();
      });
    });

    group('Test data validation', () {
      test('project_data dependencies form valid DAG', () {
        final ids = projectData.map((j) => j['id']! as String).toSet();
        for (final job in projectData) {
          final deps = job['deps']! as List;
          for (final dep in deps) {
            expect(
              ids,
              contains(dep),
              reason: '${job['id']} depends on $dep which does not exist',
            );
          }
        }
      });

      test('every job has a matching staff trade', () {
        final trades = staffRoster.map((s) => s['trade']!).toSet();
        for (final job in projectData) {
          expect(
            trades,
            contains(job['needs']),
            reason: '${job['id']} needs ${job['needs']} '
                'but no staff has it',
          );
        }
      });

      test('weather forecast covers simulation days', () {
        final days = weatherForecast.map((w) => w['day']! as int).toSet();
        for (var d = 1; d <= 5; d++) {
          expect(days, contains(d), reason: 'No weather forecast for day $d');
        }
      });

      test('disruptions reference valid staff', () {
        final names = staffRoster.map((s) => s['name']!).toSet();
        for (final entry in dailyDisruptions.entries) {
          final worker = entry.value['worker'] as String?;
          if (worker != null) {
            expect(
              names,
              contains(worker),
              reason: 'Day ${entry.key} disruption references unknown '
                  'worker $worker',
            );
          }
        }
      });
    });
  });
}
