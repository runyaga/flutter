# Milestone: Logging IO Package

**Status:** pending
**Depends on:** 01-logging-core-package

## Objective

Create the `soliplex_logging_io` package with file-based logging sink that
supports rotation, and a compression utility for log uploads.

## Pre-flight Checklist

- [ ] `soliplex_logging` package exists and passes tests
- [ ] Understand file rotation requirements: 5MB max, 5 files max

## Files to Create

- `packages/soliplex_logging_io/pubspec.yaml`
- `packages/soliplex_logging_io/analysis_options.yaml`
- `packages/soliplex_logging_io/lib/soliplex_logging_io.dart`
- `packages/soliplex_logging_io/lib/src/file_sink.dart`
- `packages/soliplex_logging_io/lib/src/log_compressor.dart`
- `packages/soliplex_logging_io/test/file_sink_test.dart`
- `packages/soliplex_logging_io/test/log_compressor_test.dart`

## Changes

### Change 1: Create package structure

**File:** `packages/soliplex_logging_io/pubspec.yaml`

- [ ] Create pubspec with name `soliplex_logging_io`
- [ ] Set SDK constraint `^3.6.0`
- [ ] Add dependency on `soliplex_logging` (path: ../soliplex_logging)
- [ ] Add `synchronized: ^3.1.0` for thread-safe file access (per spec)
- [ ] Add `path: ^1.9.0` for cross-platform paths (per spec)
- [ ] Add dev_dependencies:
  - `test: ^1.24.0`
  - `very_good_analysis: ^7.0.0` (per spec)

### Change 2: Implement FileSink

**File:** `packages/soliplex_logging_io/lib/src/file_sink.dart`

- [ ] Accept `directory`, `maxFileSize` (5MB default), `maxFileCount` (5),
  `filePrefix`
- [ ] Implement `initialize()` to create directory and open file
- [ ] Use ISO timestamp (with `:` replaced) for filenames
- [ ] Implement `write()` with async buffering (use synchronized for safety)
- [ ] Implement rotation: create new file when size exceeded
- [ ] Implement pruning: delete oldest files when count exceeded
- [ ] Implement `getLogFiles()` returning sorted list
- [ ] Implement `getAllLogsContent()` concatenating all files
- [ ] Implement `getCompressedLogs()` returning gzipped bytes
- [ ] Use `package:path` for cross-platform path handling

### Change 3: Implement LogCompressor

**File:** `packages/soliplex_logging_io/lib/src/log_compressor.dart`

- [ ] Implement `compress(String content)` using `dart:io` gzip codec
- [ ] Implement `compressFiles(List<File>)` combining files with headers
- [ ] Return `Uint8List` of compressed bytes

### Change 4: Create barrel export

**File:** `packages/soliplex_logging_io/lib/soliplex_logging_io.dart`

- [ ] Export FileSink and LogCompressor
- [ ] Re-export soliplex_logging for convenience

### Change 5: Write unit tests

**Files:** `packages/soliplex_logging_io/test/*.dart`

- [ ] Test FileSink creates directory and file
- [ ] Test FileSink rotates at size limit
- [ ] Test FileSink prunes old files at count limit
- [ ] Test FileSink `getLogFiles()` returns sorted list
- [ ] Test LogCompressor produces valid gzip
- [ ] Test LogCompressor output can be decompressed
- [ ] Use temp directories for isolation

## Success Criteria

- [ ] `dart format --set-exit-if-changed .` passes in package directory
- [ ] `dart analyze --fatal-infos` passes in package directory
- [ ] `dart test` passes in package directory
- [ ] Test coverage ≥85%
- [ ] File rotation correctly limits size and count
- [ ] Compressed logs can be decompressed and contain original content
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
