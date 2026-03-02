import 'package:soliplex_agent/soliplex_agent.dart' show AgentApi, HostApi;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/src/df_functions.dart';
import 'package:soliplex_scripting/src/stream_registry.dart';

/// Wires [HostApi] methods to [HostFunction]s and registers them onto a
/// [MontyBridge] via a [HostFunctionRegistry].
///
/// Each category maps Python-callable function names to the corresponding
/// [HostApi] method:
///
/// | Category | Python name    | HostApi method       |
/// |----------|---------------|----------------------|
/// | df       | `df_*` (37)   | via DfRegistry       |
/// | chart    | `chart_create`| `registerChart`      |
/// | platform | `host_invoke` | `invoke`             |
/// | streams  | `stream_*`(3) | via StreamRegistry   |
class HostFunctionWiring {
  HostFunctionWiring({
    required HostApi hostApi,
    AgentApi? agentApi,
    DfRegistry? dfRegistry,
    StreamRegistry? streamRegistry,
  })  : _hostApi = hostApi,
        _agentApi = agentApi,
        _dfRegistry = dfRegistry ?? DfRegistry(),
        _streamRegistry = streamRegistry;

  final HostApi _hostApi;
  final AgentApi? _agentApi;
  final DfRegistry _dfRegistry;
  final StreamRegistry? _streamRegistry;

  /// Registers all host function categories (plus introspection builtins)
  /// onto [bridge].
  void registerOnto(MontyBridge bridge) {
    final registry = HostFunctionRegistry()
      ..addCategory('df', buildDfFunctions(_dfRegistry))
      ..addCategory('chart', _chartFunctions())
      ..addCategory('platform', _platformFunctions());
    if (_streamRegistry != null) {
      registry.addCategory('streams', _streamFunctions());
    }
    if (_agentApi != null) {
      registry.addCategory('agent', _agentFunctions());
    }
    registry.registerAllOnto(bridge);
  }

  List<HostFunction> _chartFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'chart_create',
            description: 'Create a chart from a configuration map.',
            params: [
              HostParam(
                name: 'config',
                type: HostParamType.map,
                description: 'Chart configuration.',
              ),
            ],
          ),
          handler: (args) async {
            final raw = args['config'];
            if (raw is! Map) {
              throw ArgumentError.value(raw, 'config', 'Expected a map.');
            }
            return _hostApi.registerChart(Map<String, Object?>.from(raw));
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'chart_update',
            description: 'Update an existing chart with a new configuration.',
            params: [
              HostParam(
                name: 'chart_id',
                type: HostParamType.integer,
                description: 'Chart handle returned by chart_create.',
              ),
              HostParam(
                name: 'config',
                type: HostParamType.map,
                description: 'New chart configuration.',
              ),
            ],
          ),
          handler: (args) async {
            final chartId = args['chart_id']! as int;
            final raw = args['config'];
            if (raw is! Map) {
              throw ArgumentError.value(raw, 'config', 'Expected a map.');
            }
            return _hostApi.updateChart(
              chartId,
              Map<String, Object?>.from(raw),
            );
          },
        ),
      ];

  List<HostFunction> _platformFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'host_invoke',
            description: 'Invoke a named host operation.',
            params: [
              HostParam(
                name: 'name',
                type: HostParamType.string,
                description: 'Namespaced operation name.',
              ),
              HostParam(
                name: 'args',
                type: HostParamType.map,
                description: 'Arguments for the operation.',
              ),
            ],
          ),
          handler: (args) async {
            final name = args['name'];
            if (name is! String) {
              throw ArgumentError.value(name, 'name', 'Expected a string.');
            }
            final rawArgs = args['args'];
            if (rawArgs is! Map) {
              throw ArgumentError.value(rawArgs, 'args', 'Expected a map.');
            }
            return _hostApi.invoke(name, Map<String, Object?>.from(rawArgs));
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'sleep',
            description: 'Pause execution for a number of milliseconds.',
            params: [
              HostParam(
                name: 'ms',
                type: HostParamType.integer,
                description: 'Duration in milliseconds.',
              ),
            ],
          ),
          handler: (args) async {
            final ms = args['ms']! as int;
            await Future<void>.delayed(Duration(milliseconds: ms));
            return null;
          },
        ),
      ];

  List<HostFunction> _streamFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'stream_subscribe',
            description: 'Subscribe to a named Dart stream.',
            params: [
              HostParam(
                name: 'name',
                type: HostParamType.string,
                description: 'Registered stream name.',
              ),
            ],
          ),
          handler: (args) async {
            final name = args['name'];
            if (name is! String) {
              throw ArgumentError.value(name, 'name', 'Expected a string.');
            }
            return _streamRegistry!.subscribe(name);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'stream_next',
            description: 'Pull the next value from a stream subscription. '
                'Returns null when the stream is done.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Subscription handle from stream_subscribe.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = args['handle'];
            if (handle is! int) {
              throw ArgumentError.value(
                handle,
                'handle',
                'Expected an integer.',
              );
            }
            return _streamRegistry!.next(handle);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'stream_close',
            description: 'Close a stream subscription early.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Subscription handle from stream_subscribe.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = args['handle'];
            if (handle is! int) {
              throw ArgumentError.value(
                handle,
                'handle',
                'Expected an integer.',
              );
            }
            return _streamRegistry!.close(handle);
          },
        ),
      ];

  List<HostFunction> _agentFunctions() => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'spawn_agent',
            description: 'Spawn an L2 sub-agent in a room.',
            params: [
              HostParam(
                name: 'room',
                type: HostParamType.string,
                description: 'Room ID to spawn the agent in.',
              ),
              HostParam(
                name: 'prompt',
                type: HostParamType.string,
                description: 'Prompt for the agent.',
              ),
            ],
          ),
          handler: (args) async {
            final room = args['room']! as String;
            final prompt = args['prompt']! as String;
            return _agentApi!.spawnAgent(room, prompt);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'wait_all',
            description: 'Wait for all agents to complete.',
            params: [
              HostParam(
                name: 'handles',
                type: HostParamType.list,
                description: 'List of agent handles.',
              ),
            ],
          ),
          handler: (args) async {
            final raw = args['handles']! as List<Object?>;
            final handles = List<int>.from(raw);
            return _agentApi!.waitAll(handles);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'get_result',
            description: 'Get the result of a completed agent.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Agent handle.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = args['handle']! as int;
            return _agentApi!.getResult(handle);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'ask_llm',
            description: 'Spawn an agent and return its result in one call.',
            params: [
              HostParam(
                name: 'prompt',
                type: HostParamType.string,
                description: 'Prompt for the agent.',
              ),
              HostParam(
                name: 'room',
                type: HostParamType.string,
                isRequired: false,
                defaultValue: 'general',
                description: 'Room ID (defaults to "general").',
              ),
            ],
          ),
          handler: (args) async {
            final prompt = args['prompt']! as String;
            final room = args['room']! as String;
            final api = _agentApi!;
            final handle = await api.spawnAgent(room, prompt);
            return api.getResult(handle);
          },
        ),
      ];
}
