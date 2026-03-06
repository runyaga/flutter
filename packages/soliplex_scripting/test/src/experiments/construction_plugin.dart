import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Domain-specific host functions for home construction scheduling.
///
/// The LLM doesn't implement scheduling logic — it calls these functions
/// and writes the glue code (branching, looping, reacting to disruptions).
///
/// All state lives in [ConstructionState] which the plugin owns.
/// Functions are registered under the `construction` namespace.
class ConstructionPlugin extends MontyPlugin {
  ConstructionPlugin({required this.state});

  final ConstructionState state;

  @override
  String get namespace => 'construction';

  @override
  String? get systemPromptContext => '''
You have construction scheduling functions available:

- construction_get_jobs() → list of all jobs with deps, trade, outdoor flag
- construction_get_staff() → list of workers with trade and skill level
- construction_get_weather(day) → "rain" or "sunny"
- construction_deps_met(job_id) → true if all dependencies are completed
- construction_is_outdoor(job_id) → true if the job requires outdoor work
- construction_available_workers(day) → list of workers not assigned on that day
- construction_workers_for_trade(trade) → list of workers with that trade
- construction_assign(worker, job_id, day) → assigns worker, returns success/error
- construction_unassign(worker, day) → removes worker assignment for that day
- construction_get_schedule() → current schedule as list of assignments
- construction_get_day_schedule(day) → assignments for a specific day
- construction_detect_conflicts() → list of constraint violations in schedule
- construction_inject_disruption(day, disruption) → simulate a disruption event
- construction_get_disruptions(day) → list of disruptions for that day
- construction_complete_job(job_id) → mark job as done (unlocks dependents)
- construction_job_status(job_id) → "pending", "in_progress", or "completed"
- construction_get_ready_jobs() → list of jobs that are pending AND have all deps met (ready to schedule)
- construction_advance_day(day) → mark all in-progress jobs on that day as completed, returns list of completed job IDs

Use these to build and adjust schedules. You do NOT need to implement
dependency checking, conflict detection, or worker allocation yourself.
Call the functions and react to results.

IMPORTANT: Use construction_get_ready_jobs() to find what can be scheduled
next, rather than iterating all jobs and checking deps yourself.''';

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
          'Assign a worker to a job on a day. Returns {"ok": true} or '
              '{"ok": false, "error": "reason"}. Validates deps, weather, '
              'trade match, and worker availability.',
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
              'Returns the list of job IDs that were completed.',
          [_param('day', HostParamType.integer, 'Day number.')],
          (args) async {
            final day = args['day']! as int;
            return state.advanceDay(day);
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
  List<String> advanceDay(int day) {
    final dayJobs = _assignments
        .where((a) => a.day == day)
        .map((a) => a.jobId)
        .toList()
      ..forEach(_completed.add);
    return dayJobs;
  }

  // -- Mutations ------------------------------------------------------------

  /// Assign a worker to a job on a day. Validates all constraints.
  Map<String, Object?> assign(String workerName, String jobId, int day) {
    final job = findJob(jobId);
    if (job == null) {
      return {'ok': false, 'error': 'Unknown job: $jobId'};
    }

    final worker = staff.where((s) => s.name == workerName).firstOrNull;
    if (worker == null) {
      return {'ok': false, 'error': 'Unknown worker: $workerName'};
    }

    // Trade match.
    if (worker.trade != job.trade) {
      return {
        'ok': false,
        'error': '${worker.name} is a ${worker.trade}, '
            'but ${job.id} needs a ${job.trade}.',
      };
    }

    // Dependencies.
    if (!depsMet(jobId)) {
      final unmet = job.deps.where((d) => !_completed.contains(d)).toList();
      return {
        'ok': false,
        'error': 'Dependencies not met for $jobId: $unmet',
      };
    }

    // Weather.
    if (job.outdoor && getWeather(day) == 'rain') {
      return {
        'ok': false,
        'error': '$jobId is outdoor work and day $day has rain.',
      };
    }

    // Worker availability.
    final busy = _assignments
        .where((a) => a.day == day && a.worker == workerName)
        .isNotEmpty;
    if (busy) {
      return {
        'ok': false,
        'error': '$workerName is already assigned on day $day.',
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
