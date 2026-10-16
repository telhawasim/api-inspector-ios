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
```

The convenience facade is also available as the `APIInspector` product.

## Requirements

- Swift 6 language mode
- Xcode 16 or later
- iOS 17 or later
- macOS 14 or later when running the core package and tests directly

## Basic usage

```swift
import APIInspectorCore

let configuration = try InspectorConfiguration(
    recordingEnabled: true,
    environment: .debug,
    capture: CaptureConfiguration(
        capturesHeaders: true,
        capturesBodies: true,
        maximumBodySize: 256_000
    ),
    retention: RetentionConfiguration(
        maximumRecords: 1_000
    )
)

let recorder = try NetworkRecorder(configuration: configuration)

let request = HTTPRequestInput(
    method: .get,
    url: URL(string: "https://api.example.com/users?token=secret")!,
    headers: ["Authorization": "Bearer secret"]
)

if let id = try await recorder.begin(request) {
    try await recorder.complete(
        id,
        response: HTTPResponseInput(statusCode: 200)
    )
}
```

Phase 1 accepts explicit request and response inputs. Automatic `URLSession`
integration belongs to Phase 2.

## Events

```swift
let events = try await recorder.events(bufferingNewest: 64)

for await event in events {
    print(event)
}
```

Every subscriber receives an independent bounded buffer. A slow subscriber
cannot block recording or another subscriber. When a buffer is full, its
oldest buffered event is discarded.

## Privacy boundary

Raw input types can contain secrets and are intentionally transient. The
recorder sanitizes them before active tracking, repository insertion, or event
publication.

Supported body sanitizers:

- `application/json` and media types ending in `+json`
- `application/x-www-form-urlencoded`

Malformed, oversized, multipart, compressed, protobuf, text, and binary
bodies are retained as metadata only. Recording and body capture are disabled
by default. Recording in a release environment requires explicit opt-in.

## Testing

```sh
swift build
swift test
```

The example app is located at
`Examples/APIInspectorDemo/APIInspectorDemo.xcodeproj`.

## Phase 1 boundary

Phase 1 does not include:

- automatic request interception;
- URLSession metrics;
- SQLite persistence;
- replay or mocking;
- export or analytics;
- an inspector user interface.

## Documentation

The DocC catalog lives in
`Sources/APIInspectorCore/APIInspectorCore.docc`. Build documentation from
Xcode with **Product > Build Documentation**.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

APIInspector is available under the MIT license. See [LICENSE](LICENSE).
