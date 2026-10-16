//
//  TestFixtures.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation
@testable import APIInspectorCore

enum TestFixtures {

    static func url(_ value: String) -> URL {
        guard let url = URL(string: value) else {
            preconditionFailure("Invalid test URL: \(value)")
        }

        return url
    }

    static func configuration(
        maximumRecords: Int = 1_000,
        capturesBodies: Bool = true,
        maximumBodySize: Int = 256_000,
        privacy: PrivacyConfiguration = .default
    ) throws -> InspectorConfiguration {
        try InspectorConfiguration(
            recordingEnabled: true,
            environment: .testing,
            capture: CaptureConfiguration(
                capturesHeaders: true,
                capturesBodies: capturesBodies,
                maximumBodySize: maximumBodySize
            ),
            privacy: privacy,
            retention: RetentionConfiguration(maximumRecords: maximumRecords)
        )
    }

    static func request(index: Int = 0, body: RawBody? = nil) -> HTTPRequestInput {
        HTTPRequestInput(
            method: .get,
            url: url("https://api.example.com/items/\(index)?token=secret-\(index)&page=1"),
            headers: [
                "Authorization": "Bearer secret-\(index)",
                "Accept": "application/json"
            ],
            body: body
        )
    }

    static let response = HTTPResponseInput(
        statusCode: 200,
        headers: [
            "Content-Type": "application/json"
        ],
        body: RawBody(
            data: Data(#"{"ok":true}"#.utf8),
            contentType: "application/json"
        )
    )
}
