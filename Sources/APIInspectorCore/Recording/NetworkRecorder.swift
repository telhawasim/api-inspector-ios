//
//  NetworkRecorder.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation

public struct TimestampProvider: Sendable {

    // MARK: - PROPERTIES -

    /// Callbacks
    private let implementation: @Sendable () -> Date

    // MARK: - INITIALIZER -
    public init(_ implementation: @escaping @Sendable () -> Date) {
        self.implementation = implementation
    }

    public func now() -> Date {
        implementation()
    }

    public static let system = TimestampProvider {
        Date()
    }
}

public actor NetworkRecorder {

    public enum RecorderError: Error, Hashable, Sendable {
        case recordingNotAllowedInRelease
        case storageBackendUnavailable
    }

    // MARK: - PROPERTIES -

    /// Normal
    public private(set) var configuration: InspectorConfiguration
    public private(set) var isRecording: Bool
    private let repository: any RecordRepository
    private let hasInjectedRepository: Bool
    private let timestamps: TimestampProvider
    private let eventHub = InspectorEventHub()
    private var tracker = RequestTracker()
    private var finalizationsInProgress = 0
    private var finalizationWaiters: [CheckedContinuation<Void, Never>] = []

    // MARK: - INITIALIZER -
    public init(
        configuration: InspectorConfiguration = .default,
        repository: (any RecordRepository)? = nil,
        timestamps: TimestampProvider = .system
    ) throws {
        if case .sqlite = configuration.storage, repository == nil {
            throw RecorderError.storageBackendUnavailable
        }

        self.configuration = configuration
        self.isRecording = configuration.recordingEnabled
        self.repository = repository ?? InMemoryRecordRepository()
        self.hasInjectedRepository = repository != nil
        self.timestamps = timestamps
    }

    public func start() async throws {
        if configuration.environment == .release, !configuration.allowsRecordingInRelease {
            throw RecorderError.recordingNotAllowedInRelease
        }

        guard !isRecording else { return }

        isRecording = true

        await eventHub.publish(.recordingStateChanged(isRecording: true)
        )
    }

    public func stop() async {
        guard isRecording else { return }

        isRecording = false

        await eventHub.publish(.recordingStateChanged(isRecording: false))
    }

    public func updateConfiguration(_ newConfiguration: InspectorConfiguration) async throws {
        if case .sqlite = newConfiguration.storage, !hasInjectedRepository {
            throw RecorderError.storageBackendUnavailable
        }

        configuration = newConfiguration
        isRecording = newConfiguration.recordingEnabled

        await eventHub.publish(.configurationChanged(newConfiguration))
        await eventHub.publish(.recordingStateChanged(
            isRecording: newConfiguration.recordingEnabled
            )
        )
    }

    @discardableResult
    public func begin(
        _ input: HTTPRequestInput,
        id: RequestID = RequestID(),
        startedAt: Date? = nil
    ) async throws -> RequestID? {
        guard isRecording,
              configuration.capture.permits(
                url: input.url,
                method: input.method
              )
                else {
            return nil
        }

        let sanitizer = PrivacySanitizer(
            capture: configuration.capture,
            privacy: configuration.privacy
        )

        let sanitizedRequest = sanitizer.sanitize(
            request: input
        )
        let date = startedAt ?? timestamps.now()

        try tracker.insert(
            ActiveRequest(
                id: id,
                request: sanitizedRequest,
                capture: configuration.capture,
                privacy: configuration.privacy,
                startedAt: date,
                phase: .tracking
            )
        )

        await eventHub.publish(
            .requestStarted(
                id: id,
                request: sanitizedRequest,
                startedAt: date
            )
        )

        return id
    }

    /// Completes a request with an HTTP response.
    ///
    /// HTTP 4xx and 5xx responses are completed HTTP transactions. They
    /// are not converted into transport failures.
    @discardableResult
    public func complete(
        _ id: RequestID,
        response: HTTPResponseInput,
        endedAt: Date? = nil
    ) async throws -> NetworkRecord {
        try await finalize(
            id,
            state: .completed,
            response: response,
            error: nil,
            endedAt: endedAt
        )
    }

    @discardableResult
    public func fail(
        _ id: RequestID,
        error: NetworkErrorInput,
        endedAt: Date? = nil
    ) async throws -> NetworkRecord {
        try await finalize(
            id,
            state: .failed,
            response: nil,
            error: error,
            endedAt: endedAt
        )
    }

    @discardableResult
    public func cancel(
        _ id: RequestID,
        endedAt: Date? = nil
    ) async throws -> NetworkRecord {
        try await finalize(
            id,
            state: .cancelled,
            response: nil,
            error: nil,
            endedAt: endedAt
        )
    }

    /// Sanitizes and records an already-completed transaction.
    @discardableResult
    public func record(
        _ transaction: NetworkTransactionInput
    ) async throws -> NetworkRecord? {
        guard let id = try await begin(
            transaction.request,
            id: transaction.id,
            startedAt: transaction.startedAt
        ) else {
            return nil
        }

        switch transaction.outcome {
        case let .response(response):
            return try await complete(
                id,
                response: response,
                endedAt: transaction.endedAt
            )

        case let .failure(error):
            return try await fail(
                id,
                error: error,
                endedAt: transaction.endedAt
            )

        case .cancelled:
            return try await cancel(
                id,
                endedAt: transaction.endedAt
            )
        }
    }

    public func records() async throws -> [NetworkRecord] {
        try await repository.records(
            retention: configuration.retention,
            relativeTo: timestamps.now()
        )
    }

    public func activeRequestCount() -> Int {
        tracker.count
    }

    public func clear(
        includingActiveRequests: Bool = false
    ) async throws {
        await waitForFinalizations()
        try await repository.clear()

        let removedActiveCount = includingActiveRequests
        ? tracker.removeTrackingRequests()
        : 0

        await eventHub.publish(
            .recordsCleared(
                removedActiveRequestCount: removedActiveCount,
                occurredAt: timestamps.now()
            )
        )
    }

    /// Creates an independent subscription with a newest-event buffer.
    ///
    /// A slow subscriber never blocks recording. If its buffer fills,
    /// its oldest buffered event is discarded without affecting other
    /// subscribers.
    public func events(
        bufferingNewest capacity: Int = 64
    ) async throws -> AsyncStream<InspectorEvent> {
        try await eventHub.stream(
            bufferingNewest: capacity
        )
    }

    private func finalize(
        _ id: RequestID,
        state: RequestState,
        response responseInput: HTTPResponseInput?,
        error errorInput: NetworkErrorInput?,
        endedAt: Date?
    ) async throws -> NetworkRecord {
        let active = try tracker.reserveForFinalization(id)
        finalizationsInProgress += 1

        let sanitizer = PrivacySanitizer(
            capture: active.capture,
            privacy: active.privacy
        )

        let response = responseInput.map {
            sanitizer.sanitize(response: $0)
        }

        let error: NetworkErrorRecord?

        switch state {
        case .completed:
            error = nil

        case .failed:
            error = errorInput.map {
                sanitizer.sanitize(error: $0)
            }

        case .cancelled:
            error = sanitizer.cancellationError()

        case .started:
            assertionFailure(
                "Finalization cannot produce a started state."
            )
            error = nil
        }

        let finalDate = max(
            endedAt ?? timestamps.now(),
            active.startedAt
        )

        let record: NetworkRecord

        do {
            record = try NetworkRecord(
                id: id,
                request: active.request,
                response: response,
                error: error,
                state: state,
                timing: NetworkTiming(
                    startedAt: active.startedAt,
                    endedAt: finalDate
                )
            )
        } catch {
            tracker.rollbackFinalization(id)
            finishFinalization()
            throw error
        }

        do {
            try await repository.insert(
                record,
                retention: configuration.retention,
                relativeTo: finalDate
            )
        } catch {
            // Repository implementations must not partially insert when
            // throwing. The request is returned to the tracking state so
            // its finalization can be retried.
            tracker.rollbackFinalization(id)
            finishFinalization()
            throw error
        }

        tracker.commitFinalization(id)
        finishFinalization()

        await eventHub.publish(
            .recordStored(record)
        )

        return record
    }

    private func waitForFinalizations() async {
        while finalizationsInProgress > 0 {
            await withCheckedContinuation { continuation in
                finalizationWaiters.append(continuation)
            }
        }
    }

    private func finishFinalization() {
        precondition(finalizationsInProgress > 0)
        finalizationsInProgress -= 1

        guard finalizationsInProgress == 0 else {
            return
        }

        let waiters = finalizationWaiters
        finalizationWaiters.removeAll(keepingCapacity: true)

        for waiter in waiters {
            waiter.resume()
        }
    }
}
