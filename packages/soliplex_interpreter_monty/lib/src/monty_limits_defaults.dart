import 'package:dart_monty_platform_interface/dart_monty_platform_interface.dart';

/// Safe default resource limits for Monty execution contexts.
abstract final class MontyLimitsDefaults {
  /// Limits for AI tool-call execution (default 30s).
  static const tool = MontyLimits(
    timeoutMs: 30000,
    memoryBytes: 16 * 1024 * 1024, // 16 MB
    stackDepth: 100,
  );

  /// Limits for user-initiated play-button execution.
  static const playButton = MontyLimits(
    timeoutMs: 30000,
    memoryBytes: 32 * 1024 * 1024, // 32 MB
    stackDepth: 100,
  );

  /// Limits for showcase demos (generous for slow LLM backends).
  static const showcase = MontyLimits(
    timeoutMs: 60000,
    memoryBytes: 32 * 1024 * 1024, // 32 MB
    stackDepth: 100,
  );

  /// Limits for event-loop scripts (long-running, UI-interactive).
  /// No timeout (event loops run indefinitely), standard memory cap.
  static const eventLoop = MontyLimits(
    memoryBytes: 32 * 1024 * 1024, // 32 MB
    stackDepth: 100,
    // No timeoutMs — event loops run indefinitely.
  );
}
