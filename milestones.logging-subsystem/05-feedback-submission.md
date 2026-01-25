# Milestone: Feedback Submission

**Status:** pending
**Depends on:** 03-flutter-providers

## Objective

Create a feedback screen that compresses logs and uploads them to the backend
using the existing HTTP transport layer. No new HTTP clients.

## Pre-flight Checklist

- [ ] Logging providers exist and work
- [ ] Review `SoliplexApi` and `HttpTransport` for request pattern
- [ ] Review `UrlBuilder` usage in existing services

## Files to Create

- `packages/soliplex_client/lib/src/api/log_submission_service.dart`
- `lib/features/feedback/feedback_screen.dart`
- `test/features/feedback/feedback_screen_test.dart`
- `packages/soliplex_client/test/api/log_submission_service_test.dart`

## Files to Modify

- `packages/soliplex_client/lib/soliplex_client.dart` - Export LogSubmissionService
- `lib/core/providers/api_provider.dart` - Add logSubmissionProvider
- `lib/core/router/app_router.dart` - Add feedback route
- `lib/features/settings/settings_screen.dart` - Add feedback link

## Changes

### Change 1: Create LogSubmissionService

**File:** `packages/soliplex_client/lib/src/api/log_submission_service.dart`

- [ ] Accept HttpTransport and UrlBuilder in constructor
- [ ] Implement `submitLogs({required Uint8List compressedLogs, String? feedbackMessage, Map<String, String>? metadata})`
- [ ] POST to `/feedback/logs` endpoint
- [ ] Set headers: `Content-Type: application/gzip`, `Content-Encoding: gzip`
- [ ] Include feedback message in `X-Feedback-Message` header (URL-encoded)
- [ ] Return submission ID from response
- [ ] Throw ApiException on failure

### Change 2: Add provider

**File:** `lib/core/providers/api_provider.dart`

- [ ] Create `logSubmissionProvider` Provider
- [ ] Inject httpTransportProvider and urlBuilderProvider
- [ ] Return LogSubmissionService instance

### Change 3: Create FeedbackScreen

**File:** `lib/features/feedback/feedback_screen.dart`

- [ ] TextField for feedback message (multiline)
- [ ] SwitchListTile for "Attach logs" (default true)
- [ ] Submit button with loading state
- [ ] On submit:
  - Get compressed logs (from FileSink on native, MemorySink on web)
  - Call LogSubmissionService.submitLogs
  - Show success snackbar with submission ID
  - Pop screen on success
- [ ] Handle and display errors

### Change 4: Update exports

**File:** `packages/soliplex_client/lib/soliplex_client.dart`

- [ ] Export LogSubmissionService

### Change 5: Add routes and settings link

**Files:** `app_router.dart`, `settings_screen.dart`

- [ ] Add `/feedback` route to router
- [ ] Add "Send Feedback" ListTile in settings navigating to feedback screen

### Change 6: Write tests

**Files:** test files

- [ ] Test LogSubmissionService makes correct POST request
- [ ] Test LogSubmissionService handles error responses
- [ ] Test FeedbackScreen shows loading state during submit
- [ ] Test FeedbackScreen handles web platform (uses memory logs)
- [ ] Mock HttpTransport for unit tests

## Success Criteria

- [ ] `dart format --set-exit-if-changed .` passes
- [ ] `dart analyze --fatal-infos` passes
- [ ] `flutter test` passes
- [ ] Feedback screen accessible from Settings > Send Feedback
- [ ] Submitting feedback with logs makes POST with gzip payload
- [ ] Works on web (compresses memory buffer)
- [ ] Works on native (compresses file logs)
- [ ] Backend endpoint accepts gzip-compressed payload (manual verification)
- [ ] Gemini review: PASS
- [ ] Codex review: PASS
