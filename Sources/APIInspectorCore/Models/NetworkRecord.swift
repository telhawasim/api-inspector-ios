//
//  NetworkRecord.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation

public struct NetworkPayload: Hashable, Codable, Sendable {

    public enum Content: Hashable, Codable, Sendable {
        case empty
        case json(JSONValue)
        case formURLEncoded([FormField])
        case omitted(OmissionReason)
    }

    public enum OmissionReason: String, Hashable, Codable, Sendable {
        case captureDisabled
        case exceedsSizeLimit
        case unsupportedContentType
        case missingContentType
        case malformedBody
    }

    // MARK: - PROPERTIES -

    /// Normal
    public let contentType: String?
    public let originalByteCount: Int
    public let wasTruncated: Bool
    public let content: Content

    // MARK: - INITIALIZER -
    public init(contentType: String?, originalByteCount: Int, wasTruncated: Bool, content: Content) {
        self.contentType = contentType
        self.originalByteCount = originalByteCount
        self.wasTruncated = wasTruncated
        self.content = content
    }
}

public struct HTTPRequestRecord: Hashable, Codable, Sendable {

    // MARK: - PROPERTIES -

    /// Normal
    public let method: HTTPMethod
    public let url: URL
    public let headers: HTTPHeaders
    public let queryParameters: [QueryParameter]
    public let body: NetworkPayload?
    public let source: RequestSource

    // MARK: - INITIALIZER -
    public init(
        method: HTTPMethod,
        url: URL,
        headers: HTTPHeaders,
        queryParameters: [QueryParameter],
        body: NetworkPayload?,
        source: RequestSource
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.queryParameters = queryParameters
        self.body = body
        self.source = source
    }
}

public struct HTTPResponseRecord: Hashable, Codable, Sendable {

    // MARK: - PROPERTIES -

    /// Normal
    public let statusCode: Int
    public let headers: HTTPHeaders
    public let body: NetworkPayload?
    /// Computed
    public var isInformational: Bool {
        (100 ... 199).contains(statusCode)
    }

    public var isSuccessful: Bool {
        (200 ... 299).contains(statusCode)
    }

    public var isRedirection: Bool {
        (300 ... 399).contains(statusCode)
    }

    public var isClientError: Bool {
        (400 ... 499).contains(statusCode)
    }

    public var isServerError: Bool {
        (500 ... 599).contains(statusCode)
    }

    // MARK: - INITIALIZER -
    public init(statusCode: Int, headers: HTTPHeaders, body: NetworkPayload?) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public struct NetworkErrorRecord: Hashable, Codable, Sendable {

    public enum Kind: String, Hashable, Codable, Sendable {
        case transport
        case cancellation
    }

    // MARK: - PROPERTIES -

    /// Normal
    public let kind: Kind
    public let domain: String
    public let code: Int

    // MARK: - INITIALIZER -
    public init(kind: Kind, domain: String, code: Int) {
        self.kind = kind
        self.domain = domain
        self.code = code
    }
}

public struct NetworkTiming: Hashable, Codable, Sendable {

    // MARK: - PROPERTIES -

    /// Normal
    public let startedAt: Date
    public let endedAt: Date?
    /// Computed
    public var duration: TimeInterval? {
        endedAt.map {
            max(0, $0.timeIntervalSince(startedAt))
        }
    }

    // MARK: - INITIALIZER -
    public init(startedAt: Date, endedAt: Date?) {
        self.startedAt = startedAt
        self.endedAt = endedAt.map {
            max($0, startedAt)
        }
    }
}

public struct NetworkRecord: Hashable, Codable, Sendable, Identifiable {

    public enum ValidationError: Error, Hashable, Sendable {
        case startedRecordHasTerminalData
        case completedRecordRequiresResponse
        case failedRecordRequiresError
        case responseNotAllowedForState(RequestState)
        case errorNotAllowedForState(RequestState)
        case terminalRecordRequiresEndDate
    }

    // MARK: - PROPERTIES -

    /// Normal
    public let id: RequestID
    public let request: HTTPRequestRecord
    public let response: HTTPResponseRecord?
    public let error: NetworkErrorRecord?
    public let state: RequestState
    public let timing: NetworkTiming

    // MARK: - INITIALIZER -
    public init(
        id: RequestID,
        request: HTTPRequestRecord,
        response: HTTPResponseRecord?,
        error: NetworkErrorRecord?,
        state: RequestState,
        timing: NetworkTiming
    ) throws {
        switch state {
        case .started:
            guard response == nil,
                  error == nil,
                  timing.endedAt == nil else {
                throw ValidationError.startedRecordHasTerminalData
            }

        case .completed:
            guard response != nil else {
                throw ValidationError.completedRecordRequiresResponse
            }
            guard error == nil else {
                throw ValidationError.errorNotAllowedForState(state)
            }
            guard timing.endedAt != nil else {
                throw ValidationError.terminalRecordRequiresEndDate
            }

        case .failed:
            guard response == nil else {
                throw ValidationError.responseNotAllowedForState(state)
            }
            guard error != nil else {
                throw ValidationError.failedRecordRequiresError
            }
            guard timing.endedAt != nil else {
                throw ValidationError.terminalRecordRequiresEndDate
            }

        case .cancelled:
            guard response == nil else {
                throw ValidationError.responseNotAllowedForState(state)
            }
            guard timing.endedAt != nil else {
                throw ValidationError.terminalRecordRequiresEndDate
            }
        }

        self.id = id
        self.request = request
        self.response = response
        self.error = error
        self.state = state
        self.timing = timing
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case request
        case response
        case error
        case state
        case timing
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            id: container.decode(RequestID.self, forKey: .id),
            request: container.decode(
                HTTPRequestRecord.self,
                forKey: .request
            ),
            response: container.decodeIfPresent(
                HTTPResponseRecord.self,
                forKey: .response
            ),
            error: container.decodeIfPresent(
                NetworkErrorRecord.self,
                forKey: .error
            ),
            state: container.decode(
                RequestState.self,
                forKey: .state
            ),
            timing: container.decode(
                NetworkTiming.self,
                forKey: .timing
            )
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(request, forKey: .request)
        try container.encodeIfPresent(response, forKey: .response)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encode(state, forKey: .state)
        try container.encode(timing, forKey: .timing)
    }
}
