//
//  InspectorEventHub.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation

public enum InspectorEvent: Hashable, Sendable {
    case recordingStateChanged(isRecording: Bool)
    case configurationChanged(InspectorConfiguration)
    case requestStarted(id: RequestID, request: HTTPRequestRecord, startedAt: Date)
    case recordStored(NetworkRecord)
    case recordsCleared(removedActiveRequestCount: Int, occurredAt: Date)
}

public enum EventSubscriptionError: Error, Hashable, Sendable {
    case invalidBufferCapacity
}

actor InspectorEventHub {

    // MARK: - PROPERTIES -

    /// Normal
    private var subscribers: [UUID: AsyncStream<InspectorEvent>.Continuation] = [:]

    func stream(bufferingNewest capacity: Int) throws -> AsyncStream<InspectorEvent> {
        guard capacity > 0 else {
            throw EventSubscriptionError.invalidBufferCapacity
        }

        let id = UUID()
        let pair = AsyncStream<InspectorEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(capacity)
        )

        subscribers[id] = pair.continuation

        pair.continuation.onTermination = { @Sendable [weak self] _ in
            Task {
                await self?.removeSubscriber(id)
            }
        }

        return pair.stream
    }

    func publish(_ event: InspectorEvent) {
        for continuation in subscribers.values {
            continuation.yield(event)
        }
    }

    func finish() {
        let current = subscribers.values
        subscribers.removeAll()

        for continuation in current {
            continuation.finish()
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers.removeValue(forKey: id)
    }
}
