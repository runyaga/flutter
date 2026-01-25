# Milestone: Flutter Providers

**Status:** pending
**Depends on:** 02-logging-io-package

## Objective

Create Riverpod providers to integrate logging into the Flutter app, with
persisted configuration and platform-aware sink initialization.

## Pre-flight Checklist

- [ ] `soliplex_logging` and `soliplex_logging_io` packages exist and pass tests
- [ ] Review `config_provider.dart` for persistence pattern
- [ ] Confirm `path_provider` is available (check pubspec.yaml)

## Files to Create

- `lib/core/logging/log_config.dart`
- `lib/core/logging/logging_provider.dart`
- `lib/core/logging/file_sink_provider.dart` (conditional import barrel)
- `lib/core/logging/file_sink_stub.dart`
- `lib/core/logging/file_sink_io.dart`
- `lib/shared/utils/log_helper.dart`
- `test/core/logging/log_config_test.dart`
- `test/core/logging/logging_provider_test.dart`

## Files to Modify

- `pubspec.yaml` - Add logging package dependencies
- `lib/main.dart` - Initialize logging before runApp

## Web Compatibility Strategy

The `soliplex_logging_io` package uses `dart:io` which is unavailable on Flutter
Web. To avoid compilation failures, we use **conditional imports** to isolate
the `dart:io` dependency:

1. `file_sink_provider.dart` - Barrel file with conditional export
2. `file_sink_stub.dart` - Stub that returns null (used on web)
3. `file_sink_io.dart` - Real implementation using soliplex_logging_io (native)

This pattern ensures the import of `soliplex_logging_io` only occurs on
platforms that support `dart:io`.

**IMPORTANT:** Even though conditional imports control which file is compiled,
the `soliplex_logging_io` package MUST be listed as a dependency in
`pubspec.yaml`. Dart's analysis and compilation require the package to be
declared for the import directive to resolve successfully.

## Changes

### Change 1: Add package dependencies

**File:** `pubspec.yaml`

- [ ] Add `soliplex_logging: path: packages/soliplex_logging`
- [ ] Add `soliplex_logging_io: path: packages/soliplex_logging_io`
- [ ] Verify `path_provider` is present (add if missing)

**Note:** Both packages MUST be listed as dependencies. While `soliplex_logging_io`
is only imported via conditional import in `file_sink_io.dart`, the package
must still be a declared dependency for Dart analysis and compilation to
resolve the import directive. This is a Dart language requirement.

### Change 2: Create LogConfig model

**File:** `lib/core/logging/log_config.dart`

- [ ] Create immutable class with: minimumLevel, fileLoggingEnabled,
  consoleLoggingEnabled
- [ ] Set sensible defaults: LogLevel.info, true, true
- [ ] Implement copyWith method

### Change 3: Create conditional file sink files

**File:** `lib/core/logging/file_sink_provider.dart`

```dart
export 'file_sink_stub.dart'
    if (dart.library.io) 'file_sink_io.dart';
```

**File:** `lib/core/logging/file_sink_stub.dart`

- [ ] Define `createFileSink()` function that returns `Future<LogSink?>`
- [ ] Stub implementation returns `null` (for web platform)
- [ ] Define `getCompressedLogs()` function that returns `Future<Uint8List>`
- [ ] Stub implementation returns empty `Uint8List(0)`

**File:** `lib/core/logging/file_sink_io.dart`

- [ ] Import `soliplex_logging_io` (only compiled on native platforms)
- [ ] Implement `createFileSink()` that:
  - Gets platform-appropriate log directory via `path_provider`
  - Creates and initializes `FileSink`
  - Returns the sink
- [ ] Implement `getCompressedLogs(FileSink sink)` that calls
  `sink.getCompressedLogs()`

### Change 4: Create logging providers

**File:** `lib/core/logging/logging_provider.dart`

- [ ] Import from `file_sink_provider.dart` (conditional import barrel)
- [ ] Create `LogConfigNotifier` extending Notifier<LogConfig>
- [ ] Persist config to SharedPreferences (keys: `log_level`, `file_logging`,
  `console_logging`)
- [ ] Create `logConfigProvider` NotifierProvider
- [ ] Create `memorySinkProvider` that adds MemorySink to LogManager
- [ ] Create `fileSinkProvider` (FutureProvider) that:
  - Calls `createFileSink()` from conditional import
  - Returns null if fileLoggingEnabled is false
  - Adds sink to LogManager if not null
  - Disposes correctly on provider dispose
- [ ] Create `consoleSinkProvider` that adds ConsoleSink when enabled
- [ ] Apply minimumLevel to LogManager when config changes

### Change 5: Create log helper

**File:** `lib/shared/utils/log_helper.dart`

- [ ] Create `getLogger(String name)` convenience function
- [ ] Simply wraps `LogManager.instance.getLogger(name)`

### Change 6: Initialize logging in main

**File:** `lib/main.dart`

- [ ] Create `initializeLogging()` async function
- [ ] Call after `WidgetsFlutterBinding.ensureInitialized()`
- [ ] Before other initialization (config, auth, etc.)
- [ ] Initialize LogManager with console sink (always available)
- [ ] Load persisted log level from SharedPreferences

### Change 7: Write tests

**Files:** `test/core/logging/*.dart`

- [ ] Test LogConfig copyWith
- [ ] Test LogConfigNotifier persists and loads settings
- [ ] Test fileSinkProvider returns null on web (mock conditional import)
- [ ] Test memorySinkProvider adds sink to LogManager
- [ ] Test minimumLevel changes propagate to LogManager

## Platform Log Directory Paths

| Platform | Directory | Notes |
|----------|-----------|-------|
| iOS | `Documents/logs/` | Backed up to iCloud |
| macOS | `Application Support/logs/` | App-specific |
| Android | `Documents/logs/` | Internal storage |
| Linux | `Application Support/logs/` | XDG compliant |
| Windows | `Application Support/logs/` | AppData\Roaming |

Use `getApplicationDocumentsDirectory()` for iOS/Android and
`getApplicationSupportDirectory()` for desktop platforms.

## Success Criteria

- [ ] `dart format --set-exit-if-changed .` passes
- [ ] `dart analyze --fatal-infos` passes
- [ ] `flutter test` passes
- [ ] Log level persists across app restart (verify with integration test or
  manual)
- [ ] Changing log level in settings immediately affects logging output
- [ ] Log files created in correct platform-specific directories
- [ ] **Flutter Web compiles without errors** (no dart:io import leakage)
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
