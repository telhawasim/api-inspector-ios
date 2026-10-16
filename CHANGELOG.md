# Changelog

All notable changes to APIInspector are documented in this file. The project
uses semantic versioning after its first stable release.

## Unreleased

### Added

- Swift 6 package foundation for iOS 17 and macOS 14.
- Immutable, Codable, `Sendable` HTTP transaction models.
- Validated capture, privacy, retention, storage, and environment settings.
- Early redaction for headers, URL queries and paths, nested JSON, and
  URL-encoded forms.
- Fail-closed metadata handling for unsupported, malformed, and oversized
  payloads.
- Actor-isolated request tracking with terminal-state race protection.
- Bounded independent `AsyncStream` event subscribers.
- In-memory count and age retention.
- Swift Testing and XCTest coverage.
- DocC articles and an iOS example application.

### Security

- Configuration decoded from external data is routed through the same
  validation as configuration created in code.
- Raw request and response inputs are sanitized before tracking, storage, or
  event publication.

## 0.1.0 - Phase 1

Initial development release of the APIInspector core. No automatic networking
capture or inspector UI is included.
