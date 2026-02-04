# Logging Implementation Plan

This plan covers Milestones 01 and 02 of the central logging architecture.
Claude acts as orchestrator, delegating implementation to Codex and review to Gemini.

## Branch Strategy

| Milestone | Branch | Base |
|-----------|--------|------|
| 01-essential-logging-api | `logging-slice-1` | `main` |
| 02-api-documentation | `logging-slice-2` | `logging-slice-1` |

## Tool Configuration

### Codex

- **Model:** `gpt-5.2`
- **Timeout:** 10 minutes
- **Sandbox:** `workspace-write`
- **Approval policy:** `on-failure`

### Gemini

- **Model:** `gemini-3-pro-preview`
- **Tool:** `mcp__gemini__read_files`
- **Requirement:** Pass ALL file paths (both `.md` and `.dart`) as absolute paths
- **File limit:** 15 files per call (batch if needed)

---

## Milestone 01: Essential Logging API

**Spec:** `docs/planning/logging/01-essential-logging-api.md`
**Branch:** `logging-slice-1`

### Task 1.1: Create branch

```
git checkout -b logging-slice-1 main
```

### Task 1.2: Create package structure (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Create the soliplex_logging package structure. Read docs/planning/logging/01-essential-logging-api.md for the full spec. Create these files:\n\n1. packages/soliplex_logging/pubspec.yaml - SDK ^3.6.0, meta ^1.9.0, dev deps test and very_good_analysis\n2. packages/soliplex_logging/analysis_options.yaml - include very_good_analysis\n3. packages/soliplex_logging/lib/soliplex_logging.dart - barrel export\n4. packages/soliplex_logging/lib/src/log_level.dart - enum with trace(0), debug(100), info(200), warning(300), error(400), fatal(500)\n5. packages/soliplex_logging/lib/src/log_record.dart - immutable class with level, message, timestamp, loggerName, error, stackTrace, spanId, traceId\n6. packages/soliplex_logging/lib/src/log_sink.dart - abstract interface\n7. packages/soliplex_logging/lib/src/sinks/console_sink.dart - implementation using dart:developer\n8. packages/soliplex_logging/lib/src/logger.dart - facade class\n9. packages/soliplex_logging/lib/src/log_manager.dart - singleton\n\nRun dart format and dart analyze after creating files.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 1.3: Write package tests (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Write unit tests for soliplex_logging package. Read docs/planning/logging/01-essential-logging-api.md for requirements. Create:\n\n1. packages/soliplex_logging/test/log_level_test.dart - test comparisons\n2. packages/soliplex_logging/test/log_record_test.dart - test creation with span fields\n3. packages/soliplex_logging/test/console_sink_test.dart - test write behavior\n4. packages/soliplex_logging/test/logger_test.dart - test level filtering and span field passing\n5. packages/soliplex_logging/test/log_manager_test.dart - test singleton, sink management\n\nRun dart test packages/soliplex_logging to verify all pass.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 1.4: Create app integration files (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Create Flutter app integration for soliplex_logging. Read docs/planning/logging/01-essential-logging-api.md for the full spec.\n\n1. Add soliplex_logging path dependency to pubspec.yaml\n2. Create lib/core/logging/loggers.dart - abstract final class Loggers with static fields: auth, http, activeRun, chat, room, router, quiz, config, ui\n3. Create lib/core/logging/log_config.dart - immutable LogConfig class with minimumLevel, consoleLoggingEnabled, copyWith, defaultConfig\n4. Create lib/core/logging/logging_provider.dart - LogConfigNotifier (AsyncNotifier), logConfigProvider, consoleSinkProvider with keepAlive and proper disposal\n\nRun flutter analyze to verify no issues.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 1.5: Write app integration tests (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Write tests for logging app integration. Read docs/planning/logging/01-essential-logging-api.md.\n\nCreate:\n1. test/core/logging/log_config_test.dart - test copyWith, defaultConfig\n2. test/core/logging/logging_provider_test.dart - test provider behavior, default while loading\n\nRun flutter test test/core/logging/ to verify.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 1.6: Validation checks

**Action:** Run these commands and verify all pass

```bash
dart format --set-exit-if-changed packages/soliplex_logging
dart analyze --fatal-infos packages/soliplex_logging
dart test packages/soliplex_logging
flutter analyze --fatal-infos
flutter test test/core/logging/
```

### Task 1.7: Gemini Review

**Action:** Use `mcp__gemini__read_files` with model `gemini-3-pro-preview`

**Files to pass (absolute paths):**

```
/Users/runyaga/dev/soliplex-flutter-logging/docs/planning/logging/01-essential-logging-api.md
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/pubspec.yaml
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/soliplex_logging.dart
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/src/log_level.dart
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/src/log_record.dart
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/src/log_sink.dart
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/src/sinks/console_sink.dart
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/src/logger.dart
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/src/log_manager.dart
/Users/runyaga/dev/soliplex-flutter-logging/lib/core/logging/loggers.dart
/Users/runyaga/dev/soliplex-flutter-logging/lib/core/logging/log_config.dart
/Users/runyaga/dev/soliplex-flutter-logging/lib/core/logging/logging_provider.dart
```

**Prompt:** "Review this logging implementation against the spec. Check: 1) Type-safe Loggers class, 2) Span-ready LogRecord with spanId/traceId, 3) Pure Dart (no Flutter imports in package), 4) Proper sink lifecycle in providers. Report any issues."

### Task 1.8: Codex Review

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Review the soliplex_logging implementation against docs/planning/logging/01-essential-logging-api.md. Check:\n1. Type-safe Loggers.x API (not string-based)\n2. LogRecord has spanId and traceId fields\n3. Package is pure Dart (no Flutter, no dart:io)\n4. consoleSinkProvider uses keepAlive and proper disposal\n5. No duplicate sink initialization\n6. All tests pass\n\nReport PASS or list issues to fix.",
  "model": "gpt-5.2",
  "sandbox": "read-only",
  "approval-policy": "on-failure"
}
```

### Task 1.9: Commit and push

```bash
git add packages/soliplex_logging/ lib/core/logging/ test/core/logging/ pubspec.yaml
git commit -m "feat(logging): implement essential logging API (M01)

- Add soliplex_logging pure Dart package
- Type-safe Loggers class with static fields
- Span-ready LogRecord with spanId/traceId
- ConsoleSink using dart:developer
- LogConfigNotifier with SharedPreferences persistence
- consoleSinkProvider with proper lifecycle management"

git push -u origin logging-slice-1
```

---

## Milestone 02: API Documentation

**Spec:** `docs/planning/logging/02-api-documentation.md`
**Branch:** `logging-slice-2`

### Task 2.1: Create branch

```bash
git checkout -b logging-slice-2 logging-slice-1
```

### Task 2.2: Create package README (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Create the README for soliplex_logging package. Read docs/planning/logging/02-api-documentation.md for requirements.\n\nCreate packages/soliplex_logging/README.md with:\n1. Package description (1-2 sentences)\n2. Installation instructions\n3. Quick start example showing raw LogManager API\n4. Note about type-safe Loggers.x usage in apps\n5. LogLevel reference table\n6. API reference for LogLevel, LogRecord (with span fields), LogSink, ConsoleSink, Logger, LogManager\n\nRun npx markdownlint-cli packages/soliplex_logging/README.md to verify.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 2.3: Create quickstart guide (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Create the logging quickstart guide. Read docs/planning/logging/02-api-documentation.md for requirements.\n\nCreate docs/logging-quickstart.md with:\n1. Overview of logging architecture\n2. Type-safe Loggers.x usage examples\n3. List of available loggers (auth, http, activeRun, chat, room, router, quiz, config, ui)\n4. How to add a new logger\n5. Log level guidelines with examples table\n6. Span context for telemetry (future feature note)\n\nRun npx markdownlint-cli docs/logging-quickstart.md to verify.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 2.4: Add dartdoc comments (Codex)

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Add dartdoc comments to all public APIs in soliplex_logging package. Read docs/planning/logging/02-api-documentation.md.\n\nUpdate these files with dartdoc:\n1. packages/soliplex_logging/lib/src/log_level.dart - document each level's purpose\n2. packages/soliplex_logging/lib/src/log_record.dart - document all fields including spanId/traceId\n3. packages/soliplex_logging/lib/src/log_sink.dart - document interface contract\n4. packages/soliplex_logging/lib/src/sinks/console_sink.dart - document configuration\n5. packages/soliplex_logging/lib/src/logger.dart - document each method\n6. packages/soliplex_logging/lib/src/log_manager.dart - document singleton usage\n\nRun dart doc packages/soliplex_logging to verify no warnings.",
  "model": "gpt-5.2",
  "sandbox": "workspace-write",
  "approval-policy": "on-failure"
}
```

### Task 2.5: Validation checks

**Action:** Run these commands and verify all pass

```bash
npx markdownlint-cli packages/soliplex_logging/README.md
npx markdownlint-cli docs/logging-quickstart.md
dart doc packages/soliplex_logging
dart analyze --fatal-infos packages/soliplex_logging
```

### Task 2.6: Gemini Review

**Action:** Use `mcp__gemini__read_files` with model `gemini-3-pro-preview`

**Files to pass (absolute paths):**

```
/Users/runyaga/dev/soliplex-flutter-logging/docs/planning/logging/02-api-documentation.md
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/README.md
/Users/runyaga/dev/soliplex-flutter-logging/docs/logging-quickstart.md
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/src/log_level.dart
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/src/log_record.dart
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/src/log_sink.dart
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/src/sinks/console_sink.dart
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/src/logger.dart
/Users/runyaga/dev/soliplex-flutter-logging/packages/soliplex_logging/lib/src/log_manager.dart
/Users/runyaga/dev/soliplex-flutter-logging/lib/core/logging/loggers.dart
```

**Prompt:** "Review this documentation against the spec. Check: 1) README has both raw API and type-safe Loggers.x examples, 2) Quickstart covers all loggers, 3) All public APIs have dartdoc, 4) Log level guidelines are clear. Report any issues."

### Task 2.7: Codex Review

**Action:** Use `mcp__codex__codex` with timeout 10 minutes

```json
{
  "prompt": "Review the logging documentation against docs/planning/logging/02-api-documentation.md. Check:\n1. packages/soliplex_logging/README.md exists and is complete\n2. docs/logging-quickstart.md exists with Loggers.x usage guide\n3. All public APIs have dartdoc comments\n4. dart doc runs without errors\n5. Markdown linting passes\n\nReport PASS or list issues to fix.",
  "model": "gpt-5.2",
  "sandbox": "read-only",
  "approval-policy": "on-failure"
}
```

### Task 2.8: Commit and push

```bash
git add packages/soliplex_logging/README.md docs/logging-quickstart.md packages/soliplex_logging/lib/
git commit -m "docs(logging): add API documentation (M02)

- Package README with installation and quick start
- Quickstart guide with type-safe Loggers.x usage
- Dartdoc comments on all public APIs
- Log level guidelines and examples"

git push -u origin logging-slice-2
```

---

## Completion Checklist

### Milestone 01

- [ ] Branch `logging-slice-1` created from `main`
- [ ] Package structure created (Task 1.2)
- [ ] Package tests written and passing (Task 1.3)
- [ ] App integration files created (Task 1.4)
- [ ] App integration tests passing (Task 1.5)
- [ ] Validation checks pass (Task 1.6)
- [ ] Gemini review: PASS (Task 1.7)
- [ ] Codex review: PASS (Task 1.8)
- [ ] Committed and pushed (Task 1.9)

### Milestone 02

- [ ] Branch `logging-slice-2` created from `logging-slice-1`
- [ ] Package README created (Task 2.2)
- [ ] Quickstart guide created (Task 2.3)
- [ ] Dartdoc comments added (Task 2.4)
- [ ] Validation checks pass (Task 2.5)
- [ ] Gemini review: PASS (Task 2.6)
- [ ] Codex review: PASS (Task 2.7)
- [ ] Committed and pushed (Task 2.8)
