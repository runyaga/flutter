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

const _t5Prompt =
    'A construction schedule has already been built and completed.\n'
    'Your job is to VERIFY it is correct by working backwards:\n\n'
    '1. Get the full schedule and list of jobs/staff.\n'
    '2. Check for conflicts (double-bookings, etc.).\n'
    '3. For each assignment, verify:\n'
    '   - The worker has the right trade for the job.\n'
    '   - Outdoor jobs are NOT on rainy days (day 1 = rain).\n'
    '   - Dependencies are satisfied (foundation before framing, '
    'framing before roofing).\n'
    '4. Confirm all jobs are completed.\n\n'
    'Report each check and whether the schedule passes or fails.';

/// Room used for all verification runs (120B model).
const _verifyRoomId = 'construction-verify-120b';

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

/// Verify that the state is still correct after verification pass.
/// Uses the same tier-specific checks plus confirms tool calls were made.
_Verdict _validateVerify(
  _RoomRun originalRun,
  ConstructionState state,
  int toolCallCount,
) {
  final tierChecks = _validate(originalRun, state);
  return _Verdict([
    ...tierChecks.checks,
    _Check('verifier made ≥1 tool call', passed: toolCallCount >= 1),
    _Check('state not corrupted', passed: state.detectConflicts().isEmpty),
  ]);
}

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
// Single room runner (shared between generation and verification)
// ---------------------------------------------------------------------------

class _RunResult {
  _RunResult({
    required this.output,
    required this.verdict,
    required this.calls,
    required this.elapsed,
  });
  final String output;
  final _Verdict verdict;
  final List<_CapturedCall> calls;
  final Duration elapsed;
}

/// Run a single room and return the result. [state] and [plugin] are
/// shared — the caller owns them and can reuse across phases.
Future<_RunResult?> _runRoom({
  required String host,
  required String roomId,
  required String prompt,
  required String tier,
  required String modelSize,
  required ConstructionState state,
  required ConstructionPlugin plugin,
  required Logger logger,
  required String outputDir,
  required String filePrefix,
  required _Verdict Function(ConstructionState) validator,
  int maxToolDepth = RunOrchestrator.defaultMaxToolDepth,
}) async {
  final connection = createVerboseConnection(host);

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
    maxToolDepth: maxToolDepth,
  );
  agentApi = RuntimeAgentApi(runtime: runtime);

  final stopwatch = Stopwatch()..start();
  _RunResult? runResult;
  try {
    final session = await runtime.spawn(
      roomId: roomId,
      prompt: prompt,
    );

    final result = await session.awaitResult(
      timeout: const Duration(seconds: 180),
    );
    stopwatch.stop();

    final output = formatResult(result);
    stderr.writeln(output);

    final verdict = validator(state);
    stderr
      ..writeln('VERDICT: ${verdict.summary}')
      ..writeln(verdict.details);

    final calls = codeCapture?.capturedCalls ?? [];
    runResult = _RunResult(
      output: output,
      verdict: verdict,
      calls: calls,
      elapsed: stopwatch.elapsed,
    );

    // Write result file.
    final file = File('$outputDir/$filePrefix.txt');
    final sink = file.openWrite()
      ..writeln('Room: $roomId')
      ..writeln('Tier: $tier  Model: $modelSize')
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
    final verdict = validator(state);
    stderr
      ..writeln('FAILED (${stopwatch.elapsed}): $e')
      ..writeln('VERDICT: ${verdict.summary}')
      ..writeln(verdict.details)
      ..writeln(st);

    final calls = codeCapture?.capturedCalls ?? [];
    runResult = _RunResult(
      output: 'ERROR: $e',
      verdict: verdict,
      calls: calls,
      elapsed: stopwatch.elapsed,
    );

    final file = File('$outputDir/$filePrefix.txt');
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
      'Room: $roomId\n'
      'Tier: $tier  Model: $modelSize\n'
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
  return runResult;
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
    if (!roomIds.contains(_verifyRoomId)) {
      stderr.writeln('Room $_verifyRoomId not found on server!');
      exit(1);
    }
    await check.close();
  }
  stderr
    ..writeln('All ${_rooms.length} rooms + verify room found on server.')
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

      // Fresh state per room.
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

      // --- Phase 1: Generation ---
      final genResult = await _runRoom(
        host: host,
        roomId: run.roomId,
        prompt: run.prompt,
        tier: run.tier,
        modelSize: run.modelSize,
        state: state,
        plugin: plugin,
        logger: logger,
        outputDir: outputDir,
        filePrefix: run.roomId,
        validator: (s) => _validate(run, s),
        maxToolDepth: run.modelSize == '20B' ? 22 : 20,
      );

      // --- Phase 2: Verification (120B proves the answer correct) ---
      if (genResult != null && genResult.verdict.passed) {
        stderr.writeln(
          '\n  --- T5 Verify (120B) for ${run.tier} ${run.modelSize} ---',
        );

        // Snapshot schedule before verification.
        final scheduleBefore = state.getSchedule().toString();

        final verifyResult = await _runRoom(
          host: host,
          roomId: _verifyRoomId,
          prompt: _t5Prompt,
          tier: 'T5',
          modelSize: '120B',
          state: state,
          plugin: plugin,
          logger: logger,
          outputDir: outputDir,
          filePrefix: '${run.roomId}-verify',
          validator: (s) => _validateVerify(
            run,
            s,
            // Will be set after the run; pass 0 as placeholder,
            // the real count is checked in the post-hoc verdict.
            0,
          ),
        );

        // Post-hoc: check state wasn't mutated + tool calls were made.
        if (verifyResult != null) {
          final scheduleAfter = state.getSchedule().toString();
          final statePreserved = scheduleBefore == scheduleAfter;
          final verifyCalls = verifyResult.calls.length;
          if (!statePreserved) {
            stderr.writeln(
              '  WARNING: Verifier mutated the schedule!',
            );
          }
          stderr.writeln(
            '  Verify: ${statePreserved ? "state preserved" : "STATE CHANGED"}'
            ', $verifyCalls tool calls',
          );
        }
      } else {
        stderr.writeln('  Skipping verification (generation not CORRECT).');
      }

      // Brief pause between rooms.
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  stderr.writeln('\nExperiment complete. Results in $baseDir');
}
