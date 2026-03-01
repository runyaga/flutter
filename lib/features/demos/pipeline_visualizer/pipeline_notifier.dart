import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soliplex_agent/soliplex_agent.dart';
import 'package:soliplex_client/soliplex_client.dart' show ClientTool;
import 'package:soliplex_frontend/core/providers/api_provider.dart';
import 'package:soliplex_frontend/features/demos/pipeline_visualizer/pipeline_pattern.dart';
import 'package:soliplex_logging/soliplex_logging.dart';
import 'package:soliplex_scripting/soliplex_scripting.dart';

// ---------------------------------------------------------------------------
// Per-node runtime state
// ---------------------------------------------------------------------------

class NodeState {
  const NodeState({
    required this.nodeId,
    this.status = NodeStatus.pending,
    this.input,
    this.output,
    this.streamingOutput,
    this.elapsed,
  });

  final String nodeId;
  final NodeStatus status;
  final String? input;
  final String? output;
  final String? streamingOutput;
  final Duration? elapsed;

  /// Returns streaming text while running, final output otherwise.
  String? get displayOutput => streamingOutput ?? output;

  NodeState copyWith({
    NodeStatus? status,
    String? input,
    String? output,
    String? streamingOutput,
    Duration? elapsed,
  }) {
    return NodeState(
      nodeId: nodeId,
      status: status ?? this.status,
      input: input ?? this.input,
      output: output ?? this.output,
      streamingOutput: streamingOutput ?? this.streamingOutput,
      elapsed: elapsed ?? this.elapsed,
    );
  }
}

// ---------------------------------------------------------------------------
// Pipeline state
// ---------------------------------------------------------------------------

enum PipelineStatus { idle, running, completed, error }

class PipelineState {
  const PipelineState({
    this.status = PipelineStatus.idle,
    this.pattern,
    this.prompt = '',
    this.nodeStates = const {},
    this.selectedNodeId,
    this.error = '',
    this.startedAt,
    this.completedAt,
  });

  final PipelineStatus status;
  final PipelinePattern? pattern;
  final String prompt;
  final Map<String, NodeState> nodeStates;
  final String? selectedNodeId;
  final String error;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isRunning => status == PipelineStatus.running;

  Duration? get elapsed {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  int get completedCount =>
      nodeStates.values.where((n) => n.status == NodeStatus.completed).length;

  int get totalNodes => nodeStates.length;

  NodeState? get selectedNode =>
      selectedNodeId != null ? nodeStates[selectedNodeId] : null;

  PipelineState copyWith({
    PipelineStatus? status,
    PipelinePattern? pattern,
    String? prompt,
    Map<String, NodeState>? nodeStates,
    String? selectedNodeId,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return PipelineState(
      status: status ?? this.status,
      pattern: pattern ?? this.pattern,
      prompt: prompt ?? this.prompt,
      nodeStates: nodeStates ?? this.nodeStates,
      selectedNodeId: selectedNodeId ?? this.selectedNodeId,
      error: error ?? this.error,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

final _log = LogManager.instance.getLogger('PipelineNotifier');

class PipelineNotifier extends Notifier<PipelineState> {
  static const _timeout = Duration(seconds: 120);

  /// Set to `false` to disable live text streaming.
  bool streamingEnabled = true;

  @override
  PipelineState build() => const PipelineState();

  void selectPattern(PipelinePattern pattern) {
    state = PipelineState(pattern: pattern);
  }

  void selectNode(String? nodeId) {
    state = state.copyWith(selectedNodeId: nodeId);
  }

  Future<void> runPipeline(String prompt) async {
    final pattern = state.pattern;
    if (pattern == null || state.isRunning) return;

    _log.info(
      'Running pipeline "${pattern.name}" with prompt: '
      '"${prompt.substring(0, prompt.length.clamp(0, 60))}"',
    );

    final bridgeCache = BridgeCache(limit: 4);
    final hostWiring = HostFunctionWiring(hostApi: FakeHostApi());
    var nodeCounter = 0;

    final runtime = AgentRuntime(
      api: ref.read(apiProvider),
      agUiClient: ref.read(agUiClientProvider),
      toolRegistryResolver: (roomId) async {
        final base = ref.read(toolRegistryProvider);
        final threadKey = (
          serverId: 'pipeline',
          roomId: roomId,
          threadId: 'node-${nodeCounter++}',
        );
        final executor = MontyToolExecutor(
          threadKey: threadKey,
          bridgeCache: bridgeCache,
          hostWiring: hostWiring,
        );
        return base.register(
          ClientTool(
            definition: PythonExecutorTool.definition,
            executor: executor.execute,
          ),
        );
      },
      platform: const NativePlatformConstraints(),
      logger: LogManager.instance.getLogger('PipelineViz'),
    );

    // Initialize all node states to pending.
    final initial = <String, NodeState>{
      for (final node in pattern.nodes) node.id: NodeState(nodeId: node.id),
    };

    state = state.copyWith(
      status: PipelineStatus.running,
      prompt: prompt,
      nodeStates: initial,
      error: '',
      startedAt: DateTime.now(),
    );

    final outputs = <String, String>{};

    try {
      final layers = pattern.executionLayers();

      for (var layerIdx = 0; layerIdx < layers.length; layerIdx++) {
        final layer = layers[layerIdx];
        _log.info(
          'Layer $layerIdx: '
          '${layer.map((n) => n.id).join(", ")}',
        );

        // Build prompts and mark nodes as running.
        final nodePrompts = <String, String>{};
        final updatedStates = Map<String, NodeState>.from(state.nodeStates);

        for (final node in layer) {
          final nodePrompt = _buildPrompt(node, prompt, outputs);
          nodePrompts[node.id] = nodePrompt;
          updatedStates[node.id] = updatedStates[node.id]!.copyWith(
            status: NodeStatus.running,
            input: nodePrompt,
          );
        }
        state = state.copyWith(nodeStates: updatedStates);

        // Spawn all nodes in this layer.
        final sessions = <String, AgentSession>{};
        for (final node in layer) {
          _log.debug(
            '  Spawning ${node.id} (room=${node.roomId})',
          );
          sessions[node.id] = await runtime.spawn(
            roomId: node.roomId,
            prompt: nodePrompts[node.id]!,
            ephemeral: false,
          );
        }

        // Subscribe to text streams for live updates.
        final subs = <StreamSubscription<String>>[];
        if (streamingEnabled) {
          for (final entry in sessions.entries) {
            subs.add(
              entry.value.textStream.listen((text) {
                final updated = Map<String, NodeState>.from(state.nodeStates);
                updated[entry.key] =
                    updated[entry.key]!.copyWith(streamingOutput: text);
                state = state.copyWith(nodeStates: updated);
              }),
            );
          }
        }

        // Wait for all nodes in this layer.
        if (sessions.length == 1) {
          final entry = sessions.entries.first;
          final sw = Stopwatch()..start();
          final result = await entry.value.awaitResult(
            timeout: _timeout,
          );
          sw.stop();
          _processResult(entry.key, result, sw.elapsed, outputs);
        } else {
          final keys = sessions.keys.toList();
          final sessionList = sessions.values.toList();
          final sw = Stopwatch()..start();
          final results = await runtime.waitAll(
            sessionList,
            timeout: _timeout,
          );
          sw.stop();
          for (var i = 0; i < keys.length; i++) {
            _processResult(
              keys[i],
              results[i],
              sw.elapsed,
              outputs,
            );
          }
        }

        // Cancel streaming subscriptions for this layer.
        for (final sub in subs) {
          await sub.cancel();
        }
      }

      state = state.copyWith(
        status: PipelineStatus.completed,
        completedAt: DateTime.now(),
      );
      _log.info(
        'Pipeline complete in ${state.elapsed?.inSeconds}s',
      );
    } on Object catch (e, st) {
      _log.error('Pipeline failed', error: e, stackTrace: st);
      final cleanedStates = Map<String, NodeState>.from(state.nodeStates);
      for (final entry in cleanedStates.entries) {
        if (entry.value.status == NodeStatus.running) {
          cleanedStates[entry.key] = entry.value.copyWith(
            status: NodeStatus.cancelled,
            output: 'Aborted due to pipeline error',
          );
        }
      }
      state = state.copyWith(
        status: PipelineStatus.error,
        error: e.toString(),
        nodeStates: cleanedStates,
        completedAt: DateTime.now(),
      );
    } finally {
      hostWiring.dfRegistry.disposeAll();
      bridgeCache.disposeAll();
    }
  }

  void reset() => state = PipelineState(pattern: state.pattern);

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  void _processResult(
    String nodeId,
    AgentResult result,
    Duration elapsed,
    Map<String, String> outputs,
  ) {
    final updatedStates = Map<String, NodeState>.from(state.nodeStates);

    switch (result) {
      case AgentSuccess(:final output):
        outputs[nodeId] = output;
        // Reconstruct to clear streamingOutput.
        final prev = updatedStates[nodeId]!;
        updatedStates[nodeId] = NodeState(
          nodeId: prev.nodeId,
          status: NodeStatus.completed,
          input: prev.input,
          output: output,
          elapsed: elapsed,
        );
        _log.info(
          '  $nodeId completed (${output.length} chars)',
        );
      case AgentFailure(:final error):
        final prev = updatedStates[nodeId]!;
        updatedStates[nodeId] = NodeState(
          nodeId: prev.nodeId,
          status: NodeStatus.failed,
          input: prev.input,
          output: 'Error: $error',
          elapsed: elapsed,
        );
        _log.error('  $nodeId failed: $error');
        throw Exception('Node $nodeId failed: $error');
      case AgentTimedOut(:final elapsed):
        final prev = updatedStates[nodeId]!;
        updatedStates[nodeId] = NodeState(
          nodeId: prev.nodeId,
          status: NodeStatus.failed,
          input: prev.input,
          output: 'Timed out after ${elapsed.inSeconds}s',
          elapsed: elapsed,
        );
        _log.error('  $nodeId timed out');
        throw Exception(
          'Node $nodeId timed out '
          'after ${elapsed.inSeconds}s',
        );
    }

    state = state.copyWith(nodeStates: updatedStates);
  }

  String _buildPrompt(
    DagNode node,
    String userPrompt,
    Map<String, String> outputs,
  ) {
    if (node.dependsOn.isEmpty) return userPrompt;
    final upstream = node.dependsOn
        .map(
          (id) => '=== $id ===\n${outputs[id] ?? "(pending)"}',
        )
        .join('\n\n');
    return 'Given these inputs:\n\n$upstream\n\n$userPrompt';
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final pipelineProvider = NotifierProvider<PipelineNotifier, PipelineState>(
  PipelineNotifier.new,
);
