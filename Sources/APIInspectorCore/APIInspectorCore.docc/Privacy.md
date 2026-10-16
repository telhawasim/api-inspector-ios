# Privacy architecture

APIInspector uses early sanitization instead of display-time masking.

## Capture path

1. A networking adapter creates a transient input.
2. The capture policy excludes configured hosts and endpoints.
3. Body-size limits are evaluated before parsing.
4. Supported bodies are parsed and recursively sanitized.
5. Unsupported or malformed bodies become metadata-only payloads.
6. Only sanitized models enter tracking, storage, or event delivery.

## Fail-closed body handling

Phase 1 supports:

- `application/json`;
- media types ending in `+json`;
- `application/x-www-form-urlencoded`.

Multipart, arbitrary text, compressed, protobuf, and binary payloads
are metadata-only. Oversized JSON is not partially stored because
partial JSON may conceal a sensitive field beyond the captured range.

## Error handling

Raw localized error descriptions are not accepted. They frequently
contain URLs or server-provided information. Only a bounded error
domain and numeric code are retained.

## Production defaults

Recording and body capture are disabled by default. Enabling recording
in a release environment requires explicit configuration.
