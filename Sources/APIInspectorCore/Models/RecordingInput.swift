//
//  RecordingInput.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation

public struct RawBody: Sendable {

    // MARK: - PROPERTIES -

    /// Normal
    public let data: Data
    public let contentType: String?

    // MARK: - INITIALIZER -
    public init(data: Data, contentType: String? = nil) {
        self.data = data
        self.contentType = contentType
    }
}

public struct HTTPRequestInput: Sendable {

    // MARK: - PROPERTIES -

    /// Normal
    public let method: HTTPMethod
    public let url: URL
    public let headers: HTTPHeaders
    public let body: RawBody?
    public let source: RequestSource

    // MARK: - INITIALIZER -
    public init(
        method: HTTPMethod,
        url: URL,
        headers: HTTPHeaders = .init(),
        body: RawBody? = nil,
        source: RequestSource = .application
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.source = source
    }
}

public struct HTTPResponseInput: Sendable {

    // MARK: - PROPERTIES -

    /// Normal
    public let statusCode: Int
    public let headers: HTTPHeaders
    public let body: RawBody?

    // MARK: - INITIALIZER -
    public init(statusCode: Int, headers: HTTPHeaders = .init(), body: RawBody? = nil) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public struct NetworkErrorInput: Sendable {

    // MARK: - PROPERTIES -

    /// Normal
    public let domain: String
    public let code: Int

    // MARK: - INITIALIZER -
    public init(domain: String, code: Int) {
        self.domain = domain
        self.code = code
    }
}

public enum TransactionOutcome: Sendable {
    case response(HTTPResponseInput)
    case failure(NetworkErrorInput)
    case cancelled
}

public struct NetworkTransactionInput: Sendable {

    // MARK: - PROPERTIES -

    /// Normal
    public let id: RequestID
    public let request: HTTPRequestInput
    public let outcome: TransactionOutcome
    public let startedAt: Date
    public let endedAt: Date

    // MARK: - INITIALIZER -
    public init(
        id: RequestID = RequestID(),
        request: HTTPRequestInput,
        outcome: TransactionOutcome,
        startedAt: Date,
        endedAt: Date
    ) {
        self.id = id
        self.request = request
        self.outcome = outcome
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
