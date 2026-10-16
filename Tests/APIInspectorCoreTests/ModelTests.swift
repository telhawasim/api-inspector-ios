//
//  ModelTests.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation
import Testing
@testable import APIInspectorCore

@Suite("Network models")
struct ModelTests {
    @Test
    func methodNormalizationSupportsCustomMethods() {
        #expect(HTTPMethod("get") == .get)
        #expect(HTTPMethod("PATCH") == .patch)
        #expect(HTTPMethod("PURGE") == .custom("PURGE"))
    }

    @Test
    func headersAreCaseInsensitiveAndPreserveDuplicates() {
        let headers = HTTPHeaders(
            entries: [
                .init(name: "Set-Cookie", value: "a=1"),
                .init(name: "set-cookie", value: "b=2")
            ]
        )

        #expect(
            headers.values(for: "SET-COOKIE") == ["a=1", "b=2"]
        )
    }

    @Test
    func clientErrorIsACompletedHTTPTransaction() throws {
        let request = HTTPRequestRecord(
            method: .get,
            url: TestFixtures.url("https://example.com"),
            headers: .init(),
            queryParameters: [],
            body: nil,
            source: .application
        )
        let response = HTTPResponseRecord(
            statusCode: 404,
            headers: .init(),
            body: nil
        )

        let record = try NetworkRecord(
            id: RequestID(),
            request: request,
            response: response,
            error: nil,
            state: .completed,
            timing: NetworkTiming(
                startedAt: Date(timeIntervalSince1970: 10),
                endedAt: Date(timeIntervalSince1970: 11)
            )
        )

        #expect(record.state == .completed)
        #expect(record.response?.isClientError == true)
        #expect(record.error == nil)
    }

    @Test
    func invalidCompletedRecordIsRejected() {
        let request = HTTPRequestRecord(
            method: .get,
            url: TestFixtures.url("https://example.com"),
            headers: .init(),
            queryParameters: [],
            body: nil,
            source: .application
        )

        #expect(throws: NetworkRecord.ValidationError.self) {
            try NetworkRecord(
                id: RequestID(),
                request: request,
                response: nil,
                error: nil,
                state: .completed,
                timing: NetworkTiming(
                    startedAt: Date(),
                    endedAt: Date()
                )
            )
        }
    }

    @Test
    func recordRoundTripsThroughCodable() throws {
        let request = HTTPRequestRecord(
            method: .post,
            url: TestFixtures.url("https://example.com/login"),
            headers: ["Accept": "application/json"],
            queryParameters: [],
            body: nil,
            source: .application
        )

        let original = try NetworkRecord(
            id: RequestID(),
            request: request,
            response: HTTPResponseRecord(
                statusCode: 201,
                headers: .init(),
                body: nil
            ),
            error: nil,
            state: .completed,
            timing: NetworkTiming(
                startedAt: Date(timeIntervalSince1970: 100),
                endedAt: Date(timeIntervalSince1970: 101)
            )
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            NetworkRecord.self,
            from: encoded
        )

        #expect(decoded == original)
    }
}
