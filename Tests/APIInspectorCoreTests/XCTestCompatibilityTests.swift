//
//  XCTestCompatibilityTests.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import XCTest
@testable import APIInspectorCore

final class XCTestCompatibilityTests: XCTestCase {
    func testRecorderCanBeUsedFromXCTest() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )

        let optionalID = try await recorder.begin(
            TestFixtures.request()
        )
        let id = try XCTUnwrap(optionalID)

        _ = try await recorder.complete(
            id,
            response: TestFixtures.response
        )

        let records = try await recorder.records()

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].state, .completed)
    }
}
