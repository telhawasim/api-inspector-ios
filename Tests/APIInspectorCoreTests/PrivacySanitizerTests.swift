//
//  PrivacySanitizerTests.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation
import Testing
@testable import APIInspectorCore

@Suite("Privacy sanitizer")
struct PrivacySanitizerTests {
    private func sanitizer(
        maximumBodySize: Int = 256_000
    ) throws -> PrivacySanitizer {
        PrivacySanitizer(
            capture: try CaptureConfiguration(
                capturesHeaders: true,
                capturesBodies: true,
                maximumBodySize: maximumBodySize
            ),
            privacy: .default
        )
    }

    @Test
    func sensitiveHeadersAreMatchedCaseInsensitively() throws {
        let result = try sanitizer().sanitize(
            headers: HTTPHeaders(
                entries: [
                    .init(
                        name: "AUTHORIZATION",
                        value: "Bearer private"
                    ),
                    .init(
                        name: "Content-Type",
                        value: "application/json"
                    )
                ]
            )
        )

        #expect(
            result.firstValue(for: "authorization")
                == "[REDACTED]"
        )
        #expect(
            result.firstValue(for: "content-type")
                == "application/json"
        )
    }

    @Test
    func queryCredentialsAndURLUserInfoAreRemoved() throws {
        let result = try sanitizer().sanitize(
            url: TestFixtures.url(
                "https://user:password@example.com/items"
                    + "?token=abc&page=3#private"
            )
        )

        #expect(result.url.user == nil)
        #expect(result.url.password == nil)
        #expect(result.url.fragment == nil)
        #expect(
            result.queryParameters.first {
                $0.name == "token"
            }?.value == "[REDACTED]"
        )
        #expect(
            result.queryParameters.first {
                $0.name == "page"
            }?.value == "3"
        )
        #expect(result.url.absoluteString.contains("abc") == false)
    }

    @Test
    func nestedJSONAndArrayValuesAreRedacted() throws {
        let data = Data(
            """
            {
              "profile": {
                "email": "person@example.com",
                "preferences": {
                  "theme": "dark"
                }
              },
              "sessions": [
                {
                  "access_token": "one",
                  "name": "primary"
                }
              ]
            }
            """.utf8
        )

        let payload = try sanitizer().sanitize(
            body: RawBody(
                data: data,
                contentType: "application/json; charset=utf-8"
            ),
            inferredContentType: nil
        )

        guard case let .json(root)? = payload?.content else {
            Issue.record("Expected sanitized JSON")
            return
        }

        #expect(
            root["profile"]?["email"]?.stringValue
                == "[REDACTED]"
        )

        guard case let .array(sessions)? = root["sessions"],
              let first = sessions.first
        else {
            Issue.record("Expected sessions array")
            return
        }

        #expect(
            first["access_token"]?.stringValue
                == "[REDACTED]"
        )
        #expect(first["name"]?.stringValue == "primary")

        let reencoded = try JSONEncoder().encode(payload)
        let text = String(decoding: reencoded, as: UTF8.self)

        #expect(text.contains("person@example.com") == false)
        #expect(text.contains(#""one""#) == false)
    }

    @Test
    func formDataPreservesDuplicatesAndRedactsSecrets() throws {
        let data = Data(
            "email=person%40example.com&scope=read&scope=write"
                .utf8
        )

        let payload = try sanitizer().sanitize(
            body: RawBody(
                data: data,
                contentType:
                    "application/x-www-form-urlencoded"
            ),
            inferredContentType: nil
        )

        guard case let .formURLEncoded(fields)? =
            payload?.content
        else {
            Issue.record("Expected form fields")
            return
        }

        #expect(fields[0].value == "[REDACTED]")
        #expect(fields[1].value == "read")
        #expect(fields[2].value == "write")
    }

    @Test
    func unsupportedBodiesFailClosed() throws {
        let secret = Data("secret binary bytes".utf8)

        let payload = try sanitizer().sanitize(
            body: RawBody(
                data: secret,
                contentType: "application/octet-stream"
            ),
            inferredContentType: nil
        )

        #expect(
            payload?.content
                == .omitted(.unsupportedContentType)
        )

        let encoded = try JSONEncoder().encode(payload)
        let text = String(decoding: encoded, as: UTF8.self)

        #expect(text.contains("secret binary bytes") == false)
    }

    @Test
    func malformedJSONFailsClosed() throws {
        let payload = try sanitizer().sanitize(
            body: RawBody(
                data: Data(#"{"password":"secret""#.utf8),
                contentType: "application/json"
            ),
            inferredContentType: nil
        )

        #expect(payload?.content == .omitted(.malformedBody))
    }

    @Test
    func oversizedBodyIsNotPartiallyRetained() throws {
        let payload = try sanitizer(
            maximumBodySize: 8
        ).sanitize(
            body: RawBody(
                data: Data(
                    #"{"password":"secret"}"#.utf8
                ),
                contentType: "application/json"
            ),
            inferredContentType: nil
        )

        #expect(payload?.wasTruncated == true)
        #expect(
            payload?.content == .omitted(.exceedsSizeLimit)
        )
    }

    @Test
    func bodyCaptureIsDisabledByDefault() {
        let sanitizer = PrivacySanitizer(
            capture: .default,
            privacy: .default
        )

        let payload = sanitizer.sanitize(
            body: RawBody(
                data: Data(#"{"value":"data"}"#.utf8),
                contentType: "application/json"
            ),
            inferredContentType: nil
        )

        #expect(
            payload?.content == .omitted(.captureDisabled)
        )
    }
}
