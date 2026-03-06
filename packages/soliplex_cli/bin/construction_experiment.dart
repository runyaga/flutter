import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_monty_ffi/dart_monty_ffi.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_cli/src/client_factory.dart';
import 'package:soliplex_cli/src/result_printer.dart';
import 'package:soliplex_client/soliplex_client.dart' show DartHttpClient;
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';

// ---------------------------------------------------------------------------
// Test data (same as test suite)
// ---------------------------------------------------------------------------

final _jobs = [
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

final _staff = [
  const Worker(name: 'Bob', trade: 'concrete_crew', level: 'master'),
  const Worker(name: 'Alice', trade: 'framer', level: 'journeyman'),
  const Worker(name: 'Charlie', trade: 'roofer', level: 'journeyman'),
];

final _weather = <int, String>{
  1: 'rain',
  2: 'sunny',
  3: 'sunny',
  4: 'sunny',
  5: 'sunny',
};

// ---------------------------------------------------------------------------
// Room definitions
// ---------------------------------------------------------------------------

class _RoomRun {
  const _RoomRun(
    this.roomId,
    this.prompt,
    this.tier,
    this.modelSize, {
    this.needsStreams = false,
  });
  final String roomId;
  final String prompt;
  final String tier;
  final String modelSize;
  final bool needsStreams;
}

const _t1Prompt = 'Assign Bob to H1_FND on day 2, Alice to H1_FRM on day 3, '
    'then Charlie to H1_ROF on day 4. Advance day after each '
    'assignment. Verify no conflicts at the end.';

const _t2Prompt = 'Here are the project details:\n'
    '- 2 houses (H1, H2), 5 jobs total\n'
    '- Day 1 has rain, days 2-5 are sunny\n'
    '- 3 workers: Bob (concrete_crew), Alice (framer), '
    'Charlie (roofer)\n'
    '- Foundation must be done before framing, framing before '
    'roofing\n'
    '- Foundation is outdoor work, framing is indoor, roofing is '
    'outdoor\n\n'
    'Build an optimal schedule. All jobs must be completed. '
    'Minimize the number of days. Show the final schedule.';

const _t3Prompt =
    'A schedule has been built. You need to monitor for disruptions.\n'
    'Available streams: "crew_updates" and "weather_updates".\n\n'
    'Subscribe to both streams and react to whatever events come in.\n'
    'For crew no-shows: unassign the worker, find a replacement.\n'
    'For weather changes: if rain, move outdoor jobs.\n\n'
    'Keep going until all streams are exhausted.';

const _t4Prompt = 'Build a schedule for 2 houses (H1, H2) with 5 jobs and '
    '3 workers. Day 1 is rain, days 2-5 are sunny.\n\n'
    'Expect your assign() calls to fail sometimes. When they '
    'fail, read the error_code, diagnose what went wrong, fix '
    'it, and retry. Track all errors on the blackboard. Show '
    'the final schedule and error count.';

const _rooms = <_RoomRun>[
  _RoomRun('construction-prescriptive-20b', _t1Prompt, 'T1', '20B'),
  _RoomRun('construction-prescriptive-120b', _t1Prompt, 'T1', '120B'),
  _RoomRun('construction-scheduler-20b', _t2Prompt, 'T2', '20B'),
  _RoomRun('construction-scheduler-120b', _t2Prompt, 'T2', '120B'),
  _RoomRun(
    'construction-dispatcher-20b',
    _t3Prompt,
    'T3',
    '20B',
    needsStreams: true,
  ),
  _RoomRun(
    'construction-dispatcher-120b',
    _t3Prompt,
    'T3',
    '120B',
    needsStreams: true,
  ),
  _RoomRun('construction-recovery-20b', _t4Prompt, 'T4', '20B'),
  _RoomRun('construction-recovery-120b', _t4Prompt, 'T4', '120B'),
];

// ---------------------------------------------------------------------------
// Correctness validation
// ---------------------------------------------------------------------------

/// Structured verdict for a single room run.
class _Verdict {
  _Verdict(this.checks);

  final List<_Check> checks;

  bool get passed => checks.every((c) => c.passed);
  int get passCount => checks.where((c) => c.passed).length;
  int get totalCount => checks.length;

  String get summary => passed
      ? 'CORRECT ($passCount/$totalCount)'
      : 'INCORRECT ($passCount/$totalCount)';

  String get details =>
      checks.map((c) => '  ${c.passed ? "OK" : "FAIL"}: ${c.label}').join('\n');
}

class _Check {
  const _Check(this.label, {required this.passed});
  final String label;
  final bool passed;
}

bool _hasAssignment(ConstructionState s, String worker, String jobId, int day) {
  return s.getSchedule().any(
        (a) => a['worker'] == worker && a['job_id'] == jobId && a['day'] == day,
      );
}

int _maxDay(ConstructionState s) {
  var max = 0;
  for (final a in s.getSchedule()) {
    final day = a['day']! as int;
    if (day > max) max = day;
  }
  return max;
}

bool _hasOutdoorOnDay(ConstructionState s, int day) {
  final dayAssigns = s.getDaySchedule(day);
  for (final a in dayAssigns) {
    final job = s.findJob(a['job_id']! as String);
    if (job != null && job.outdoor) return true;
  }
  return false;
}

bool _workerOnDay(ConstructionState s, String worker, int day) {
  return s.getDaySchedule(day).any((a) => a['worker'] == worker);
}

_Verdict _validateT1(ConstructionState s) => _Verdict([
      _Check('3 assignments', passed: s.getSchedule().length == 3),
      _Check('0 conflicts', passed: s.detectConflicts().isEmpty),
      _Check(
        'Bob→H1_FND day 2',
        passed: _hasAssignment(s, 'Bob', 'H1_FND', 2),
      ),
      _Check(
        'Alice→H1_FRM day 3',
        passed: _hasAssignment(s, 'Alice', 'H1_FRM', 3),
      ),
      _Check(
        'Charlie→H1_ROF day 4',
        passed: _hasAssignment(s, 'Charlie', 'H1_ROF', 4),
      ),
      _Check(
        'all 3 jobs completed',
        passed: ['H1_FND', 'H1_FRM', 'H1_ROF']
            .every((id) => s.jobStatus(id) == 'completed'),
      ),
    ]);

_Verdict _validateT2(ConstructionState s) => _Verdict([
      _Check('5 assignments', passed: s.getSchedule().length == 5),
      _Check('0 conflicts', passed: s.detectConflicts().isEmpty),
      _Check(
        'all 5 jobs completed',
        passed: s.jobs.every((j) => s.jobStatus(j.id) == 'completed'),
      ),
      _Check('no outdoor work day 1', passed: !_hasOutdoorOnDay(s, 1)),
      _Check('optimal span ≤ 4 days', passed: _maxDay(s) <= 4),
    ]);

_Verdict _validateT3(ConstructionState s) => _Verdict([
      _Check('0 conflicts', passed: s.detectConflicts().isEmpty),
      _Check('Alice NOT on day 3', passed: !_workerOnDay(s, 'Alice', 3)),
      _Check('no outdoor work day 4', passed: !_hasOutdoorOnDay(s, 4)),
      _Check(
        'Bob→H1_FND day 2 preserved',
        passed: _hasAssignment(s, 'Bob', 'H1_FND', 2),
      ),
      _Check(
        'Bob→H2_FND day 3 preserved',
        passed: _hasAssignment(s, 'Bob', 'H2_FND', 3),
      ),
    ]);

_Verdict _validateT4(ConstructionState s) => _Verdict([
      _Check('5 assignments', passed: s.getSchedule().length == 5),
      _Check('0 conflicts', passed: s.detectConflicts().isEmpty),
      _Check(
        'all 5 jobs completed',
        passed: s.jobs.every((j) => s.jobStatus(j.id) == 'completed'),
      ),
      _Check('no outdoor work day 1', passed: !_hasOutdoorOnDay(s, 1)),
    ]);

_Verdict _validate(_RoomRun run, ConstructionState state) => switch (run.tier) {
      'T1' => _validateT1(state),
      'T2' => _validateT2(state),
      'T3' => _validateT3(state),
      'T4' => _validateT4(state),
      _ => _Verdict([]),
    };

// ---------------------------------------------------------------------------
// Code-capturing extension wrapper
// ---------------------------------------------------------------------------

/// A single captured tool call: the code sent and the result returned.
class _CapturedCall {
  _CapturedCall({required this.code, required this.result});
  final String code;
  final String result;
}

/// Wraps a [SessionExtension] and intercepts `execute_python` tool calls
/// to record the generated Python code AND execution result.
class _CodeCapturingExtension implements SessionExtension {
  _CodeCapturingExtension(this._delegate);

  final SessionExtension _delegate;

  /// All captured calls in execution order.
  final List<_CapturedCall> capturedCalls = [];

  @override
  List<ClientTool> get tools => _delegate.tools.map((t) {
        if (t.definition.name == 'execute_python') {
          return ClientTool(
            definition: t.definition,
            executor: (call, ctx) async {
              String? code;
              try {
                final decoded =
                    jsonDecode(call.arguments) as Map<String, Object?>;
                code = decoded['code'] as String?;
              } on Object catch (_) {
                // Best-effort capture — don't block execution.
              }
              final result = await t.executor(call, ctx);
              capturedCalls.add(
                _CapturedCall(
                  code: code ?? '<parse error>',
                  result: result,
                ),
              );
              return result;
            },
          );
        }
        return t;
      }).toList();

  @override
  Future<void> onAttach(AgentSession session) => _delegate.onAttach(session);

  @override
  void onDispose() => _delegate.onDispose();
}

// ---------------------------------------------------------------------------
// Experiment runner
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  final host = args.isNotEmpty ? args[0] : 'http://localhost:8000';
  final baseDir = args.length > 1 ? args[1] : '/tmp/construction-experiment';
  final iterations = args.length > 2 ? int.tryParse(args[2]) ?? 1 : 1;

  final logManager = LogManager.instance
    ..minimumLevel = LogLevel.debug
    ..addSink(StdoutSink(useColors: true));
  final logger = logManager.getLogger('experiment');

  // Verify rooms with a one-shot connection.
  {
    final check = createVerboseConnection(host);
    final roomList = await check.api.getRooms();
    final roomIds = roomList.map((r) => r.id).toSet();
    for (final run in _rooms) {
      if (!roomIds.contains(run.roomId)) {
        stderr.writeln('Room ${run.roomId} not found on server!');
        exit(1);
      }
    }
    await check.close();
  }
  stderr
    ..writeln('All ${_rooms.length} rooms found on server.')
    ..writeln('Running $iterations iteration(s).');

  for (var iter = 1; iter <= iterations; iter++) {
    final outputDir = iterations == 1 ? baseDir : '$baseDir/run$iter';
    await Directory(outputDir).create(recursive: true);

    stderr.writeln(
      '\n${'#' * 70}\n'
      'ITERATION $iter / $iterations\n'
      '${'#' * 70}',
    );

    for (final run in _rooms) {
      stderr.writeln(
        '\n${'=' * 70}\n'
        '${run.tier} ${run.modelSize}: ${run.roomId}\n'
        '${'=' * 70}',
      );

      // Fresh connection + state per room.
      final connection = createVerboseConnection(host);
      final state = ConstructionState(
        jobs: _jobs,
        staff: _staff,
        weather: _weather,
      );
      final plugin = ConstructionPlugin(state: state);

      // For T3 (dispatcher), pre-seed a schedule and create streams.
      if (run.needsStreams) {
        state
          ..assign('Bob', 'H1_FND', 2)
          ..assign('Alice', 'H1_FRM', 3)
          ..assign('Charlie', 'H1_ROF', 4)
          ..assign('Bob', 'H2_FND', 3)
          ..assign('Alice', 'H2_FRM', 4);
      }

      final hostApi = FakeHostApi(
        invokeHandler: (name, fnArgs) async {
          if (name == 'log') {
            final level = fnArgs['level'] ?? 'info';
            final message = fnArgs['message'] ?? '';
            stderr.writeln('[MONTY:$level] $message');
            return null;
          }
          throw UnimplementedError(
            'FakeHostApi.invoke: no handler for "$name"',
          );
        },
      );
      final blackboardApi = DirectBlackboardApi();
      final fetchClient = DartHttpClient();

      // Code-capturing wrapper — one per room run.
      _CodeCapturingExtension? codeCapture;

      AgentApi? agentApi;
      Future<List<SessionExtension>> extensionFactory() async {
        final factory = createMontyScriptEnvironmentFactory(
          hostApi: hostApi,
          agentApi: agentApi,
          blackboardApi: blackboardApi,
          httpClient: fetchClient,
          platformFactory: () async => MontyFfi(bindings: NativeBindingsFfi()),
          limits: MontyLimitsDefaults.tool,
          extraFunctions: plugin.functions,
          executionTimeout: const Duration(seconds: 60),
          streamSetup: run.needsStreams
              ? (streams) {
                  streams
                    ..registerFactory(
                      'crew_updates',
                      () => Stream.fromIterable([
                        <String, Object?>{
                          'type': 'crew_noshow',
                          'worker': 'Alice',
                          'day': 3,
                        },
                      ]),
                    )
                    ..registerFactory(
                      'weather_updates',
                      () => Stream.fromIterable([
                        <String, Object?>{
                          'type': 'weather_change',
                          'day': 4,
                          'condition': 'rain',
                        },
                      ]),
                    );
                }
              : null,
        );
        final env = await factory();
        final ext = ScriptEnvironmentExtension(env);
        codeCapture = _CodeCapturingExtension(ext);
        return [codeCapture!];
      }

      final runtime = AgentRuntime(
        connection: connection,
        toolRegistryResolver: (_) async => const ToolRegistry(),
        platform: const NativePlatformConstraints(),
        logger: logger,
        extensionFactory: extensionFactory,
      );
      agentApi = RuntimeAgentApi(runtime: runtime);

      final stopwatch = Stopwatch()..start();
      try {
        final session = await runtime.spawn(
          roomId: run.roomId,
          prompt: run.prompt,
        );

        final result = await session.awaitResult(
          timeout: const Duration(seconds: 180),
        );
        stopwatch.stop();

        final output = formatResult(result);
        stderr.writeln(output);

        // Validate correctness.
        final verdict = _validate(run, state);
        stderr
          ..writeln('VERDICT: ${verdict.summary}')
          ..writeln(verdict.details);

        // Write result + state + captured python + verdict to file.
        final file = File('$outputDir/${run.roomId}.txt');
        final sink = file.openWrite()
          ..writeln('Room: ${run.roomId}')
          ..writeln('Tier: ${run.tier}  Model: ${run.modelSize}')
          ..writeln('Duration: ${stopwatch.elapsed}')
          ..writeln()
          ..writeln('=== Verdict ===')
          ..writeln(verdict.summary)
          ..writeln(verdict.details)
          ..writeln()
          ..writeln('=== LLM Result ===')
          ..writeln(output)
          ..writeln()
          ..writeln('=== Tool Calls ===');
        final calls = codeCapture?.capturedCalls ?? [];
        for (var i = 0; i < calls.length; i++) {
          sink
            ..writeln('--- call ${i + 1} ---')
            ..writeln('[code]')
            ..writeln(calls[i].code)
            ..writeln()
            ..writeln('[result]')
            ..writeln(calls[i].result)
            ..writeln();
        }
        sink
          ..writeln('=== Final Schedule ===')
          ..writeln(state.getSchedule())
          ..writeln()
          ..writeln('=== Conflicts ===')
          ..writeln(state.detectConflicts())
          ..writeln()
          ..writeln('=== Completed Jobs ===');
        final completedIds = state.jobs
            .where((j) => state.jobStatus(j.id) == 'completed')
            .map((j) => j.id)
            .toList();
        sink.writeln(completedIds);
        await sink.close();

        stderr.writeln(
          'Saved to ${file.path}  '
          '(${stopwatch.elapsed}, '
          '${verdict.summary}, '
          '${calls.length} tool calls)',
        );
      } on Object catch (e, st) {
        stopwatch.stop();
        final verdict = _validate(run, state);
        stderr
          ..writeln('FAILED (${stopwatch.elapsed}): $e')
          ..writeln('VERDICT: ${verdict.summary}')
          ..writeln(verdict.details)
          ..writeln(st);

        final file = File('$outputDir/${run.roomId}.txt');
        final calls = codeCapture?.capturedCalls ?? [];
        final callSection = StringBuffer('=== Tool Calls ===\n');
        for (var i = 0; i < calls.length; i++) {
          callSection
            ..writeln('--- call ${i + 1} ---')
            ..writeln('[code]')
            ..writeln(calls[i].code)
            ..writeln()
            ..writeln('[result]')
            ..writeln(calls[i].result)
            ..writeln();
        }
        await file.writeAsString(
          'Room: ${run.roomId}\n'
          'Tier: ${run.tier}  Model: ${run.modelSize}\n'
          'Duration: ${stopwatch.elapsed}\n\n'
          '=== Verdict ===\n'
          '${verdict.summary}\n'
          '${verdict.details}\n\n'
          '$callSection\n'
          '=== ERROR ===\n$e\n$st\n',
        );
      }

      await runtime.dispose();
      await connection.close();
      // Brief pause between rooms.
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  stderr.writeln('\nExperiment complete. Results in $baseDir');
}
