import 'dart:async';

import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart'
    show MontyLimits, MontyPlatform;
import 'package:soliplex_agent/soliplex_agent.dart'
    show AgentApi, BlackboardApi, FormApi, HostApi, ScriptEnvironmentFactory;
import 'package:soliplex_client/soliplex_client.dart' show SoliplexHttpClient;
import 'package:soliplex_dataframe/soliplex_dataframe.dart';
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';
import 'package:soliplex_scripting/src/host_function_wiring.dart';
import 'package:soliplex_scripting/src/monty_script_environment.dart';
import 'package:soliplex_scripting/src/stream_registry.dart';

/// Factory that creates a fresh [MontyPlatform] for each session.
typedef MontyPlatformFactory = Future<MontyPlatform> Function();

/// Creates a [ScriptEnvironmentFactory] that produces session-scoped
/// [MontyScriptEnvironment] instances.
///
/// Each invocation of the returned factory creates a fresh bridge,
/// registers host functions once, and returns an environment that
/// disposes everything when the owning session dies.
///
/// When [platformFactory] is provided, each session gets its own
/// [MontyPlatform] instance, enabling concurrent Monty execution
/// across sessions (e.g. parent + child agents). Without it, the
/// bridge falls back to the global [MontyPlatform.instance] singleton.
///
/// ```dart
/// final factory = createMontyScriptEnvironmentFactory(
///   hostApi: myHostApi,
///   agentApi: myAgentApi,
///   platformFactory: () async => MontyFfi(bindings: NativeBindingsFfi()),
/// );
/// final runtime = AgentRuntime(
///   // ...
///   scriptEnvironmentFactory: factory,
/// );
/// ```
ScriptEnvironmentFactory createMontyScriptEnvironmentFactory({
  required HostApi hostApi,
  AgentApi? agentApi,
  BlackboardApi? blackboardApi,
  SoliplexHttpClient? httpClient,
  String? Function()? getAuthToken,
  FormApi? formApi,
  List<HostFunction>? extraFunctions,
  MontyPlatformFactory? platformFactory,
  MontyLimits? limits,
  Duration executionTimeout = const Duration(seconds: 30),
}) {
  return () async {
    final dfRegistry = DfRegistry();
    final streamRegistry = StreamRegistry();
    final platform = platformFactory != null ? await platformFactory() : null;
    final bridge = DefaultMontyBridge(
      platform: platform,
      useFutures: false,
      limits: limits ?? MontyLimitsDefaults.tool,
    );

    // Register IsolatePlugin if a platform factory is provided.
    IsolatePlugin? isolatePlugin;
    if (platformFactory != null) {
      isolatePlugin = IsolatePlugin(platformFactory: platformFactory);
      isolatePlugin.functions.forEach(bridge.register);
    }

    try {
      HostFunctionWiring(
        hostApi: hostApi,
        agentApi: agentApi,
        blackboardApi: blackboardApi,
        httpClient: httpClient,
        getAuthToken: getAuthToken,
        dfRegistry: dfRegistry,
        streamRegistry: streamRegistry,
        formApi: formApi,
        extraFunctions: extraFunctions,
      ).registerOnto(bridge);
    } on Object {
      bridge.dispose();
      if (platform != null) unawaited(platform.dispose());
      rethrow;
    }
    return MontyScriptEnvironment(
      bridge: bridge,
      ownedPlatform: platform,
      dfRegistry: dfRegistry,
      streamRegistry: streamRegistry,
      executionTimeout: executionTimeout,
      isolatePlugin: isolatePlugin,
    );
  };
}
