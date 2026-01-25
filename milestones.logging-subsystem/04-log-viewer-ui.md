# Milestone: Log Viewer UI

**Status:** pending
**Depends on:** 03-flutter-providers

## Objective

Create an in-app log viewer screen accessible from Settings, with level
filtering, module/loggerName filtering, search, and cross-platform export
functionality.

## Pre-flight Checklist

- [ ] Logging providers exist and work
- [ ] Understand existing settings screen structure
- [ ] Review conditional import pattern in `packages/soliplex_client_native/`

## Files to Create

- `lib/features/logging/log_viewer_screen.dart`
- `lib/features/logging/widgets/log_entry_tile.dart`
- `lib/features/logging/widgets/log_filter_bar.dart`
- `lib/features/logging/widgets/log_export_button.dart`
- `lib/features/logging/log_export.dart` (conditional export)
- `lib/features/logging/log_export_stub.dart`
- `lib/features/logging/log_export_web.dart`
- `lib/features/logging/log_export_io.dart`
- `test/features/logging/log_viewer_screen_test.dart`
- `test/features/logging/widgets/log_entry_tile_test.dart`

## Files to Modify

- `lib/features/settings/settings_screen.dart` - Add logging section
- `lib/core/router/app_router.dart` - Add log viewer route

## Export Strategy (No New Dependencies)

This milestone uses **direct file save** without any file picker or share
plugins:

- **Native (iOS/Android/macOS/Windows/Linux):** Write to app's documents
  directory using existing `path_provider` dependency, then display file path
  to user via snackbar
- **Web:** Use `dart:html` Blob API to trigger browser download

No `file_picker`, `share_plus`, or other new plugins are required.

## Changes

### Change 1: Create LogEntryTile widget

**File:** `lib/features/logging/widgets/log_entry_tile.dart`

- [ ] Display timestamp, level badge, logger name, message
- [ ] Color-code level badge (error=red, warning=orange, info=blue, debug=gray)
- [ ] Show error/stackTrace in expandable section if present

### Change 2: Create LogFilterBar widget

**File:** `lib/features/logging/widgets/log_filter_bar.dart`

- [ ] Horizontal scrollable chips for each LogLevel
- [ ] "All" option to clear level filter
- [ ] Module/loggerName dropdown or chips to filter by source
- [ ] Dynamically populate module list from distinct loggerName values in
  records
- [ ] Search text field with debounce
- [ ] Callback for filter changes

### Change 3: Create conditional export files

**Files:** `lib/features/logging/log_export*.dart`

Export Barrel (`log_export.dart`):

```dart
export 'log_export_stub.dart'
    if (dart.library.html) 'log_export_web.dart'
    if (dart.library.io) 'log_export_io.dart';
```

Stub (`log_export_stub.dart`):

- [ ] Define signature: `Future<String?> exportLogs(List<LogRecord> records)`
- [ ] Return value is file path (native) or null (web/error)
- [ ] Stub throws `UnsupportedError`

Web (`log_export_web.dart`):

- [ ] Use `dart:html` Blob API
- [ ] Create text blob from formatted log records
- [ ] Trigger download with timestamp filename: `soliplex_logs_<timestamp>.txt`
- [ ] Return null (web has no file path)

IO (`log_export_io.dart`):

- [ ] Use `path_provider` to get application documents directory
- [ ] Write formatted log content to `soliplex_logs_<timestamp>.txt`
- [ ] Return the file path for display to user
- [ ] No file picker or share plugin needed

### Change 4: Create LogExportButton widget

**File:** `lib/features/logging/widgets/log_export_button.dart`

- [ ] IconButton with download icon
- [ ] On tap: get filtered records, call platform export
- [ ] Show snackbar with file path (native) or "Downloaded" (web)
- [ ] Show error snackbar on failure

### Change 5: Create LogViewerScreen

**File:** `lib/features/logging/log_viewer_screen.dart`

- [ ] AppBar with title "Logs" and export button
- [ ] LogFilterBar at top
- [ ] ListView.builder displaying filtered LogRecords from MemorySink
- [ ] Use LogEntryTile for each record
- [ ] Filter by level, module/loggerName, and search text
- [ ] Show empty state when no logs match filter

### Change 6: Add settings integration

**File:** `lib/features/settings/settings_screen.dart`

- [ ] Add "Logging" section divider
- [ ] Add ListTile for "Log Level" with current level subtitle, opens picker
- [ ] Add SwitchListTile for "Save logs to file" (native only, hide on web)
- [ ] Add ListTile for "View Logs" navigating to `/settings/logs`
- [ ] Use ref.watch(logConfigProvider) for current state

### Change 7: Add router integration

**File:** `lib/core/router/app_router.dart`

- [ ] Add route `/settings/logs` pointing to LogViewerScreen
- [ ] Nest under settings branch

### Change 8: Write widget tests

**Files:** `test/features/logging/*.dart`

- [ ] Test LogEntryTile renders all fields correctly
- [ ] Test LogFilterBar emits filter changes
- [ ] Test LogViewerScreen filters by level
- [ ] Test LogViewerScreen filters by module/loggerName
- [ ] Test LogViewerScreen filters by search text
- [ ] Test empty state when no logs

## Success Criteria

- [ ] `dart format --set-exit-if-changed .` passes
- [ ] `dart analyze --fatal-infos` passes
- [ ] `flutter test` passes
- [ ] Log viewer accessible from Settings > View Logs
- [ ] Level filter shows only matching logs
- [ ] Module filter shows only logs from selected logger(s)
- [ ] Search filters by message content
- [ ] Export works on all platforms using existing dependencies only
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
