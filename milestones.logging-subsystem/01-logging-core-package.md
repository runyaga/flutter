# Milestone: Logging Core Package

**Status:** pending
**Depends on:** none

## Objective

Create the pure Dart `soliplex_logging` package with core logging infrastructure:
LogLevel enum, LogRecord class, LogSink interface, ConsoleSink, MemorySink,
Logger facade, and LogManager singleton.

## Pre-flight Checklist

- [ ] Confirm `packages/` directory exists
- [ ] Review existing package structure (`soliplex_client`) for conventions

## Files to Create

- `packages/soliplex_logging/pubspec.yaml`
- `packages/soliplex_logging/analysis_options.yaml`
- `packages/soliplex_logging/lib/soliplex_logging.dart`
- `packages/soliplex_logging/lib/src/log_level.dart`
- `packages/soliplex_logging/lib/src/log_record.dart`
- `packages/soliplex_logging/lib/src/log_formatter.dart`
- `packages/soliplex_logging/lib/src/log_sink.dart`
- `packages/soliplex_logging/lib/src/sinks/console_sink.dart`
- `packages/soliplex_logging/lib/src/sinks/memory_sink.dart`
- `packages/soliplex_logging/lib/src/logger.dart`
- `packages/soliplex_logging/lib/src/log_manager.dart`
- `packages/soliplex_logging/test/log_level_test.dart`
- `packages/soliplex_logging/test/log_record_test.dart`
- `packages/soliplex_logging/test/memory_sink_test.dart`
- `packages/soliplex_logging/test/console_sink_test.dart`
- `packages/soliplex_logging/test/logger_test.dart`
- `packages/soliplex_logging/test/log_manager_test.dart`

## Changes

### Change 1: Create package structure

**File:** `packages/soliplex_logging/pubspec.yaml`

- [ ] Create pubspec with name `soliplex_logging`
- [ ] Set SDK constraint `^3.6.0`
- [ ] Add `meta: ^1.9.0` dependency (per spec)
- [ ] Add dev_dependencies:
  - `test: ^1.24.0`
  - `very_good_analysis: ^7.0.0` (per spec)
- [ ] No Flutter dependencies (pure Dart)

### Change 2: Implement LogLevel enum

**File:** `packages/soliplex_logging/lib/src/log_level.dart`

- [ ] Create enum with values: trace(0), debug(100), info(200), warning(300),
  error(400), fatal(500)
- [ ] Add `value` and `name` properties
- [ ] Implement comparison operators (`>=`, `<`)

### Change 3: Implement LogRecord class

**File:** `packages/soliplex_logging/lib/src/log_record.dart`

- [ ] Create immutable class with: level, message, timestamp, loggerName,
  error?, stackTrace?
- [ ] Implement `toJson()` serialization
- [ ] Implement `fromJson()` deserialization

### Change 4: Implement LogSink interface

**File:** `packages/soliplex_logging/lib/src/log_sink.dart`

- [ ] Define abstract interface with: `write(LogRecord)`, `flush()`, `close()`

### Change 5: Implement LogFormatter

**File:** `packages/soliplex_logging/lib/src/log_formatter.dart`

- [ ] Create interface for formatting LogRecord to String
- [ ] Implement default formatter: `[LEVEL] loggerName: message`

### Change 6: Implement ConsoleSink

**File:** `packages/soliplex_logging/lib/src/sinks/console_sink.dart`

- [ ] Implement LogSink using `dart:developer` `log()` function for output
- [ ] **Spec Divergence:** Use `dart:developer log()` instead of `debugPrint()`.
  This is a pure Dart package with no Flutter dependency. The `debugPrint()`
  function requires Flutter foundation, violating the pure Dart requirement
  stated in the spec ("No dependencies beyond meta"). `dart:developer log()` is
  the standard pure Dart console output mechanism. See PLAN.md "Spec
  Divergences" for full rationale.
- [ ] Accept optional LogFormatter
- [ ] Add `enabled` flag for conditional output

### Change 7: Implement MemorySink

**File:** `packages/soliplex_logging/lib/src/sinks/memory_sink.dart`

- [ ] Implement circular buffer with configurable `maxRecords` (default 2000)
- [ ] Expose `records` as unmodifiable list
- [ ] Implement `clear()` method
- [ ] Remove oldest entry when buffer full

### Change 8: Implement Logger facade

**File:** `packages/soliplex_logging/lib/src/logger.dart`

- [ ] Create class with named constructor `Logger._(name, manager)`
- [ ] Implement level methods: trace, debug, info, warning, error, fatal
- [ ] Error/warning/fatal accept optional `error` and `stackTrace` params
- [ ] Filter logs below `manager.minimumLevel`

### Change 9: Implement LogManager singleton

**File:** `packages/soliplex_logging/lib/src/log_manager.dart`

- [ ] Create singleton with `LogManager.instance`
- [ ] Manage list of sinks with `addSink`, `removeSink`
- [ ] Expose `minimumLevel` getter/setter
- [ ] Implement `getLogger(name)` returning cached Logger instances
- [ ] Implement `emit(LogRecord)` to write to all sinks
- [ ] Implement `flush()` and `close()` for cleanup

### Change 10: Create barrel export

**File:** `packages/soliplex_logging/lib/soliplex_logging.dart`

- [ ] Export all public APIs: LogLevel, LogRecord, LogSink, LogFormatter,
  ConsoleSink, MemorySink, Logger, LogManager

### Change 11: Write unit tests

**Files:** `packages/soliplex_logging/test/*.dart`

- [ ] Test LogLevel comparisons
- [ ] Test LogRecord serialization round-trip
- [ ] Test MemorySink circular buffer behavior
- [ ] Test Logger respects minimum level
- [ ] Test LogManager singleton behavior
- [ ] Test multiple sinks receive records

## Success Criteria

- [ ] `dart format --set-exit-if-changed .` passes in package directory
- [ ] `dart analyze --fatal-infos` passes in package directory
- [ ] `dart test` passes in package directory
- [ ] Test coverage ≥85%
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
