
# ``APIInspectorCore``

A privacy-first, actor-isolated HTTP transaction recording engine.

## Overview

APIInspectorCore supplies the foundational models, configuration,
sanitization pipeline, repository abstraction, event delivery, and
recording actor used by APIInspector.

Phase 1 intentionally performs no automatic network interception.
Applications or future adapters pass transient request and response
inputs to ``NetworkRecorder``.

Raw inputs are sanitized before they enter:

- active request tracking;
- completed-record repositories;
- asynchronous event streams;
- future storage, UI, analytics, or export pipelines.

## Topics

### Configuration

- ``InspectorConfiguration``
- ``CaptureConfiguration``
- ``PrivacyConfiguration``
- ``RetentionConfiguration``

### Recording

- ``NetworkRecorder``
- ``RecordRepository``
- ``InMemoryRecordRepository``
- ``InspectorEvent``

### Models

- ``NetworkRecord``
- ``HTTPRequestRecord``
- ``HTTPResponseRecord``
- ``NetworkPayload``
- ``NetworkErrorRecord``

### Transient input

- ``HTTPRequestInput``
- ``HTTPResponseInput``
- ``NetworkTransactionInput``
