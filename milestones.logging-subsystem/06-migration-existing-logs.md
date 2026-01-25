# Milestone: Migration of Existing Logs

**Status:** pending
**Depends on:** 03-flutter-providers

## Objective

Migrate all existing `_log()` helper methods and `debugPrint` calls to use the
central logging system. Integrate HTTP observer with the logger.

## Pre-flight Checklist

- [ ] Central logging system is working
- [ ] Review all files with existing log patterns
- [ ] Identify logger name conventions

## Files to Modify

### Core Layer

- `lib/core/providers/active_run_notifier.dart` - Has `_log()` pattern
- `lib/core/auth/auth_notifier.dart` - Has `_log()` pattern
- `lib/core/providers/http_log_provider.dart` - HTTP observer
- `lib/core/router/app_router.dart` - Router logging

### Feature Layer

- `lib/features/home/home_screen.dart` - Connectivity logging
- `lib/features/chat/` - Chat feature files with logging
- `lib/features/room/` - Room feature files with logging
- `lib/features/quiz/` - Quiz feature files with logging

### Client Package

- `packages/soliplex_client/lib/src/api/mappers.dart` - Quiz warnings

## Changes

### Change 1: Migrate active_run_notifier.dart

**File:** `lib/core/providers/active_run_notifier.dart`

- [ ] Import `log_helper.dart`
- [ ] Replace `void _log(String message) => debugPrint(...)` with
  `final _log = getLogger('ActiveRunNotifier')`
- [ ] Replace `_log('message')` calls with `_log.info('message')` or
  appropriate level
- [ ] Use `_log.error()` for error cases with error and stackTrace params

### Change 2: Migrate auth_notifier.dart

**File:** `lib/core/auth/auth_notifier.dart`

- [ ] Import `log_helper.dart`
- [ ] Replace `_log()` helper pattern
- [ ] Use appropriate levels: info for auth events, error for failures

### Change 3: Integrate HTTP observer

**File:** `lib/core/providers/http_log_provider.dart`

- [ ] Add `static final _log = LogManager.instance.getLogger('HTTP')`
- [ ] In `onRequest`: `_log.debug('${event.method} ${event.uri}')`
- [ ] In `onResponse`:
  `_log.debug('${event.statusCode} ${event.method} ${event.uri}')`
- [ ] In `onError`:
  `_log.error('${event.method} ${event.uri}', error: event.exception)`
- [ ] Keep existing HttpLogNotifier behavior (UI display) alongside central
  logger

### Change 4: Migrate router logging

**File:** `lib/core/router/app_router.dart`

- [ ] Add logger if navigation logging exists
- [ ] Use debug level for route changes

### Change 5: Migrate home_screen.dart

**File:** `lib/features/home/home_screen.dart`

- [ ] Add logger for connectivity/startup logging
- [ ] Use appropriate levels

### Change 6: Migrate chat feature

**File:** `lib/features/chat/`

- [ ] Search for `debugPrint` and `_log` patterns in chat feature files
- [ ] Migrate each file to use `getLogger('ChatFeature')` or more specific names
- [ ] Use appropriate log levels

### Change 7: Migrate room feature

**File:** `lib/features/room/`

- [ ] Search for `debugPrint` and `_log` patterns in room feature files
- [ ] Migrate each file to use `getLogger('RoomFeature')` or more specific names
- [ ] Use appropriate log levels

### Change 8: Migrate quiz feature

**File:** `lib/features/quiz/`

- [ ] Search for `debugPrint` and `_log` patterns in quiz feature files
- [ ] Migrate each file to use `getLogger('QuizFeature')` or more specific names
- [ ] Use appropriate log levels

### Change 9: Migrate client mappers

**File:** `packages/soliplex_client/lib/src/api/mappers.dart`

- [ ] This is pure Dart package - add soliplex_logging dependency if logging
  needed
- [ ] Or remove debugPrint calls if they're temporary debug code

### Change 10: Search for remaining debugPrint

- [ ] Run `grep -r "debugPrint" lib/` to find remaining calls
- [ ] Run `grep -r "debugPrint" lib/features/chat/` for chat feature
- [ ] Run `grep -r "debugPrint" lib/features/room/` for room feature
- [ ] Run `grep -r "debugPrint" lib/features/quiz/` for quiz feature
- [ ] Migrate or remove each one
- [ ] Ensure no `void _log(` patterns remain

### Change 11: Update tests

- [ ] Update any tests that mock or verify the old `_log()` pattern
- [ ] Ensure tests still pass with new logging

## Success Criteria

- [ ] `dart format --set-exit-if-changed .` passes
- [ ] `dart analyze --fatal-infos` passes
- [ ] `flutter test` passes
- [ ] No `void _log(String` patterns remain in codebase
- [ ] No `debugPrint` calls remain (except in Flutter-specific debug code)
- [ ] HTTP requests appear in log viewer
- [ ] Auth events appear in log viewer
- [ ] Chat, room, and quiz feature logs appear in log viewer
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
