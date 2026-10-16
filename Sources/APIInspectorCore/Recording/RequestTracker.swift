//
//  RequestTracker.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation

struct ActiveRequest: Sendable {

    enum Phase: Sendable {
        case tracking
        case finalizing
    }

    let id: RequestID
    let request: HTTPRequestRecord
    let capture: CaptureConfiguration
    let privacy: PrivacyConfiguration
    let startedAt: Date
    var phase: Phase
}

struct RequestTracker: Sendable {

    enum Error: Swift.Error, Hashable, Sendable {
        case duplicateRequest(RequestID)
        case unknownRequest(RequestID)
        case finalizationInProgress(RequestID)
    }

    // MARK: - PROPERTIES -

    /// Normal
    private var entries: [RequestID: ActiveRequest] = [:]
    /// Computed
    var count: Int { entries.count }

    mutating func insert(_ request: ActiveRequest) throws {
        guard entries[request.id] == nil else {
            throw Error.duplicateRequest(request.id)
        }

        entries[request.id] = request
    }

    mutating func reserveForFinalization(_ id: RequestID) throws -> ActiveRequest {
        guard var request = entries[id] else {
            throw Error.unknownRequest(id)
        }

        guard request.phase == .tracking else {
            throw Error.finalizationInProgress(id)
        }

        request.phase = .finalizing
        entries[id] = request

        return request
    }

    mutating func commitFinalization(_ id: RequestID) {
        entries.removeValue(forKey: id)
    }

    mutating func rollbackFinalization(_ id: RequestID) {
        guard var request = entries[id] else {
            return
        }

        request.phase = .tracking
        entries[id] = request
    }

    mutating func removeTrackingRequests() -> Int {
        let identifiers = entries.compactMap { key, value in
            value.phase == .tracking ? key : nil
        }

        for id in identifiers {
            entries.removeValue(forKey: id)
        }

        return identifiers.count
    }
}
