import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

// ---------------------------------------------------------------------------
// Room profiles — each room sees only the tools it needs.
// ---------------------------------------------------------------------------

/// Which capabilities to expose in the system prompt.
enum RoomCapability { scheduling, streams, agents, blackboard }

/// Pre-defined room profiles matching the experiment tiers.
enum RoomProfile {
  /// Tier 1: Follow step-by-step instructions. Core scheduling only.
  prescriptive({RoomCapability.scheduling}),

  /// Tier 2: Build a schedule autonomously. Scheduling + delegation.
  scheduler({RoomCapability.scheduling, RoomCapability.agents}),

  /// Tier 3: React to live disruptions via event streams.
  dispatcher({
    RoomCapability.scheduling,
    RoomCapability.streams,
  }),

  /// Tier 4: Handle errors, reflect, retry. Scheduling + memory.
  recovery({
    RoomCapability.scheduling,
    RoomCapability.blackboard,
  }),

  /// All capabilities (for the combined test harness).
  full({
    RoomCapability.scheduling,
    RoomCapability.streams,
    RoomCapability.agents,
    RoomCapability.blackboard,
  });

  const RoomProfile(this.capabilities);
  final Set<RoomCapability> capabilities;
}

// ---------------------------------------------------------------------------
// Composable prompt sections
// ---------------------------------------------------------------------------

/// Builds the system prompt from composable sections based on
/// which [RoomCapability]s are active.
class ConstructionPrompts {
  const ConstructionPrompts._();

  static String build({
    required Set<RoomCapability> capabilities,
    required String role,
    required String goal,
  }) {
    final sections = StringBuffer()
      ..writeln(role)
      ..writeln()
      ..writeln(goal)
      ..writeln()
      ..writeln('You MUST think step-by-step. For each step, decide '
          'which function to call,')
      ..writeln('execute it, and use the result to inform your '
          'next action.')
      ..writeln('You may ONLY use the functions listed below '
          '— do not invent functions.')
      ..writeln()
      ..writeln(coreScheduling);

    if (capabilities.contains(RoomCapability.streams)) {
      sections
        ..writeln()
        ..writeln(reactiveStreams);
    }
    if (capabilities.contains(RoomCapability.agents)) {
      sections
        ..writeln()
        ..writeln(agentDelegation);
    }
    if (capabilities.contains(RoomCapability.blackboard)) {
      sections
        ..writeln()
        ..writeln(sharedMemory);
    }

    // Add relevant patterns.
    sections.writeln();
    if (capabilities.contains(RoomCapability.scheduling)) {
      sections
        ..writeln(patternScheduling)
        ..writeln();
    }
    if (capabilities.contains(RoomCapability.streams)) {
      sections
        ..writeln(patternReactive)
        ..writeln();
    }
    // Error recovery pattern is always useful.
    sections.writeln(patternErrorRecovery);

    return sections.toString().trimRight();
  }

  // -- Section: Core Scheduling -------------------------------------------

  static const coreScheduling = '''
## Scheduling Functions

- construction_get_jobs() → all jobs with deps, trade, outdoor flag
- construction_get_staff() → all workers with trade and skill level
- construction_get_weather(day) → "rain" or "sunny"
- construction_get_ready_jobs() → jobs pending AND deps met
- construction_find_workers_for_job(job_id, day) → workers qualified
  AND available for this job on this day (empty if none)
- construction_get_job_details(job_id) → full details: id, trade,
  outdoor, status, deps with their statuses
- construction_assign(worker, job_id, day) → assigns worker. Returns
  {"ok": true} on success, or {"ok": false, "error_code": "CODE",
  "error": "human message", "context": {...}} on failure.
  Error codes: TRADE_MISMATCH, DEPS_NOT_MET, WEATHER_RAIN,
  DOUBLE_BOOKING, UNKNOWN_JOB, UNKNOWN_WORKER
- construction_unassign(worker, day) → remove assignment
- construction_complete_job(job_id) → mark done, unlocks dependents
- construction_advance_day(day) → complete all jobs on that day,
  returns list of completed job IDs (idempotent)
- construction_get_schedule() → full current schedule
- construction_get_day_schedule(day) → assignments for one day
- construction_detect_conflicts() → constraint violations (empty=valid)
- construction_job_status(job_id) → "pending"/"in_progress"/"completed"
- construction_deps_met(job_id) → true if all deps completed
- construction_is_outdoor(job_id) → true if outdoor work
- construction_available_workers(day) → workers not assigned that day
- construction_workers_for_trade(trade) → workers with that trade''';

  // -- Section: Reactive Event Handling -----------------------------------

  static const reactiveStreams = '''
## Event Streams

Subscribe to real-time disruption streams and react as events arrive.

- stream_subscribe(name) → subscribe to named stream, returns handle
- stream_select(handles) → race multiple streams. Returns
  {"handle": N, "data": {...}} for whichever fires first,
  or null when ALL streams are exhausted
- stream_next(handle) → pull next event from one stream (null=done)
- stream_close(handle) → unsubscribe from a stream''';

  // -- Section: Agent Delegation ------------------------------------------

  static const agentDelegation = '''
## Reasoning & Delegation

- ask_llm(prompt, room?) → send a question to another LLM, returns
  {"text": "response", "thread_id": "..."}
- spawn_agent(room, prompt) → spawn a sub-agent, returns handle
- agent_watch(handle) → wait for agent result
- cancel_agent(handle) → cancel a running agent''';

  // -- Section: Shared Memory ---------------------------------------------

  static const sharedMemory = '''
## Shared Memory

Use the blackboard to record reasoning, track retries, and reflect
on past errors.

- blackboard_write(key, value) → store a value
- blackboard_read(key) → retrieve a value
- blackboard_keys() → list all keys''';

  // -- Pattern: Autonomous Scheduling -------------------------------------

  static const patternScheduling = '''
### Pattern: Autonomous Scheduling
```
current_day = 1
while construction_get_ready_jobs() has jobs:
  for each ready job:
    candidates = construction_find_workers_for_job(job_id, day)
    if candidates not empty:
      construction_assign(candidates[0], job_id, current_day)
  construction_advance_day(current_day)
  current_day += 1
construction_detect_conflicts()  # verify
```''';

  // -- Pattern: Reactive Disruption Handling ------------------------------

  static const patternReactive = '''
### Pattern: Reactive Disruption Handling
```
crew_h = stream_subscribe("crew_updates")
weather_h = stream_subscribe("weather_updates")
while True:
  event = stream_select([crew_h, weather_h])
  if event is None: break
  data = event["data"]
  if data["type"] == "crew_noshow":
    construction_unassign(data["worker"], data["day"])
    # find replacement or reschedule
  elif data["type"] == "weather_change":
    # move outdoor jobs on affected day
```''';

  // -- Pattern: Error Recovery --------------------------------------------

  static const patternErrorRecovery = '''
### Pattern: Error Recovery
```
result = construction_assign(worker, job_id, day)
if not result["ok"]:
  code = result["error_code"]
  if code == "TRADE_MISMATCH":
    candidates = construction_find_workers_for_job(job_id, day)
    # retry with correct worker
  elif code == "DEPS_NOT_MET":
    # schedule prerequisite first, then retry
  elif code == "WEATHER_RAIN":
    # find next sunny day, retry
  elif code == "DOUBLE_BOOKING":
    # try a different day
```''';

  // -- Per-room role + goal -----------------------------------------------

  static String roleFor(RoomProfile profile) => switch (profile) {
        RoomProfile.prescriptive =>
          'You are a construction scheduling assistant. Follow '
              'the instructions given to you exactly.',
        RoomProfile.scheduler =>
          'You are an autonomous construction scheduler. Create '
              'an optimal, conflict-free schedule that finishes '
              'as early as possible.',
        RoomProfile.dispatcher =>
          'You are a disruption dispatcher. Monitor event streams '
              'and keep the schedule valid by reacting to crew '
              'no-shows, weather changes, and material delays.',
        RoomProfile.recovery =>
          'You are a resilient scheduler. Build a schedule, but '
              'expect errors. When assign() fails, diagnose the '
              'error, fix the problem, and retry.',
        RoomProfile.full =>
          'You are an autonomous construction scheduler. Create '
              'and maintain an optimal, conflict-free schedule.',
      };

  static String goalFor(RoomProfile profile) => switch (profile) {
        RoomProfile.prescriptive =>
          'Execute the assignment sequence you are given. '
              'Call the functions in order.',
        RoomProfile.scheduler =>
          'Schedule all jobs as soon as possible. Minimize total '
              'project duration. Use construction_get_ready_jobs() '
              'to find what can be scheduled, maximize parallelism '
              'across houses, and call construction_detect_conflicts()'
              ' to verify your work.',
        RoomProfile.dispatcher =>
          'Subscribe to all available event streams. Enter a '
              'select loop. When a disruption arrives, read its '
              'type and payload, then take corrective action '
              '(unassign, reschedule, update weather).',
        RoomProfile.recovery =>
          'Build a valid schedule. The assign() function will '
              'return structured errors when constraints are '
              'violated. Inspect error_code and context to '
              'diagnose failures, then fix and retry. Use the '
              'blackboard to track past errors and avoid repeating '
              'mistakes.',
        RoomProfile.full =>
          'Create and maintain an optimal, conflict-free schedule '
              'using all available capabilities.',
      };

  /// Build the complete system prompt for a room profile.
  static String forProfile(RoomProfile profile) => build(
        capabilities: profile.capabilities,
        role: roleFor(profile),
        goal: goalFor(profile),
      );
}

/// Domain-specific host functions for home construction scheduling.
///
/// The LLM doesn't implement scheduling logic — it calls these functions
/// and writes the glue code (branching, looping, reacting to disruptions).
///
/// All state lives in [ConstructionState] which the plugin owns.
/// Functions are registered under the `construction` namespace.
class ConstructionPlugin extends MontyPlugin {
  ConstructionPlugin({
    required this.state,
    this.profile = RoomProfile.full,
  });

  final ConstructionState state;
  final RoomProfile profile;

  @override
  String get namespace => 'construction';

  @override
  String? get systemPromptContext => ConstructionPrompts.forProfile(profile);

  @override
  List<HostFunction> get functions => [
        _fn(
          'construction_get_jobs',
          'Get all jobs with dependencies, required trade, and outdoor flag.',
          [],
          (_) async => state.jobs.map((j) => j.toMap()).toList(),
        ),
        _fn(
          'construction_get_staff',
          'Get all workers with their trade and skill level.',
          [],
          (_) async => state.staff.map((s) => s.toMap()).toList(),
        ),
        _fn(
          'construction_get_weather',
          'Get weather condition for a day. Returns "rain" or "sunny".',
          [_param('day', HostParamType.integer, 'Day number.')],
          (args) async {
            final day = args['day']! as int;
            return state.getWeather(day);
          },
        ),
        _fn(
          'construction_deps_met',
          'Check if all dependencies for a job are completed.',
          [_param('job_id', HostParamType.string, 'Job ID.')],
          (args) async {
            final jobId = args['job_id']! as String;
            return state.depsMet(jobId);
          },
        ),
        _fn(
          'construction_is_outdoor',
          'Check if a job requires outdoor work.',
          [_param('job_id', HostParamType.string, 'Job ID.')],
          (args) async {
            final jobId = args['job_id']! as String;
            final job = state.findJob(jobId);
            return job?.outdoor ?? false;
          },
        ),
        _fn(
          'construction_available_workers',
          'Get workers not assigned to any job on the given day.',
          [_param('day', HostParamType.integer, 'Day number.')],
          (args) async {
            final day = args['day']! as int;
            return state.availableWorkers(day).map((s) => s.toMap()).toList();
          },
        ),
        _fn(
          'construction_workers_for_trade',
          'Get all workers that have the given trade.',
          [_param('trade', HostParamType.string, 'Trade name.')],
          (args) async {
            final trade = args['trade']! as String;
            return state.staff
                .where((s) => s.trade == trade)
                .map((s) => s.toMap())
                .toList();
          },
        ),
        _fn(
          'construction_assign',
          'Assign a worker to a job on a day. Returns {"ok": true} '
              'on success. On failure returns {"ok": false, '
              '"error_code": "CODE", "error": "message", '
              '"context": {...}}. Error codes: TRADE_MISMATCH, '
              'DEPS_NOT_MET, WEATHER_RAIN, DOUBLE_BOOKING, '
              'UNKNOWN_JOB, UNKNOWN_WORKER.',
          [
            _param('worker', HostParamType.string, 'Worker name.'),
            _param('job_id', HostParamType.string, 'Job ID.'),
            _param('day', HostParamType.integer, 'Day number.'),
          ],
          (args) async {
            final worker = args['worker']! as String;
            final jobId = args['job_id']! as String;
            final day = args['day']! as int;
            return state.assign(worker, jobId, day);
          },
        ),
        _fn(
          'construction_unassign',
          'Remove a worker assignment for a given day.',
          [
            _param('worker', HostParamType.string, 'Worker name.'),
            _param('day', HostParamType.integer, 'Day number.'),
          ],
          (args) async {
            final worker = args['worker']! as String;
            final day = args['day']! as int;
            return state.unassign(worker, day);
          },
        ),
        _fn(
          'construction_get_schedule',
          'Get the full current schedule as a list of assignments.',
          [],
          (_) async => state.getSchedule(),
        ),
        _fn(
          'construction_get_day_schedule',
          'Get assignments for a specific day.',
          [_param('day', HostParamType.integer, 'Day number.')],
          (args) async {
            final day = args['day']! as int;
            return state.getDaySchedule(day);
          },
        ),
        _fn(
          'construction_detect_conflicts',
          'Check the current schedule for constraint violations. Returns '
              'a list of conflict descriptions (empty if valid).',
          [],
          (_) async => state.detectConflicts(),
        ),
        _fn(
          'construction_inject_disruption',
          'Inject a disruption event for a day (crew sick, material delay, '
              'weather change).',
          [
            _param('day', HostParamType.integer, 'Day number.'),
            _param('disruption', HostParamType.map, 'Disruption details.'),
          ],
          (args) async {
            final day = args['day']! as int;
            final disruption =
                Map<String, Object?>.from(args['disruption']! as Map);
            state.injectDisruption(day, disruption);
            return null;
          },
        ),
        _fn(
          'construction_get_disruptions',
          'Get all disruptions for a day.',
          [_param('day', HostParamType.integer, 'Day number.')],
          (args) async {
            final day = args['day']! as int;
            return state.getDisruptions(day);
          },
        ),
        _fn(
          'construction_complete_job',
          'Mark a job as completed. Unlocks dependent jobs.',
          [_param('job_id', HostParamType.string, 'Job ID.')],
          (args) async {
            final jobId = args['job_id']! as String;
            return state.completeJob(jobId);
          },
        ),
        _fn(
          'construction_job_status',
          'Get job status: "pending", "in_progress", or "completed".',
          [_param('job_id', HostParamType.string, 'Job ID.')],
          (args) async {
            final jobId = args['job_id']! as String;
            return state.jobStatus(jobId);
          },
        ),
        _fn(
          'construction_get_ready_jobs',
          'Get jobs that are pending and have all dependencies met. '
              'These are the jobs that can be scheduled right now.',
          [],
          (_) async => state.getReadyJobs().map((j) => j.toMap()).toList(),
        ),
        _fn(
          'construction_advance_day',
          'Mark all assigned jobs on the given day as completed. '
              'Returns the list of job IDs that were completed. '
              'Idempotent — calling twice returns empty on second call.',
          [_param('day', HostParamType.integer, 'Day number.')],
          (args) async {
            final day = args['day']! as int;
            return state.advanceDay(day);
          },
        ),
        _fn(
          'construction_find_workers_for_job',
          'Find workers who are qualified (correct trade) AND '
              'available (not scheduled) for a job on a given day. '
              'Returns empty list if none available.',
          [
            _param('job_id', HostParamType.string, 'Job ID.'),
            _param('day', HostParamType.integer, 'Day number.'),
          ],
          (args) async {
            final jobId = args['job_id']! as String;
            final day = args['day']! as int;
            return state
                .findWorkersForJob(jobId, day)
                .map((s) => s.toMap())
                .toList();
          },
        ),
        _fn(
          'construction_get_job_details',
          'Get full details for a job: id, house, task, trade, '
              'outdoor, status, and dependency statuses.',
          [_param('job_id', HostParamType.string, 'Job ID.')],
          (args) async {
            final jobId = args['job_id']! as String;
            return state.getJobDetails(jobId);
          },
        ),
      ];

  static HostFunction _fn(
    String name,
    String description,
    List<HostParam> params,
    HostFunctionHandler handler,
  ) =>
      HostFunction(
        schema: HostFunctionSchema(
          name: name,
          description: description,
          params: params,
        ),
        handler: handler,
      );

  static HostParam _param(
    String name,
    HostParamType type,
    String description,
  ) =>
      HostParam(name: name, type: type, description: description);
}

// ---------------------------------------------------------------------------
// Domain models
// ---------------------------------------------------------------------------

class Job {
  const Job({
    required this.id,
    required this.house,
    required this.task,
    required this.trade,
    required this.material,
    required this.deps,
    required this.outdoor,
  });

  final String id;
  final String house;
  final String task;
  final String trade;
  final String material;
  final List<String> deps;
  final bool outdoor;

  Map<String, Object?> toMap() => {
        'id': id,
        'house': house,
        'task': task,
        'trade': trade,
        'material': material,
        'deps': deps,
        'outdoor': outdoor,
      };
}

class Worker {
  const Worker({
    required this.name,
    required this.trade,
    required this.level,
  });

  final String name;
  final String trade;
  final String level;

  Map<String, Object?> toMap() => {
        'name': name,
        'trade': trade,
        'level': level,
      };
}

class Assignment {
  const Assignment({
    required this.worker,
    required this.jobId,
    required this.day,
  });

  final String worker;
  final String jobId;
  final int day;

  Map<String, Object?> toMap() => {
        'worker': worker,
        'job_id': jobId,
        'day': day,
      };
}

// ---------------------------------------------------------------------------
// Stateful domain engine — all scheduling logic lives here
// ---------------------------------------------------------------------------

class ConstructionState {
  ConstructionState({
    required this.jobs,
    required this.staff,
    required this.weather,
  });

  final List<Job> jobs;
  final List<Worker> staff;
  final Map<int, String> weather; // day → "rain" | "sunny"

  final List<Assignment> _assignments = [];
  final Set<String> _completed = {};
  final Map<int, List<Map<String, Object?>>> _disruptions = {};

  // -- Queries --------------------------------------------------------------

  Job? findJob(String id) {
    for (final j in jobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  String getWeather(int day) => weather[day] ?? 'sunny';

  bool depsMet(String jobId) {
    final job = findJob(jobId);
    if (job == null) return false;
    return job.deps.every(_completed.contains);
  }

  List<Worker> availableWorkers(int day) {
    final assigned =
        _assignments.where((a) => a.day == day).map((a) => a.worker).toSet();
    return staff.where((s) => !assigned.contains(s.name)).toList();
  }

  List<Map<String, Object?>> getSchedule() =>
      _assignments.map((a) => a.toMap()).toList();

  List<Map<String, Object?>> getDaySchedule(int day) =>
      _assignments.where((a) => a.day == day).map((a) => a.toMap()).toList();

  String jobStatus(String jobId) {
    if (_completed.contains(jobId)) return 'completed';
    if (_assignments.any((a) => a.jobId == jobId)) return 'in_progress';
    return 'pending';
  }

  /// Jobs that are pending (not assigned, not completed) and have all
  /// dependencies met. These are the jobs the LLM should schedule next.
  List<Job> getReadyJobs() => jobs.where((j) {
        if (_completed.contains(j.id)) return false;
        if (_assignments.any((a) => a.jobId == j.id)) return false;
        return depsMet(j.id);
      }).toList();

  /// Mark all assigned jobs on [day] as completed.
  /// Returns the list of job IDs that were completed.
  /// Idempotent — already-completed jobs are skipped.
  List<String> advanceDay(int day) {
    final dayJobs = _assignments
        .where((a) => a.day == day)
        .map((a) => a.jobId)
        .where((id) => !_completed.contains(id))
        .toList()
      ..forEach(_completed.add);
    return dayJobs;
  }

  /// Workers who are qualified (correct trade) AND available
  /// (not assigned) for [jobId] on [day].
  List<Worker> findWorkersForJob(String jobId, int day) {
    final job = findJob(jobId);
    if (job == null) return [];
    final available = availableWorkers(day);
    return available.where((w) => w.trade == job.trade).toList();
  }

  /// Full details for a job including dependency statuses.
  Map<String, Object?>? getJobDetails(String jobId) {
    final job = findJob(jobId);
    if (job == null) return null;
    return {
      'id': job.id,
      'house': job.house,
      'task': job.task,
      'trade': job.trade,
      'outdoor': job.outdoor,
      'status': jobStatus(job.id),
      'deps': job.deps.map((d) => {'id': d, 'status': jobStatus(d)}).toList(),
    };
  }

  // -- Mutations ------------------------------------------------------------

  /// Assign a worker to a job on a day. Validates all constraints.
  Map<String, Object?> assign(String workerName, String jobId, int day) {
    final job = findJob(jobId);
    if (job == null) {
      return {
        'ok': false,
        'error_code': 'UNKNOWN_JOB',
        'error': 'Unknown job: $jobId',
        'context': {'job_id': jobId},
      };
    }

    final worker = staff.where((s) => s.name == workerName).firstOrNull;
    if (worker == null) {
      return {
        'ok': false,
        'error_code': 'UNKNOWN_WORKER',
        'error': 'Unknown worker: $workerName',
        'context': {'worker': workerName},
      };
    }

    // Trade match.
    if (worker.trade != job.trade) {
      return {
        'ok': false,
        'error_code': 'TRADE_MISMATCH',
        'error': '${worker.name} is a ${worker.trade}, '
            'but ${job.id} needs a ${job.trade}.',
        'context': {
          'worker': worker.name,
          'worker_trade': worker.trade,
          'job_id': job.id,
          'required_trade': job.trade,
        },
      };
    }

    // Dependencies.
    if (!depsMet(jobId)) {
      final unmet = job.deps.where((d) => !_completed.contains(d)).toList();
      return {
        'ok': false,
        'error_code': 'DEPS_NOT_MET',
        'error': 'Dependencies not met for $jobId: $unmet',
        'context': {
          'job_id': jobId,
          'unmet_deps': unmet,
        },
      };
    }

    // Weather.
    if (job.outdoor && getWeather(day) == 'rain') {
      return {
        'ok': false,
        'error_code': 'WEATHER_RAIN',
        'error': '$jobId is outdoor work and day $day has rain.',
        'context': {
          'job_id': jobId,
          'day': day,
        },
      };
    }

    // Worker availability.
    final busy = _assignments
        .where((a) => a.day == day && a.worker == workerName)
        .isNotEmpty;
    if (busy) {
      return {
        'ok': false,
        'error_code': 'DOUBLE_BOOKING',
        'error': '$workerName is already assigned on day $day.',
        'context': {
          'worker': workerName,
          'day': day,
        },
      };
    }

    _assignments.add(Assignment(worker: workerName, jobId: jobId, day: day));
    return {'ok': true};
  }

  /// Remove a worker's assignment for a day.
  Map<String, Object?> unassign(String workerName, int day) {
    _assignments.removeWhere((a) => a.worker == workerName && a.day == day);
    return {'ok': true};
  }

  /// Mark a job as completed.
  Map<String, Object?> completeJob(String jobId) {
    if (findJob(jobId) == null) {
      return {'ok': false, 'error': 'Unknown job: $jobId'};
    }
    _completed.add(jobId);
    return {'ok': true};
  }

  // -- Conflict detection ---------------------------------------------------

  /// Check the full schedule for constraint violations.
  List<String> detectConflicts() {
    final conflicts = <String>[];

    for (final a in _assignments) {
      final job = findJob(a.jobId);
      if (job == null) {
        conflicts.add('Assignment references unknown job: ${a.jobId}');
        continue;
      }

      // Trade mismatch.
      final worker = staff.where((s) => s.name == a.worker).firstOrNull;
      if (worker != null && worker.trade != job.trade) {
        conflicts.add('${a.worker} (${worker.trade}) assigned to '
            '${a.jobId} which needs ${job.trade}');
      }

      // Weather violation.
      if (job.outdoor && getWeather(a.day) == 'rain') {
        conflicts.add('${a.jobId} is outdoor but day ${a.day} has rain');
      }

      // Dependency violation.
      for (final dep in job.deps) {
        final depDay = _completionDay(dep);
        if (depDay == null || depDay >= a.day) {
          conflicts.add('${a.jobId} on day ${a.day} but dep $dep '
              '${depDay == null ? "not scheduled" : "on day $depDay"}');
        }
      }
    }

    // Double-booking: same worker, same day.
    final byWorkerDay = <String, List<String>>{};
    for (final a in _assignments) {
      final key = '${a.worker}:${a.day}';
      byWorkerDay.putIfAbsent(key, () => []).add(a.jobId);
    }
    for (final entry in byWorkerDay.entries) {
      if (entry.value.length > 1) {
        conflicts.add('Double-booking: ${entry.key} → ${entry.value}');
      }
    }

    return conflicts;
  }

  int? _completionDay(String jobId) {
    // Find the latest day this job is assigned (approximation).
    int? latest;
    for (final a in _assignments) {
      if (a.jobId == jobId) {
        if (latest == null || a.day > latest) latest = a.day;
      }
    }
    return latest;
  }

  // -- Disruptions ----------------------------------------------------------

  void injectDisruption(int day, Map<String, Object?> disruption) {
    _disruptions.putIfAbsent(day, () => []).add(disruption);
  }

  List<Map<String, Object?>> getDisruptions(int day) => _disruptions[day] ?? [];
}
