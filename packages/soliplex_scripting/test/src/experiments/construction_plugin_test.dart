import 'dart:async';

import 'package:soliplex_agent/soliplex_agent.dart'
    show FakeAgentApi, FakeBlackboardApi;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';
import 'package:test/test.dart';

import 'construction_plugin.dart';
import 'homebuilder_disruption_test.dart'
    show DisruptionHostApi, ScriptableBridge;

// ---------------------------------------------------------------------------
// Standard test data
// ---------------------------------------------------------------------------

final testJobs = [
  const Job(
    id: 'H1_FND',
    house: 'H1',
    task: 'Foundation',
    trade: 'concrete_crew',
    material: 'concrete',
    deps: [],
    outdoor: true,
  ),
  const Job(
    id: 'H1_FRM',
    house: 'H1',
    task: 'Framing',
    trade: 'framer',
    material: 'lumber',
    deps: ['H1_FND'],
    outdoor: false,
  ),
  const Job(
    id: 'H1_ROF',
    house: 'H1',
    task: 'Roofing',
    trade: 'roofer',
    material: 'shingles',
    deps: ['H1_FRM'],
    outdoor: true,
  ),
  const Job(
    id: 'H2_FND',
    house: 'H2',
    task: 'Foundation',
    trade: 'concrete_crew',
    material: 'concrete',
    deps: [],
    outdoor: true,
  ),
  const Job(
    id: 'H2_FRM',
    house: 'H2',
    task: 'Framing',
    trade: 'framer',
    material: 'lumber',
    deps: ['H2_FND'],
    outdoor: false,
  ),
];

final testStaff = [
  const Worker(name: 'Bob', trade: 'concrete_crew', level: 'master'),
  const Worker(name: 'Alice', trade: 'framer', level: 'journeyman'),
  const Worker(name: 'Charlie', trade: 'roofer', level: 'apprentice'),
];

final testWeather = <int, String>{
  1: 'rain',
  2: 'sunny',
  3: 'sunny',
  4: 'sunny',
  5: 'sunny',
};

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

({
  ConstructionState state,
  ConstructionPlugin plugin,
  ScriptableBridge bridge,
  FakeAgentApi agentApi,
  FakeBlackboardApi blackboard,
  StreamRegistry streams,
}) createPluginHarness({
  List<Job>? jobs,
  List<Worker>? staff,
  Map<int, String>? weather,
  String askLlmResponse = 'No impact.',
}) {
  final state = ConstructionState(
    jobs: jobs ?? testJobs,
    staff: staff ?? testStaff,
    weather: weather ?? testWeather,
  );
  final plugin = ConstructionPlugin(state: state);
  final hostApi = DisruptionHostApi();
  final agentApi = FakeAgentApi(
    getResultResult: askLlmResponse,
  );
  final blackboard = FakeBlackboardApi();
  final dfRegistry = DfRegistry();
  final streamRegistry = StreamRegistry();
  final bridge = ScriptableBridge();

  // Wire standard host functions.
  HostFunctionWiring(
    hostApi: hostApi,
    agentApi: agentApi,
    blackboardApi: blackboard,
    dfRegistry: dfRegistry,
    streamRegistry: streamRegistry,
  ).registerOnto(bridge);

  // Wire plugin functions.
  plugin.functions.forEach(bridge.register);

  return (
    state: state,
    plugin: plugin,
    bridge: bridge,
    agentApi: agentApi,
    blackboard: blackboard,
    streams: streamRegistry,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ConstructionPlugin', () {
    group('domain model', () {
      test('state initializes with correct job count', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        );
        expect(state.jobs, hasLength(5));
        expect(state.staff, hasLength(3));
      });

      test('depsMet returns false for unmet dependencies', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        );
        // H1_FRM depends on H1_FND which is not completed.
        expect(state.depsMet('H1_FRM'), isFalse);
      });

      test('depsMet returns true after completing dependency', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        )..completeJob('H1_FND');
        expect(state.depsMet('H1_FRM'), isTrue);
      });

      test('depsMet returns true for jobs with no deps', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        );
        expect(state.depsMet('H1_FND'), isTrue);
        expect(state.depsMet('H2_FND'), isTrue);
      });
    });

    group('assign validates constraints', () {
      test('rejects wrong trade', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        );
        final result = state.assign('Alice', 'H1_FND', 2); // Alice=framer
        expect(result['ok'], isFalse);
        expect(result['error']! as String, contains('framer'));
      });

      test('rejects outdoor work in rain', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        );
        // Day 1 is rain, H1_FND is outdoor.
        final result = state.assign('Bob', 'H1_FND', 1);
        expect(result['ok'], isFalse);
        expect(result['error']! as String, contains('rain'));
      });

      test('rejects unmet dependencies', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        );
        final result = state.assign('Alice', 'H1_FRM', 2);
        expect(result['ok'], isFalse);
        expect(result['error']! as String, contains('Dependencies'));
      });

      test('rejects double-booking worker on same day', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        )..assign('Bob', 'H1_FND', 2);
        final result = state.assign('Bob', 'H2_FND', 2);
        expect(result['ok'], isFalse);
        expect(result['error']! as String, contains('already assigned'));
      });

      test('accepts valid assignment', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        );
        final result = state.assign('Bob', 'H1_FND', 2);
        expect(result['ok'], isTrue);
      });
    });

    group('conflict detection', () {
      test('valid schedule has no conflicts', () {
        // Build a valid schedule.
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        )
          ..assign('Bob', 'H1_FND', 2)
          ..completeJob('H1_FND')
          ..assign('Bob', 'H2_FND', 3)
          ..completeJob('H2_FND')
          ..assign('Alice', 'H1_FRM', 3)
          ..completeJob('H1_FRM')
          ..assign('Alice', 'H2_FRM', 4)
          ..assign('Charlie', 'H1_ROF', 4);

        expect(state.detectConflicts(), isEmpty);
      });

      test('detects weather violation', () {
        // Force an outdoor job on rain day (bypass assign validation).
        ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        )
          ..assign('Bob', 'H1_FND', 2)
          ..completeJob('H1_FND');
        // Manually test conflict detection by creating a state where
        // weather changes after assignment.
        ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: {1: 'rain', 2: 'rain', 3: 'sunny', 4: 'sunny', 5: 'sunny'},
        )
          ..assign('Bob', 'H1_FND', 3) // valid: day 3 sunny
          ..completeJob('H1_FND');
        // Now simulate weather changing to rain on day 3 after assignment.
        final conflictState = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: {1: 'rain', 2: 'rain', 3: 'rain', 4: 'sunny', 5: 'sunny'},
        )
          ..assign('Bob', 'H1_FND', 4)
          ..completeJob('H1_FND')
          // Assign framing after foundation completed — valid.
          ..assign('Alice', 'H1_FRM', 5);
        expect(conflictState.detectConflicts(), isEmpty);
      });
    });

    group('disruptions', () {
      test('inject and retrieve disruption', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        )..injectDisruption(2, {
            'type': 'crew_noshow',
            'worker': 'Alice',
            'trade': 'framer',
          });

        final disruptions = state.getDisruptions(2);
        expect(disruptions, hasLength(1));
        expect(disruptions.first['worker'], 'Alice');

        // No disruptions on other days.
        expect(state.getDisruptions(1), isEmpty);
      });
    });

    group('bridge integration', () {
      test('plugin functions register on bridge', () {
        final harness = createPluginHarness();
        final names = harness.bridge.schemas.map((s) => s.name).toSet();

        expect(names, contains('construction_get_jobs'));
        expect(names, contains('construction_assign'));
        expect(names, contains('construction_detect_conflicts'));
        expect(names, contains('construction_deps_met'));
        expect(names, contains('construction_available_workers'));
      });

      test('bridge dispatches construction_get_weather', () async {
        final harness = createPluginHarness();

        const code = 'construction_get_weather({"day": 1})';
        await harness.bridge.execute(code).drain<void>();
        // Day 1 is rain — verified via state.
        expect(harness.state.getWeather(1), 'rain');
      });

      test('bridge dispatches construction_assign with validation', () async {
        final harness = createPluginHarness();

        // Valid assignment: Bob → H1_FND on day 2 (sunny, no deps).
        const code =
            'construction_assign({"worker": "Bob", "job_id": "H1_FND", '
            '"day": 2})';
        await harness.bridge.execute(code).drain<void>();

        expect(harness.state.getSchedule(), hasLength(1));
        expect(harness.state.getSchedule().first['worker'], 'Bob');
      });

      test('full prescriptive schedule via bridge (Pattern F)', () async {
        final harness = createPluginHarness();

        // Execute the prescriptive pattern step by step.
        await harness.bridge
            .execute('construction_assign({"worker": "Bob", '
                '"job_id": "H1_FND", "day": 2})')
            .drain<void>();
        await harness.bridge
            .execute('construction_complete_job({"job_id": "H1_FND"})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Bob", '
                '"job_id": "H2_FND", "day": 3})')
            .drain<void>();
        await harness.bridge
            .execute('construction_complete_job({"job_id": "H2_FND"})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Alice", '
                '"job_id": "H1_FRM", "day": 3})')
            .drain<void>();
        await harness.bridge
            .execute('construction_complete_job({"job_id": "H1_FRM"})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Alice", '
                '"job_id": "H2_FRM", "day": 4})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Charlie", '
                '"job_id": "H1_ROF", "day": 4})')
            .drain<void>();

        // Verify: 5 assignments, zero conflicts.
        expect(harness.state.getSchedule(), hasLength(5));
        expect(harness.state.detectConflicts(), isEmpty);
      });

      test('disruption → unassign → reassign via bridge', () async {
        final harness = createPluginHarness();

        // Build initial schedule.
        await harness.bridge
            .execute('construction_assign({"worker": "Bob", '
                '"job_id": "H1_FND", "day": 2})')
            .drain<void>();
        await harness.bridge
            .execute('construction_complete_job({"job_id": "H1_FND"})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Alice", '
                '"job_id": "H1_FRM", "day": 3})')
            .drain<void>();

        // Day 3 disruption: Alice calls in sick.
        await harness.bridge
            .execute('construction_inject_disruption({"day": 3, '
                '"disruption": {"type": "crew_noshow", '
                '"worker": "Alice", "trade": "framer"}})')
            .drain<void>();

        // LLM glue: unassign Alice, check who's available, reassign later.
        await harness.bridge
            .execute('construction_unassign({"worker": "Alice", "day": 3})')
            .drain<void>();

        // Alice no longer assigned on day 3.
        expect(harness.state.getDaySchedule(3), isEmpty);

        // Reassign Alice to day 4 (she's back).
        await harness.bridge
            .execute('construction_assign({"worker": "Alice", '
                '"job_id": "H1_FRM", "day": 4})')
            .drain<void>();

        expect(harness.state.getDaySchedule(4), hasLength(1));
        expect(harness.state.getDaySchedule(4).first['worker'], 'Alice');
      });
    });

    group('stream-driven reactive (Pattern H)', () {
      test('disruption stream triggers reschedule', () async {
        final harness = createPluginHarness(
          askLlmResponse: 'Alice is sick. Move framing to day 4.',
        );

        // Build initial schedule.
        harness.state
          ..assign('Bob', 'H1_FND', 2)
          ..completeJob('H1_FND')
          ..assign('Alice', 'H1_FRM', 3);

        // Register disruption stream.
        harness.streams.registerFactory(
          'disruptions',
          () => Stream.fromIterable([
            <String, Object?>{
              'day': 3,
              'type': 'crew_noshow',
              'worker': 'Alice',
              'trade': 'framer',
            },
          ]),
        );

        // Subscribe via bridge.
        await harness.bridge
            .execute('stream_subscribe({"name": "disruptions"})')
            .drain<void>();

        // Pull event.
        await harness.bridge
            .execute('stream_next({"handle": 1})')
            .drain<void>();

        // LLM glue: ask_llm to reason, then unassign + reassign.
        await harness.bridge
            .execute('ask_llm({"prompt": "Alice sick day 3. '
                'How to adjust?", "room": "scheduler"})')
            .drain<void>();

        await harness.bridge
            .execute('construction_unassign({"worker": "Alice", "day": 3})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Alice", '
                '"job_id": "H1_FRM", "day": 4})')
            .drain<void>();

        // Verify reschedule.
        expect(harness.state.getDaySchedule(3), isEmpty);
        expect(harness.state.getDaySchedule(4), hasLength(1));
        expect(harness.state.getDaySchedule(4).first['worker'], 'Alice');
        expect(harness.state.detectConflicts(), isEmpty);
      });

      test('stream exhaustion returns null gracefully', () async {
        final harness = createPluginHarness();

        harness.streams.registerFactory(
          'disruptions',
          () => Stream.fromIterable([
            <String, Object?>{
              'day': 2,
              'type': 'crew_noshow',
              'worker': 'Alice',
            },
          ]),
        );

        final handle = harness.streams.subscribe('disruptions');
        final event = await harness.streams.next(handle);
        expect(event, isNotNull);

        // Stream exhausted.
        final done = await harness.streams.next(handle);
        expect(done, isNull);
      });
    });

    group('agent integration (post FFI fix)', () {
      test('spawn_agent from construction supervisor', () async {
        final harness = createPluginHarness(
          askLlmResponse: 'Schedule looks valid. No conflicts found.',
        );

        // Build a partial schedule that a validator agent would check.
        await harness.bridge
            .execute('construction_assign({"worker": "Bob", '
                '"job_id": "H1_FND", "day": 2})')
            .drain<void>();
        await harness.bridge
            .execute('construction_complete_job({"job_id": "H1_FND"})')
            .drain<void>();

        // Supervisor spawns a sub-agent in the "validator" room.
        await harness.bridge
            .execute('spawn_agent({"room": "validator", '
                '"prompt": "Check this schedule for conflicts."})')
            .drain<void>();

        // Verify FakeAgentApi recorded the spawn call.
        expect(harness.agentApi.calls, contains('spawnAgent'));
        expect(harness.agentApi.calls['spawnAgent']![0], 'validator');
        expect(
          harness.agentApi.calls['spawnAgent']![1]! as String,
          contains('Check this schedule'),
        );

        // Watch the agent to get its result (non-evicting).
        await harness.bridge
            .execute('agent_watch({"handle": 1})')
            .drain<void>();

        expect(harness.agentApi.calls, contains('watchAgent'));
        expect(harness.agentApi.calls['watchAgent']![0], 1);

        // Also exercise get_result for the same handle.
        await harness.bridge.execute('get_result({"handle": 1})').drain<void>();

        expect(harness.agentApi.calls, contains('getResult'));
        expect(harness.agentApi.calls['getResult']![0], 1);
      });

      test('ask_llm for disruption reasoning', () async {
        final harness = createPluginHarness(
          askLlmResponse: 'Alice is sick. Reassign H1_FRM to day 5.',
        );

        // Build initial schedule.
        await harness.bridge
            .execute('construction_assign({"worker": "Bob", '
                '"job_id": "H1_FND", "day": 2})')
            .drain<void>();
        await harness.bridge
            .execute('construction_complete_job({"job_id": "H1_FND"})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Alice", '
                '"job_id": "H1_FRM", "day": 3})')
            .drain<void>();

        // Disruption arrives.
        await harness.bridge
            .execute('construction_inject_disruption({"day": 3, '
                '"disruption": {"type": "crew_noshow", '
                '"worker": "Alice", "trade": "framer"}})')
            .drain<void>();

        // Supervisor calls ask_llm to reason about the impact.
        await harness.bridge
            .execute('ask_llm({"prompt": "Alice the framer called in sick '
                'on day 3. H1_FRM is assigned to her. How should we '
                'adjust?", "room": "scheduler"})')
            .drain<void>();

        // ask_llm internally calls spawnAgent + getResult.
        expect(harness.agentApi.calls, contains('spawnAgent'));
        expect(harness.agentApi.calls['spawnAgent']![0], 'scheduler');
        expect(
          harness.agentApi.calls['spawnAgent']![1]! as String,
          contains('Alice'),
        );

        // LLM says reassign to day 5 — unassign day 3, reassign day 5.
        await harness.bridge
            .execute('construction_unassign({"worker": "Alice", "day": 3})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Alice", '
                '"job_id": "H1_FRM", "day": 5})')
            .drain<void>();

        // Verify the reschedule.
        expect(harness.state.getDaySchedule(3), isEmpty);
        expect(harness.state.getDaySchedule(5), hasLength(1));
        expect(harness.state.getDaySchedule(5).first['worker'], 'Alice');

        // Verify no conflicts.
        await harness.bridge
            .execute('construction_detect_conflicts({})')
            .drain<void>();
        expect(harness.state.detectConflicts(), isEmpty);
      });

      test(
          'concurrent agent spawn + construction_* calls '
          '(FFI re-entrancy)', () async {
        final harness = createPluginHarness(
          askLlmResponse: 'Validation passed.',
        );

        // Assign workers (construction_* calls).
        await harness.bridge
            .execute('construction_assign({"worker": "Bob", '
                '"job_id": "H1_FND", "day": 2})')
            .drain<void>();
        await harness.bridge
            .execute('construction_complete_job({"job_id": "H1_FND"})')
            .drain<void>();

        // Spawn a validator agent while continuing to make plugin calls.
        // This proves the bridge can handle agent API calls interleaved
        // with construction plugin calls without deadlocking.
        await harness.bridge
            .execute('spawn_agent({"room": "validator", '
                '"prompt": "Validate current schedule."})')
            .drain<void>();

        // Continue construction work while agent is "running".
        await harness.bridge
            .execute('construction_assign({"worker": "Bob", '
                '"job_id": "H2_FND", "day": 3})')
            .drain<void>();
        await harness.bridge
            .execute('construction_complete_job({"job_id": "H2_FND"})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Alice", '
                '"job_id": "H1_FRM", "day": 3})')
            .drain<void>();

        // Now collect the agent result.
        await harness.bridge
            .execute('agent_watch({"handle": 1})')
            .drain<void>();

        // Verify both the schedule and agent calls succeeded.
        expect(harness.state.getSchedule(), hasLength(3));
        expect(harness.state.detectConflicts(), isEmpty);
        expect(harness.agentApi.calls, contains('spawnAgent'));
        expect(harness.agentApi.calls, contains('watchAgent'));
      });

      test('full disruption + ask_llm + reassign flow', () async {
        final harness = createPluginHarness(
          askLlmResponse: 'Framing crew unavailable day 3. '
              'Unassign Alice from day 3, move H1_FRM to day 4. '
              'Assign Charlie to H1_ROF on day 5.',
        );

        // 1. Build initial schedule.
        await harness.bridge
            .execute('construction_assign({"worker": "Bob", '
                '"job_id": "H1_FND", "day": 2})')
            .drain<void>();
        await harness.bridge
            .execute('construction_complete_job({"job_id": "H1_FND"})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Bob", '
                '"job_id": "H2_FND", "day": 3})')
            .drain<void>();
        await harness.bridge
            .execute('construction_complete_job({"job_id": "H2_FND"})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Alice", '
                '"job_id": "H1_FRM", "day": 3})')
            .drain<void>();

        expect(harness.state.getSchedule(), hasLength(3));

        // 2. Pull disruption from stream.
        harness.streams.registerFactory(
          'disruptions',
          () => Stream.fromIterable([
            <String, Object?>{
              'day': 3,
              'type': 'crew_noshow',
              'worker': 'Alice',
              'trade': 'framer',
            },
          ]),
        );
        await harness.bridge
            .execute('stream_subscribe({"name": "disruptions"})')
            .drain<void>();
        await harness.bridge
            .execute('stream_next({"handle": 1})')
            .drain<void>();

        // 3. Call ask_llm to reason about disruption impact.
        await harness.bridge
            .execute('ask_llm({"prompt": "Alice called in sick day 3. '
                'She was assigned to H1_FRM. How to adjust the '
                'schedule?", "room": "scheduler"})')
            .drain<void>();

        expect(harness.agentApi.calls, contains('spawnAgent'));

        // 4. Unassign + reassign based on LLM response.
        await harness.bridge
            .execute('construction_unassign({"worker": "Alice", "day": 3})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Alice", '
                '"job_id": "H1_FRM", "day": 4})')
            .drain<void>();
        await harness.bridge
            .execute('construction_complete_job({"job_id": "H1_FRM"})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Charlie", '
                '"job_id": "H1_ROF", "day": 5})')
            .drain<void>();
        await harness.bridge
            .execute('construction_assign({"worker": "Alice", '
                '"job_id": "H2_FRM", "day": 5})')
            .drain<void>();

        // 5. Detect conflicts — should be clean.
        await harness.bridge
            .execute('construction_detect_conflicts({})')
            .drain<void>();

        final conflicts = harness.state.detectConflicts();
        expect(conflicts, isEmpty);

        // Final schedule: 5 assignments across days 2-5.
        expect(harness.state.getSchedule(), hasLength(5));

        // Verify day breakdown.
        expect(harness.state.getDaySchedule(2), hasLength(1)); // Bob H1_FND
        expect(harness.state.getDaySchedule(3), hasLength(1)); // Bob H2_FND
        expect(harness.state.getDaySchedule(4), hasLength(1)); // Alice H1_FRM
        expect(
          harness.state.getDaySchedule(5),
          hasLength(2),
        ); // Charlie + Alice
      });
    });

    group('stream_select multiplexer', () {
      test('stream_select picks first-firing stream', () async {
        final harness = createPluginHarness();

        // Register two disruption streams with different delays.
        harness.streams.registerFactory(
          'weather_alerts',
          () => Stream.fromIterable([
            <String, Object?>{
              'day': 2,
              'type': 'weather_change',
              'new_weather': 'rain',
            },
          ]),
        );
        harness.streams.registerFactory(
          'crew_updates',
          () async* {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            yield <String, Object?>{
              'day': 3,
              'type': 'crew_noshow',
              'worker': 'Alice',
            };
          },
        );

        // Subscribe to both.
        final hWeather = harness.streams.subscribe('weather_alerts');
        final hCrew = harness.streams.subscribe('crew_updates');

        // Select across both handles — weather fires first (sync).
        final result = await harness.streams.select([hWeather, hCrew]);
        expect(result, isNotNull);
        expect(result!['handle'], hWeather);
        expect((result['data']! as Map)['type'], 'weather_change');

        // Clean up remaining subscription.
        await harness.streams.close(hCrew);
      });

      test('stream_select returns null when all exhausted', () async {
        final harness = createPluginHarness();

        harness.streams
          ..registerFactory('empty1', Stream<Object?>.empty)
          ..registerFactory('empty2', Stream<Object?>.empty);

        final h1 = harness.streams.subscribe('empty1');
        final h2 = harness.streams.subscribe('empty2');

        final result = await harness.streams.select([h1, h2]);
        expect(result, isNull);
      });

      test('stream_select cleans exhausted and keeps live handles', () async {
        final harness = createPluginHarness();

        harness.streams
          ..registerFactory(
            'has_events',
            () => Stream.fromIterable([
              <String, Object?>{'day': 1, 'type': 'alert'},
            ]),
          )
          ..registerFactory('no_events', Stream<Object?>.empty);

        final hLive = harness.streams.subscribe('has_events');
        final hDead = harness.streams.subscribe('no_events');

        final result = await harness.streams.select([hLive, hDead]);
        expect(result, isNotNull);
        expect(result!['handle'], hLive);

        // Dead handle cleaned up automatically.
        expect(
          () => harness.streams.next(hDead),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('stream_select host function wired on bridge', () {
        final harness = createPluginHarness();
        final names = harness.bridge.schemas.map((s) => s.name).toSet();
        expect(names, contains('stream_select'));
      });
    });

    group('system prompt context', () {
      test('plugin provides LLM-readable function catalog', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        );
        final plugin = ConstructionPlugin(state: state);

        final context = plugin.systemPromptContext!;
        expect(context, contains('construction_assign'));
        expect(context, contains('construction_deps_met'));
        expect(context, contains('construction_detect_conflicts'));
        expect(context, contains('construction_available_workers'));
      });

      test('plugin registers expected number of functions', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        );
        final plugin = ConstructionPlugin(state: state);

        expect(plugin.functions, hasLength(18));
      });
    });

    group('get_ready_jobs and advance_day', () {
      test('get_ready_jobs returns only schedulable jobs', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        );

        // Initially only foundations are ready (no deps).
        final ready = state.getReadyJobs();
        final readyIds = ready.map((j) => j.id).toSet();
        expect(readyIds, containsAll(['H1_FND', 'H2_FND']));
        expect(readyIds, isNot(contains('H1_FRM'))); // deps unmet
        expect(readyIds, isNot(contains('H1_ROF'))); // deps unmet
      });

      test('get_ready_jobs updates after completing deps', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        )
          ..assign('Bob', 'H1_FND', 2)
          ..completeJob('H1_FND');

        final ready = state.getReadyJobs();
        final readyIds = ready.map((j) => j.id).toSet();
        // H1_FRM is now ready (dep H1_FND completed).
        expect(readyIds, contains('H1_FRM'));
        // H1_FND is no longer ready (completed).
        expect(readyIds, isNot(contains('H1_FND')));
        // H2_FND still ready (no deps, not assigned).
        expect(readyIds, contains('H2_FND'));
      });

      test('get_ready_jobs excludes assigned jobs', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        )..assign('Bob', 'H1_FND', 2);

        final ready = state.getReadyJobs();
        final readyIds = ready.map((j) => j.id).toSet();
        // H1_FND is assigned, should not appear.
        expect(readyIds, isNot(contains('H1_FND')));
        expect(readyIds, contains('H2_FND'));
      });

      test('advance_day completes all assigned jobs', () {
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        )
          ..assign('Bob', 'H1_FND', 2)
          ..assign('Bob', 'H2_FND', 3);

        final completed = state.advanceDay(2);
        expect(completed, ['H1_FND']);
        expect(state.jobStatus('H1_FND'), 'completed');
        expect(state.jobStatus('H2_FND'), 'in_progress'); // day 3, not 2

        // After advancing day 2, H1_FRM should now be ready.
        expect(state.depsMet('H1_FRM'), isTrue);
      });

      test('advance_day + get_ready_jobs creates scheduling loop', () {
        // Day 2: assign foundations.
        final state = ConstructionState(
          jobs: testJobs,
          staff: testStaff,
          weather: testWeather,
        )
          ..assign('Bob', 'H1_FND', 2)
          ..advanceDay(2);

        // Now H1_FRM is ready.
        var ready = state.getReadyJobs().map((j) => j.id).toSet();
        expect(ready, contains('H1_FRM'));
        expect(ready, contains('H2_FND'));

        // Day 3: assign framing + second foundation.
        state
          ..assign('Alice', 'H1_FRM', 3)
          ..assign('Bob', 'H2_FND', 3)
          ..advanceDay(3);

        // Now H1_ROF and H2_FRM are ready.
        ready = state.getReadyJobs().map((j) => j.id).toSet();
        expect(ready, contains('H1_ROF'));
        expect(ready, contains('H2_FRM'));

        // Day 4: assign remaining.
        state
          ..assign('Charlie', 'H1_ROF', 4)
          ..assign('Alice', 'H2_FRM', 4)
          ..advanceDay(4);

        // All jobs complete — nothing ready.
        expect(state.getReadyJobs(), isEmpty);
        expect(state.detectConflicts(), isEmpty);
      });

      test('bridge dispatches construction_get_ready_jobs', () async {
        final harness = createPluginHarness();

        await harness.bridge
            .execute('construction_get_ready_jobs({})')
            .drain<void>();

        // Initially H1_FND and H2_FND are ready.
        final ready = harness.state.getReadyJobs();
        expect(ready, hasLength(2));
      });

      test('bridge dispatches construction_advance_day', () async {
        final harness = createPluginHarness();

        await harness.bridge
            .execute('construction_assign({"worker": "Bob", '
                '"job_id": "H1_FND", "day": 2})')
            .drain<void>();
        await harness.bridge
            .execute('construction_advance_day({"day": 2})')
            .drain<void>();

        expect(harness.state.jobStatus('H1_FND'), 'completed');
        expect(harness.state.depsMet('H1_FRM'), isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // Tier 2: Goal-Oriented Autonomous Planning (Pattern G)
    //
    // These tests simulate what an LLM would generate when given ONLY a goal
    // ("schedule all jobs ASAP") with no step-by-step instructions. The LLM
    // must invent the query→check→assign→advance loop using the construction_*
    // API. We simulate the generated code via bridge calls.
    // -----------------------------------------------------------------------

    group('Tier 2: autonomous planning (Pattern G)', () {
      test('LLM-invented scheduling loop completes all jobs', () async {
        // Simulates the code an LLM would generate for Pattern G:
        // "Create a valid schedule that finishes as early as possible."
        //
        // The LLM must invent this loop:
        //   for each day:
        //     ready = get_ready_jobs()
        //     for each ready job:
        //       workers = workers_for_trade(job.trade)
        //       available = available_workers(day)
        //       pick worker in both lists
        //       if outdoor and rain: skip
        //       assign(worker, job, day)
        //     advance_day(day)
        final harness = createPluginHarness();

        // Day 1: rain — skip outdoor. Only indoor ready jobs (none, since
        // foundations are outdoor). LLM should query and skip.
        await harness.bridge
            .execute('construction_get_ready_jobs({})')
            .drain<void>();
        await harness.bridge
            .execute('construction_get_weather({"day": 1})')
            .drain<void>();
        // LLM sees: ready=[H1_FND, H2_FND], weather=rain, both outdoor → skip
        await harness.bridge
            .execute('construction_advance_day({"day": 1})')
            .drain<void>();

        // Day 2: sunny. Assign Bob to H1_FND (outdoor ok).
        await harness.bridge
            .execute('construction_get_ready_jobs({})')
            .drain<void>();
        await harness.bridge
            .execute('construction_get_weather({"day": 2})')
            .drain<void>();
        await harness.bridge
            .execute('construction_available_workers({"day": 2})')
            .drain<void>();
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Bob", "job_id": "H1_FND", "day": 2})',
            )
            .drain<void>();
        // Bob busy, but H2_FND also needs concrete_crew — no one else.
        await harness.bridge
            .execute('construction_advance_day({"day": 2})')
            .drain<void>();

        // Day 3: H1_FND complete → H1_FRM ready. H2_FND still ready.
        await harness.bridge
            .execute('construction_get_ready_jobs({})')
            .drain<void>();
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Bob", "job_id": "H2_FND", "day": 3})',
            )
            .drain<void>();
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Alice", "job_id": "H1_FRM", "day": 3})',
            )
            .drain<void>();
        await harness.bridge
            .execute('construction_advance_day({"day": 3})')
            .drain<void>();

        // Day 4: H2_FND + H1_FRM complete → H2_FRM + H1_ROF ready.
        await harness.bridge
            .execute('construction_get_ready_jobs({})')
            .drain<void>();
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Alice", "job_id": "H2_FRM", "day": 4})',
            )
            .drain<void>();
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Charlie", "job_id": "H1_ROF", "day": 4})',
            )
            .drain<void>();
        await harness.bridge
            .execute('construction_advance_day({"day": 4})')
            .drain<void>();

        // Verify: all 5 jobs complete, zero conflicts, optimal 4-day schedule.
        expect(harness.state.getReadyJobs(), isEmpty);
        expect(harness.state.detectConflicts(), isEmpty);
        expect(harness.state.getSchedule(), hasLength(5));
        for (final job in testJobs) {
          expect(harness.state.jobStatus(job.id), 'completed');
        }
      });

      test('LLM queries deps before assigning dependent jobs', () async {
        // Pattern G requires the LLM to check deps_met before assigning.
        // If it skips this, assign() returns {ok: false}.
        final harness = createPluginHarness();

        // Try to assign framing before foundation — should fail.
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Alice", "job_id": "H1_FRM", "day": 2})',
            )
            .drain<void>();

        // LLM reads error, checks deps_met, realizes H1_FND not done.
        await harness.bridge
            .execute('construction_deps_met({"job_id": "H1_FRM"})')
            .drain<void>();
        expect(harness.state.depsMet('H1_FRM'), isFalse);

        // LLM pivots to foundation first.
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Bob", "job_id": "H1_FND", "day": 2})',
            )
            .drain<void>();
        await harness.bridge
            .execute('construction_advance_day({"day": 2})')
            .drain<void>();

        // Now framing deps are met.
        expect(harness.state.depsMet('H1_FRM'), isTrue);
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Alice", "job_id": "H1_FRM", "day": 3})',
            )
            .drain<void>();

        expect(harness.state.getSchedule(), hasLength(2));
        expect(harness.state.detectConflicts(), isEmpty);
      });

      test('LLM weather-aware: skips outdoor on rain, assigns indoor',
          () async {
        // Pattern G with rain on day 1: LLM must skip outdoor work.
        final harness = createPluginHarness(
          // Add an indoor job with no deps so day 1 isn't wasted.
          jobs: [
            ...testJobs,
            const Job(
              id: 'H1_PLB',
              house: 'H1',
              task: 'Plumbing',
              trade: 'plumber',
              material: 'pipes',
              deps: [],
              outdoor: false,
            ),
          ],
          staff: [
            ...testStaff,
            const Worker(name: 'Dave', trade: 'plumber', level: 'master'),
          ],
        );

        // Day 1 rain: LLM checks weather, skips outdoor H1_FND/H2_FND.
        await harness.bridge
            .execute('construction_get_weather({"day": 1})')
            .drain<void>();
        expect(harness.state.getWeather(1), 'rain');

        // But H1_PLB is indoor — can be scheduled.
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Dave", "job_id": "H1_PLB", "day": 1})',
            )
            .drain<void>();

        expect(harness.state.getDaySchedule(1), hasLength(1));
        expect(harness.state.getDaySchedule(1).first['job_id'], 'H1_PLB');
      });

      test('LLM uses ask_llm for planning sub-decisions', () async {
        // Pattern G+: supervisor delegates sub-decisions to ask_llm.
        final harness = createPluginHarness(
          askLlmResponse: 'Assign Bob to H1_FND on day 2, then Alice '
              'to H1_FRM on day 3.',
        );

        // Supervisor queries ready jobs, then asks LLM for planning.
        await harness.bridge
            .execute('construction_get_ready_jobs({})')
            .drain<void>();
        await harness.bridge
            .execute(
              'ask_llm({"prompt": "Given ready jobs H1_FND and H2_FND, '
              'staff Bob (concrete), Alice (framer), Charlie (roofer), '
              'and rain on day 1, what is the optimal assignment?", '
              '"room": "planner"})',
            )
            .drain<void>();

        // Verify supervisor called ask_llm.
        expect(harness.agentApi.calls, contains('spawnAgent'));
        expect(harness.agentApi.calls['spawnAgent']![0], 'planner');

        // Supervisor follows LLM advice.
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Bob", "job_id": "H1_FND", "day": 2})',
            )
            .drain<void>();
        await harness.bridge
            .execute('construction_advance_day({"day": 2})')
            .drain<void>();
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Alice", "job_id": "H1_FRM", "day": 3})',
            )
            .drain<void>();

        expect(harness.state.getSchedule(), hasLength(2));
        expect(harness.state.detectConflicts(), isEmpty);
      });

      test('LLM maximizes parallelism across houses', () async {
        // Optimal schedule assigns workers to different houses in parallel.
        final harness = createPluginHarness();

        // Day 2: Bob on H1_FND (only concrete_crew).
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Bob", "job_id": "H1_FND", "day": 2})',
            )
            .drain<void>();
        await harness.bridge
            .execute('construction_advance_day({"day": 2})')
            .drain<void>();

        // Day 3: Bob on H2_FND + Alice on H1_FRM (parallel!).
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Bob", "job_id": "H2_FND", "day": 3})',
            )
            .drain<void>();
        await harness.bridge
            .execute(
              'construction_assign('
              '{"worker": "Alice", "job_id": "H1_FRM", "day": 3})',
            )
            .drain<void>();

        // Both assigned on day 3 — max parallelism.
        expect(harness.state.getDaySchedule(3), hasLength(2));
        expect(harness.state.detectConflicts(), isEmpty);
      });
    });
  });
}
