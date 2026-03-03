# Soliplex Packages

This directory contains 12 self-contained packages that make up the Soliplex
monorepo. Each package has its own `pubspec.yaml`, test suite, and README.

## Dependency Graph

```text
soliplex_logging           (leaf — pure Dart)
soliplex_schema            (leaf — pure Dart)
soliplex_dataframe         (leaf — pure Dart)
soliplex_skills            (leaf — pure Dart)
soliplex_interpreter_monty (leaf — pure Dart)

soliplex_client            → logging
soliplex_client_native     → client                         (Flutter)
soliplex_agent             → client, logging
soliplex_scripting         → agent, client, dataframe, interpreter_monty
soliplex_cli               → agent, client, logging
soliplex_tui               → agent, logging
soliplex_monty             → interpreter_monty (via dart_monty)  (Flutter)
```

## Package Overview

### [soliplex_client](soliplex_client/) — Pure Dart

Core communications layer: REST API client, AG-UI streaming protocol, and all
domain models (rooms, threads, runs, messages, tool calls). Everything that
talks to the Soliplex backend flows through this package.

### [soliplex_agent](soliplex_agent/) — Pure Dart

Higher-level session abstraction where the scripting engine is wired in. This
package is platform-aware — on WASM, `FutureSnapshot` is unavailable so Monty
runs without `await`; on native, full async Python is supported. The intent is
that the app layer becomes mostly widgets and wiring, with `soliplex_agent`
owning the orchestration logic (`RunOrchestrator`, `AgentRuntime`,
`AgentSession`).

### [soliplex_scripting](soliplex_scripting/) — Pure Dart

Generic scripting interface that bridges AG-UI events to an interpreter. Hard-
wired to Monty today but the interface was validated against d4rt as well.

### [soliplex_interpreter_monty](soliplex_interpreter_monty/) — Pure Dart

Concrete Monty Python interpreter implementation. Provides the bridge between
Dart and the Monty sandbox runtime.

### [soliplex_client_native](soliplex_client_native/) — Flutter

Native HTTP platform adapters (Cupertino networking). All platform-specific
code lives here so the rest of the stack stays pure Dart.

### [soliplex_logging](soliplex_logging/) — Pure Dart

Advanced logging and telemetry. Supports structured log sinks, DiskQueue for
offline buffering, and BackendLogSink for shipping logs to the server.

### [soliplex_schema](soliplex_schema/) — Pure Dart

Bridge for Soliplex feature schemas — Pydantic models on the server side that
arrive as JSON Schema. Provides `SchemaStateView`, `FeatureSchemaRegistry`, and
`SchemaParser` for typed access to feature state.

### [soliplex_dataframe](soliplex_dataframe/) — Pure Dart

Pandas-like DataFrame engine with a handle-based registry. Currently used for
showcase demos, but DataFrames may ship as a first-class system feature if the
API stabilizes.

### [soliplex_skills](soliplex_skills/) — Pure Dart

Client-side emulation of server skill data (prompts + Monty-centric Python
resources). May be removable now that the server has landed native skills
support.

### [soliplex_cli](soliplex_cli/) — Pure Dart

One-shot CLI for driving integration tests against `soliplex_agent`. Originally
designed for agents to exercise the system in non-interactive mode.

### [soliplex_tui](soliplex_tui/) — Pure Dart

Interactive terminal UI for the agent backend. Does not support auth. Has proven
valuable for agents running integration tests against live servers.

### [soliplex_monty](soliplex_monty/) — Flutter (legacy)

Legacy Flutter widget layer for the Monty bridge. Scheduled for removal — see
[issue #46](https://github.com/runyaga/flutter/issues/46).

## Candidate Packages

### soliplex_lints (planned)

Shared lint and analysis configuration for the monorepo. Would centralize
`very_good_analysis` settings, formatter config, and analyzer excludes into one
package that all targets include.

Beyond standard lints, the scripting stack passes event streams through multiple
layers (AG-UI events through `soliplex_scripting` into `soliplex_agent` and up
to the app), creating many lifecycle resources (676 dispose/close/cancel calls
across 102 files) that can easily leak if not cleaned up properly. Custom lint
rules could enforce lifecycle cleanup at each layer boundary.

DCM (`avoid-banned-imports`, `dispose-fields`, `close_sinks`,
`cancel_subscriptions`) covers the initial enforcement cases. If DCM proves
insufficient for our multi-layer streaming patterns, `soliplex_lints` would be
the place to invest in `custom_lint` rules with full AST access. See
[lint standardization plan](https://github.com/runyaga/flutter/issues/46) and
the exploration at `/soliplex-plans/soliplex-lints-exploration.md`.

## Working on a Package

```bash
cd packages/<package_name>

# Pure Dart packages
dart pub get
dart test
dart format . --set-exit-if-changed
dart analyze --fatal-infos

# Flutter packages (soliplex_client_native, soliplex_monty)
flutter pub get
flutter test
dart format . --set-exit-if-changed
dart analyze --fatal-infos
```

## Rules

- Pure Dart packages must not import `package:flutter/*`.
- Platform-specific code goes in `soliplex_client_native`.
- All packages use `very_good_analysis` for linting.
- Each package must pass `dart analyze --fatal-infos` with zero issues.
