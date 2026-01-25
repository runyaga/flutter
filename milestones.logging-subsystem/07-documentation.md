# Milestone: Documentation

**Status:** pending
**Depends on:** 06-migration-existing-logs

## Objective

Create comprehensive documentation for the logging system including package
READMEs, API usage guide, and architecture overview. This fulfills the "Full
documentation" requirement from the original spec.

## Pre-flight Checklist

- [ ] All logging packages implemented and tested
- [ ] All providers and UI integrated
- [ ] Migration complete

## Files to Create

- `packages/soliplex_logging/README.md`
- `packages/soliplex_logging_io/README.md`
- `docs/logging.md`

## Files to Modify

- `packages/soliplex_logging/lib/src/*.dart` - Add dartdoc comments
- `packages/soliplex_logging_io/lib/src/*.dart` - Add dartdoc comments

## Changes

### Change 1: Create soliplex_logging README

**File:** `packages/soliplex_logging/README.md`

- [ ] Package description and purpose
- [ ] Installation instructions
- [ ] Quick start example
- [ ] API reference:
  - LogLevel enum values and usage
  - LogRecord class and serialization
  - LogSink interface for custom sinks
  - LogFormatter for custom formatting
  - ConsoleSink configuration
  - MemorySink for in-memory buffering
  - Logger facade methods
  - LogManager singleton API
- [ ] Example: Creating a custom sink
- [ ] Example: Filtering logs by level

### Change 2: Create soliplex_logging_io README

**File:** `packages/soliplex_logging_io/README.md`

- [ ] Package description (file I/O extension)
- [ ] Installation instructions
- [ ] Platform support matrix
- [ ] FileSink configuration:
  - Directory setup
  - Rotation settings (maxFileSize, maxFileCount)
  - Initialization
- [ ] LogCompressor usage
- [ ] Example: Setting up file logging
- [ ] Example: Compressing logs for upload

### Change 3: Create architecture documentation

**File:** `docs/logging.md`

- [ ] Architecture overview diagram (text-based)
- [ ] Package structure explanation
- [ ] Data flow: Logger → LogManager → Sinks
- [ ] Platform considerations:
  - Web vs Native differences
  - Directory paths per platform
- [ ] Provider architecture:
  - LogConfigNotifier and persistence
  - Sink providers and lifecycle
- [ ] Integration points:
  - Initialization in main.dart
  - Settings screen integration
  - Feedback submission flow
- [ ] Logger naming conventions
- [ ] Log level guidelines (when to use each)
- [ ] Troubleshooting common issues

### Change 4: Add dartdoc comments to public APIs

**Files:** `packages/soliplex_logging/lib/src/*.dart`

- [ ] LogLevel: Document each level's intended use
- [ ] LogRecord: Document all fields and serialization
- [ ] LogSink: Document interface contract
- [ ] LogFormatter: Document formatting interface
- [ ] ConsoleSink: Document configuration options
- [ ] MemorySink: Document buffer behavior
- [ ] Logger: Document each method and parameters
- [ ] LogManager: Document singleton usage and lifecycle

**Files:** `packages/soliplex_logging_io/lib/src/*.dart`

- [ ] FileSink: Document rotation behavior and configuration
- [ ] LogCompressor: Document compression format

### Change 5: Verify documentation quality

- [ ] Run `dart doc` on packages to verify dartdoc parses correctly
- [ ] Review READMEs for completeness
- [ ] Ensure examples are copy-pasteable and work

## Documentation Content Requirements

### Package README Template

Each package README must include:

1. **Title and badges** (optional)
2. **Description** (1-2 sentences)
3. **Installation** (pubspec.yaml snippet)
4. **Quick Start** (minimal working example)
5. **API Reference** (key classes/methods)
6. **Examples** (common use cases)

### Architecture Doc Sections

1. Overview
2. Package Structure
3. Core Concepts
4. Platform Support
5. Integration Guide
6. Best Practices
7. Troubleshooting

## Success Criteria

- [ ] `packages/soliplex_logging/README.md` exists and is complete
- [ ] `packages/soliplex_logging_io/README.md` exists and is complete
- [ ] `docs/logging.md` exists with architecture overview
- [ ] All public APIs have dartdoc comments
- [ ] `dart doc` runs without errors on both packages
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
