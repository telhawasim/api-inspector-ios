//
//  ConfigurationTests.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation
import Testing
@testable import APIInspectorCore

@Suite("Configuration validation")
struct ConfigurationTests {
    @Test
    func bodyLimitMustBePositive() {
        #expect(throws: CaptureConfiguration.ValidationError.self) {
            try CaptureConfiguration(maximumBodySize: 0)
        }
    }

    @Test
    func recordLimitMustBePositive() {
        #expect(throws: RetentionConfiguration.ValidationError.self) {
            try RetentionConfiguration(maximumRecords: 0)
        }
    }

    @Test
    func releaseRecordingRequiresExplicitOptIn() {
        #expect(throws: InspectorConfiguration.ValidationError.self) {
            try InspectorConfiguration(
                recordingEnabled: true,
                environment: .release,
                allowsRecordingInRelease: false
            )
        }
    }

    @Test
    func ignoredHostsIncludeSubdomains() throws {
        let capture = try CaptureConfiguration(
            ignoredHosts: ["payments.example.com"]
        )

        #expect(
            capture.permits(
                url: TestFixtures.url(
                    "https://payments.example.com/charge"
                ),
                method: .post
            ) == false
        )

        #expect(
            capture.permits(
                url: TestFixtures.url(
                    "https://api.payments.example.com/charge"
                ),
                method: .post
            ) == false
        )

        #expect(
            capture.permits(
                url: TestFixtures.url(
                    "https://example.com/charge"
                ),
                method: .post
            )
        )
    }

    @Test
    func endpointExclusionsCanBeMethodSpecific() throws {
        let exclusion = try EndpointExclusion(
            method: .post,
            host: "example.com",
            pathPrefix: "/authentication"
        )
        let capture = try CaptureConfiguration(
            ignoredEndpoints: [exclusion]
        )
        let url = TestFixtures.url(
            "https://example.com/authentication/login"
        )

        #expect(capture.permits(url: url, method: .get))
        #expect(capture.permits(url: url, method: .post) == false)
    }

    @Test
    func decodingCannotBypassReleaseRecordingValidation() throws {
        let valid = try InspectorConfiguration(
            recordingEnabled: false,
            environment: .release,
            allowsRecordingInRelease: false
        )
        let encoded = try JSONEncoder().encode(valid)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object["recordingEnabled"] = true
        let tampered = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: InspectorConfiguration.ValidationError.self) {
            try JSONDecoder().decode(
                InspectorConfiguration.self,
                from: tampered
            )
        }
    }

    @Test
    func decodingCannotBypassRetentionValidation() throws {
        let encoded = try JSONEncoder().encode(RetentionConfiguration.default)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object["maximumRecords"] = -1
        let tampered = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: RetentionConfiguration.ValidationError.self) {
            try JSONDecoder().decode(
                RetentionConfiguration.self,
                from: tampered
            )
        }
    }

    @Test
    func validatedConfigurationRoundTripsThroughCodable() throws {
        let original = try TestFixtures.configuration(
            maximumRecords: 25,
            capturesBodies: true,
            maximumBodySize: 4_096
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            InspectorConfiguration.self,
            from: data
        )

        #expect(decoded == original)
    }
}
