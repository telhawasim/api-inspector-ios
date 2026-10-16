
# Contributing

## Requirements

- Xcode 16 or later.
- Swift 6.
- iOS 17 or later for application integration.

## Validation

Run:

```sh
swift package clean
swift build
swift test
```

Also build the package for an iOS 17 simulator and build the example app in
Xcode before opening a pull request.

DocC is maintained in `Sources/APIInspectorCore/APIInspectorCore.docc`. Use
Xcode's **Product > Build Documentation** command to render and validate it.

## Security requirements

Changes to capture, parsing, redaction, storage, event publication, or export
must include regression tests showing that raw secrets cannot cross the
sanitization boundary.

Unsupported body formats must remain metadata-only until a dedicated,
fail-closed parser is implemented.

Decoded configuration must pass the same validation as configuration created
through public initializers.

## Scope

Keep each pull request within the current development phase. Phase 1 contains
the core models, validated configuration, privacy sanitization, in-memory
retention, and actor-isolated recording. Networking interception and the
inspector UI are later phases.

## Style

- Use Swift 6 concurrency checking.
- Prefer immutable `Sendable` value types.
- Add documentation for new public API.
- Avoid adding runtime dependencies to the core target.
- Run `git diff --check` before submitting.
