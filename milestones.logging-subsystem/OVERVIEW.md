# Central Logging Architecture - Milestone Overview

## Progress

- [ ] 01-logging-core-package
- [ ] 02-logging-io-package
- [ ] 03-flutter-providers
- [ ] 04-log-viewer-ui
- [ ] 05-feedback-submission
- [ ] 06-migration-existing-logs
- [ ] 07-documentation

## Milestones

### 01-logging-core-package

- **Status:** pending
- **File:** [01-logging-core-package.md](./01-logging-core-package.md)

## Success Criteria

- [ ] Package compiles with zero analyzer issues
- [ ] Unit tests pass
- [ ] Test coverage ≥85% on package
- [ ] Gemini review: PASS
- [ ] Codex review: PASS

---

### 02-logging-io-package

- **Status:** pending
- **Depends on:** 01-logging-core-package
- **File:** [02-logging-io-package.md](./02-logging-io-package.md)

## Success Criteria

- [ ] Package compiles with zero analyzer issues
- [ ] Unit tests pass (file rotation, compression)
- [ ] Test coverage ≥85% on package
- [ ] Gemini review: PASS
- [ ] Codex review: PASS

---

### 03-flutter-providers

- **Status:** pending
- **Depends on:** 02-logging-io-package
- **File:** [03-flutter-providers.md](./03-flutter-providers.md)

## Success Criteria

- [ ] Providers integrate with LogManager
- [ ] Log level persists across app restarts
- [ ] Full test suite passes
- [ ] Flutter Web compiles without errors (no dart:io leakage)
- [ ] Gemini review: PASS
- [ ] Codex review: PASS

---

### 04-log-viewer-ui

- **Status:** pending
- **Depends on:** 03-flutter-providers
- **File:** [04-log-viewer-ui.md](./04-log-viewer-ui.md)

## Success Criteria

- [ ] Log viewer screen accessible from settings
- [ ] Filter by level, module, and search work
- [ ] Export works on all platforms (no new dependencies)
- [ ] Widget tests pass
- [ ] Gemini review: PASS
- [ ] Codex review: PASS

---

### 05-feedback-submission

- **Status:** pending
- **Depends on:** 03-flutter-providers
- **File:** [05-feedback-submission.md](./05-feedback-submission.md)

## Success Criteria

- [ ] LogSubmissionService uses existing HttpTransport
- [ ] Feedback screen compresses and uploads logs
- [ ] Works on web (memory buffer) and native (file)
- [ ] Unit and widget tests pass
- [ ] Backend endpoint accepts gzip-compressed payload (manual verification)
- [ ] Gemini review: PASS
- [ ] Codex review: PASS

---

### 06-migration-existing-logs

- **Status:** pending
- **Depends on:** 03-flutter-providers
- **File:** [06-migration-existing-logs.md](./06-migration-existing-logs.md)

## Success Criteria

- [ ] All existing `_log()` and `debugPrint` calls migrated
- [ ] HTTP observer integrated with central logger
- [ ] Full test suite passes
- [ ] Gemini review: PASS
- [ ] Codex review: PASS

---

### 07-documentation

- **Status:** pending
- **Depends on:** 06-migration-existing-logs
- **File:** [07-documentation.md](./07-documentation.md)

## Success Criteria

- [ ] soliplex_logging/README.md exists with API reference
- [ ] soliplex_logging_io/README.md exists with usage guide
- [ ] docs/logging.md exists with architecture overview
- [ ] All public APIs have dartdoc comments
- [ ] Gemini review: PASS
- [ ] Codex review: PASS

---

## Cross-Platform Verification (Final)

After all milestones complete, verify on each platform:

| Test | macOS | Windows | Linux | iOS | Android | Web |
|------|-------|---------|-------|-----|---------|-----|
| App launches | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Logs appear in console | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Log viewer shows entries | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Log files created | ☐ | ☐ | ☐ | ☐ | ☐ | N/A |
| Log rotation works | ☐ | ☐ | ☐ | ☐ | ☐ | N/A |
| Feedback submission | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Log level persists | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |
| Local download | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ |

## Notes

- Started: 2026-01-20
- Key constraint: Uses existing network transport (SoliplexApi, HttpTransport)
- No new HTTP clients or sockets
- Web platform uses memory buffer only (no file I/O)
- Native export writes directly to app documents directory (no file picker or
  share plugins)
- Source spec: `docs/planning/logging-architecture.md`
