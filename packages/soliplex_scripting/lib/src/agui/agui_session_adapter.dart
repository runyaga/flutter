import 'dart:async';

import 'package:signals_core/signals_core.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/src/ag_ui_bridge_adapter.dart';
import 'package:soliplex_scripting/src/agui/activity_snapshot_mapper.dart';
import 'package:soliplex_scripting/src/agui/agui_http_observer.dart';
import 'package:soliplex_scripting/src/agui/state_signal_tracker.dart';

/// A signal + key pair for plugin state observation.
///
/// Pass one per plugin that exposes a reactive state signal. The [key]
/// becomes the JSON path segment under `plugin.*` in ag-ui state frames,
/// e.g. `'event_loop'` → `plugin.event_loop`.
class StatefulPluginObservation {
  const StatefulPluginObservation({
    required this.key,
    required this.signal,
  });

  final String key;
  final ReadonlySignal<Object?> signal;
}

/// Merges all Monty + Soliplex observables into a single ag-ui event stream.
///
/// Sources:
/// - `Stream<BridgeEvent>` — 1:1 base events + ACTIVITY_SNAPSHOT custom
///   events.
/// - `AgentSession.runState` — STATE_SNAPSHOT + STATE_DELTA at `agent.run`.
/// - `AgentSession.sessionState` — STATE_SNAPSHOT + STATE_DELTA at
///   `agent.session`.
/// - `AgentSession.lastExecutionEvent` — `execution.*` custom events.
/// - `pluginStateSources` — STATE_SNAPSHOT + STATE_DELTA at `plugin.<key>`.
/// - HTTP traffic via [observer] — `http.*` custom events.
///
/// Register [observer] on your `ObservableHttpClient` once per session.
/// Call [close] when the session ends.
class AgUiSessionAdapter {
  AgUiSessionAdapter({
    required String threadId,
    required String runId,
    required Stream<BridgeEvent> bridgeEvents,
    required AgentSession agentSession,
    List<StatefulPluginObservation> pluginStateSources = const [],
  })  : observer = AgUiHttpObserver(),
        _controller = StreamController<BaseEvent>.broadcast() {
    final bridgeAdapter = AgUiBridgeAdapter(threadId: threadId, runId: runId);
    final activityMapper = ActivitySnapshotMapper(runId: runId);

    // Bridge events → base events + activity snapshots.
    _subs.add(
      bridgeEvents.listen((event) {
        if (_controller.isClosed) return;
        _controller.add(bridgeAdapter.mapEvent(event));
        final activity = activityMapper.map(event);
        if (activity != null) _controller.add(activity);
      }),
    );

    // agent.run signal → state frames.
    final runStateStr = computed(
      () => agentSession.runState.value.runtimeType.toString(),
    );
    _computed.add(runStateStr);
    _trackers.add(
      StateSignalTracker<String>(
        key: 'agent.run',
        signal: runStateStr,
        emit: _controller.add,
      ),
    );

    // agent.session signal → state frames.
    final sessionStateStr = computed(
      () => agentSession.sessionState.value.name,
    );
    _computed.add(sessionStateStr);
    _trackers.add(
      StateSignalTracker<String>(
        key: 'agent.session',
        signal: sessionStateStr,
        emit: _controller.add,
      ),
    );

    // lastExecutionEvent → execution.* custom events.
    _effectCleanups.add(
      effect(() {
        final execEvent = agentSession.lastExecutionEvent.value;
        if (execEvent == null || _controller.isClosed) return;
        final custom = _mapExecutionEvent(execEvent);
        if (custom != null) _controller.add(custom);
      }),
    );

    // Plugin signals → state frames.
    for (final src in pluginStateSources) {
      _trackers.add(
        StateSignalTracker<Object?>(
          key: 'plugin.${src.key}',
          signal: src.signal,
          emit: _controller.add,
        ),
      );
    }

    // HTTP events.
    _subs.add(observer.events.listen(_controller.add));
  }

  final AgUiHttpObserver observer;
  final StreamController<BaseEvent> _controller;
  final List<StreamSubscription<dynamic>> _subs = [];
  final List<StateSignalTracker<dynamic>> _trackers = [];
  final List<EffectCleanup> _effectCleanups = [];
  final List<Computed<dynamic>> _computed = [];

  Stream<BaseEvent> get events => _controller.stream;

  static CustomEvent? _mapExecutionEvent(ExecutionEvent event) =>
      switch (event) {
        TextDelta(:final delta) => CustomEvent(
            name: 'execution.text_delta',
            value: {'delta': delta},
          ),
        ThinkingStarted() => const CustomEvent(
            name: 'execution.thinking_started',
            value: null,
          ),
        ThinkingContent(:final delta) => CustomEvent(
            name: 'execution.thinking_content',
            value: {'delta': delta},
          ),
        ServerToolCallStarted(
          :final toolName,
          :final toolCallId,
        ) =>
          CustomEvent(
            name: 'execution.server_tool_call_started',
            value: {'toolName': toolName, 'toolCallId': toolCallId},
          ),
        ServerToolCallCompleted(
          :final toolCallId,
          :final result,
        ) =>
          CustomEvent(
            name: 'execution.server_tool_call_completed',
            value: {'toolCallId': toolCallId, 'result': result},
          ),
        ClientToolExecuting(
          :final toolName,
          :final toolCallId,
        ) =>
          CustomEvent(
            name: 'execution.client_tool_executing',
            value: {'toolName': toolName, 'toolCallId': toolCallId},
          ),
        ClientToolCompleted(
          :final toolCallId,
          :final result,
          :final status,
        ) =>
          CustomEvent(
            name: 'execution.client_tool_completed',
            value: {
              'toolCallId': toolCallId,
              'result': result,
              'status': status.name,
            },
          ),
        RunCompleted() =>
          const CustomEvent(name: 'execution.run_completed', value: null),
        RunFailed(:final error) => CustomEvent(
            name: 'execution.run_failed',
            value: {'error': error},
          ),
        RunCancelled() =>
          const CustomEvent(name: 'execution.run_cancelled', value: null),
        StateUpdated() => null,
        StepProgress(:final stepName) => CustomEvent(
            name: 'execution.step_progress',
            value: {'stepName': stepName},
          ),
        AwaitingApproval(
          :final toolCallId,
          :final toolName,
          :final rationale,
        ) =>
          CustomEvent(
            name: 'execution.awaiting_approval',
            value: {
              'toolCallId': toolCallId,
              'toolName': toolName,
              'rationale': rationale,
            },
          ),
        CustomExecutionEvent(:final type, :final payload) => CustomEvent(
            name: 'execution.custom.$type',
            value: payload,
          ),
      };

  Future<void> close() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    for (final tracker in _trackers) {
      tracker.dispose();
    }
    for (final cleanup in _effectCleanups) {
      cleanup();
    }
    for (final comp in _computed) {
      comp.dispose();
    }
    observer.dispose();
    await _controller.close();
  }
}
