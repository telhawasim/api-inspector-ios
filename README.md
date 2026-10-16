# APIInspector

A privacy-first in-app HTTP inspection package for Swift 6 and iOS 17+.

> APIInspector is under development. Phase 1 provides the recording
> core only. It does not automatically intercept URLSession traffic.

## Phase 1 features

- Immutable `Sendable` HTTP models.
- Validated configuration.
- Recording and body capture disabled by default.
- Header, URL query, nested JSON, and form redaction.
- Metadata-only handling for unknown or malformed bodies.
- Actor-isolated request lifecycle tracking.
- Duplicate-finalization protection.
- Concurrent request support.
- Bounded, independent `AsyncStream` subscribers.
- In-memory count and age retention.
- Swift Testing, XCTest, and DocC coverage.

## Installation

Add the package URL in Xcode or `Package.swift` and depend on:

```swift
.product(name: "APIInspectorCore", package: "APIInspector")
