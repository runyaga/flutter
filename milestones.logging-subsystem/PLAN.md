# Central Logging Architecture - Implementation Plan

## Overview

This plan implements a comprehensive central logging facility for the Soliplex
Flutter application providing filesystem logging with rotation, in-app log
viewer, feedback form with log attachment, runtime-configurable log levels, and
full documentation.

**Key Constraint:** Uses existing network transport layer (`SoliplexApi`,
`HttpTransport`) - no new sockets or HTTP clients.

## Spec Reference

Source spec: `docs/planning/logging-architecture.md`

## Spec Divergences

The following decisions differ from the original spec based on technical
requirements and Council review:

| Topic | Spec States | Milestone Decision | Rationale |
|-------|-------------|-------------------|-----------|
| ConsoleSink output | `debugPrint()` | `dart:developer log()` | `soliplex_logging` is a pure Dart package with no Flutter dependency. `debugPrint()` requires Flutter foundation, violating the pure Dart requirement stated in the spec ("No dependencies beyond meta"). `dart:developer log()` is the standard pure Dart console output mechanism and achieves the same goal. This is a **necessary technical deviation** to maintain package purity. |

**Note:** All other spec requirements are followed exactly, including:

- `very_good_analysis: ^7.0.0` in both package dev_dependencies
- `synchronized: ^3.1.0` and `path: ^1.9.0` in soliplex_logging_io
- 85% coverage target on logging packages
- Cross-platform verification matrix

## Directory Structure Note

The `wiggum.yaml` configuration points to `milestones/` as the milestone
directory. Only this directory contains milestone files. Any `.wiggum/`
directory is transient automation state and should be ignored.

## Milestone Sequence

| Order | Milestone | Description | Depends On |
|-------|-----------|-------------|------------|
| 1 | 01-logging-core-package | Pure Dart logging core: LogLevel, LogRecord, sinks, Logger, LogManager | - |
| 2 | 02-logging-io-package | File-based logging with rotation and compression | 01 |
| 3 | 03-flutter-providers | Riverpod integration, persisted config, platform-aware initialization | 02 |
| 4 | 04-log-viewer-ui | In-app log viewer with filtering, search, and export | 03 |
| 5 | 05-feedback-submission | Feedback screen with compressed log upload via existing HTTP transport | 03 |
| 6 | 06-migration-existing-logs | Migrate all existing _log() and debugPrint calls | 03 |
| 7 | 07-documentation | Package READMEs, API usage docs, architecture documentation | 06 |

## Architectural Decisions

### Package Structure

```text
packages/
  soliplex_logging/         # Pure Dart - no Flutter dependency
  soliplex_logging_io/      # dart:io file operations
```

### Platform Strategy

| Feature | iOS/macOS/Android/Windows/Linux | Web |
|---------|--------------------------------|-----|
| Console logging | ConsoleSink (dart:developer log()) | ConsoleSink (dart:developer log()) |
| Memory buffer | MemorySink | MemorySink |
| File persistence | FileSink | N/A (conditional import returns null) |
| Log export | Direct file save | Blob download |
| Backend upload | Existing HttpTransport | Existing HttpTransport |

### Export Strategy (No New Dependencies)

- **Native (iOS/Android/macOS/Windows/Linux):** Direct file write to app
  documents directory using existing `path_provider` dependency. Returns file
  path for user to locate.
- **Web:** Blob API download via `dart:html`
- **No file picker, share_plus, or other new plugins required**

### Web Compatibility

The `soliplex_logging_io` package uses `dart:io` which is unavailable on Web.
Milestone 03 uses conditional imports to isolate this dependency:

- `file_sink_stub.dart` - Returns null on web
- `file_sink_io.dart` - Real implementation on native platforms

**IMPORTANT:** Even with conditional imports, `soliplex_logging_io` MUST be
listed as a dependency in `pubspec.yaml` for the import directive to resolve
during Dart analysis and compilation. The conditional import mechanism controls
which file is *compiled*, but the package must still be a declared dependency.

This ensures Flutter Web compiles without `dart:io` import errors.

### Log Submission

Uses existing `HttpTransport` from `soliplex_client` package. No new HTTP
clients.

## Quality Gates

Each milestone must pass:

- `dart format --set-exit-if-changed .`
- `dart analyze --fatal-infos` with 0 issues
- `flutter test` (or `dart test` for packages)
- Test coverage ≥85% on logging packages (milestones 01 and 02)
- Gemini review: PASS
- Codex review: PASS

## Verification Targets

From the spec, the following verification targets apply:

1. **Coverage:** 85%+ on `soliplex_logging` and `soliplex_logging_io` packages
2. **Cross-platform:** Verified on macOS, Windows, Linux, iOS, Android, Web
3. **Backend integration:** Verify `/api/v1/feedback/logs` endpoint accepts
   submissions

See OVERVIEW.md for the cross-platform verification checklist.

## Documentation Deliverables

Defined in milestone 07-documentation:

- `packages/soliplex_logging/README.md` - Package API reference
- `packages/soliplex_logging_io/README.md` - IO package usage
- `docs/logging.md` - Architecture overview and usage guide
- Inline dartdoc comments on all public APIs

## Progress Tracking

See [OVERVIEW.md](./OVERVIEW.md) for milestone status and checklist.
