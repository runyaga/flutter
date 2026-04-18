/// Bridge Monty sandboxed Python interpreter into Soliplex (pure Dart).
library;

// Re-export bridge infrastructure from dart_monty_bridge.
export 'package:dart_monty/dart_monty_bridge.dart'
    show
        BridgeEvent,
        BridgeEventLoopResumed,
        BridgeEventLoopWaiting,
        BridgeOsCallResult,
        BridgeOsCallStart,
        BridgeRunError,
        BridgeRunFinished,
        BridgeRunStarted,
        BridgeStepFinished,
        BridgeStepStarted,
        BridgeToolCallArgs,
        BridgeToolCallEnd,
        BridgeToolCallResult,
        BridgeToolCallStart,
        BridgeUiRendered,
        DefaultMontyBridge,
        EventLoopBridge,
        HostFunction,
        HostFunctionHandler,
        HostFunctionSchema,
        HostParam,
        HostParamType,
        MontyBridge,
        MontyPlugin;

// Soliplex-only types.
export 'src/bridge/tool_definition_converter.dart';
export 'src/console_event.dart';
export 'src/execution_result.dart';
export 'src/input_variable.dart';
export 'src/monty_execution_service.dart';
export 'src/monty_limits_defaults.dart';
export 'src/schema_executor.dart';
