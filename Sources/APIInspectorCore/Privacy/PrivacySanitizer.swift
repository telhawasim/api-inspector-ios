//
//  PrivacySanitizer.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation

public struct PrivacySanitizer: Sendable {

    // MARK: - PROPERTIES -

    /// Static
    private static let fallbackURL = URL(string: "about:blank")!
    /// Normal
    public let capture: CaptureConfiguration
    public let privacy: PrivacyConfiguration
    /// Private
    private let sensitiveHeaders: Set<String>
    private let sensitiveJSONKeys: Set<String>
    private let sensitiveQueryParameters: Set<String>
    private let sensitiveFormFields: Set<String>

    // MARK: - INITIALIZER -
    public init(capture: CaptureConfiguration, privacy: PrivacyConfiguration) {
        self.capture = capture
        self.privacy = privacy
        self.sensitiveHeaders = Set(privacy.sensitiveHeaders)
        self.sensitiveJSONKeys = Set(privacy.sensitiveJSONKeys)
        self.sensitiveQueryParameters = Set(privacy.sensitiveQueryParameters)
        self.sensitiveFormFields = Set(privacy.sensitiveFormFields)
    }

    public func sanitize(request input: HTTPRequestInput) -> HTTPRequestRecord {
        let sanitizedURL = sanitize(url: input.url)
        let contentType = input.body?.contentType ?? input.headers.firstValue(for: "Content-Type")

        return HTTPRequestRecord(
            method: input.method,
            url: sanitizedURL.url,
            headers: sanitize(headers: input.headers),
            queryParameters: sanitizedURL.queryParameters,
            body: sanitize(body: input.body, inferredContentType: contentType),
            source: input.source
        )
    }

    public func sanitize(response input: HTTPResponseInput) -> HTTPResponseRecord {
        let contentType = input.body?.contentType ?? input.headers.firstValue(for: "Content-Type")

        return HTTPResponseRecord(
            statusCode: input.statusCode,
            headers: sanitize(headers: input.headers),
            body: sanitize(body: input.body,inferredContentType: contentType)
        )
    }

    public func sanitize(error input: NetworkErrorInput) -> NetworkErrorRecord {
        NetworkErrorRecord(
            kind: .transport,
            domain: sanitizeErrorDomain(input.domain),
            code: input.code
        )
    }

    public func cancellationError() -> NetworkErrorRecord {
        NetworkErrorRecord(kind: .cancellation, domain: "NSURLErrorDomain", code: -999)
    }

    public func sanitize(headers: HTTPHeaders) -> HTTPHeaders {
        guard capture.capturesHeaders else {
            return HTTPHeaders()
        }

        return HTTPHeaders(
            entries: headers.entries.map { entry in
                let key = normalized(entry.name)

                return HTTPHeaders.Entry(
                    name: entry.name,
                    value: sensitiveHeaders.contains(key) ? privacy.replacement : entry.value
                )
            }
        )
    }

    public func sanitize(url: URL) -> (url: URL, queryParameters: [QueryParameter]) {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return (Self.fallbackURL, [])
        }

        // User information and fragments are never needed for network
        // inspection and can contain credentials.
        components.user = nil
        components.password = nil
        components.fragment = nil

        let sanitizedItems = (components.queryItems ?? []).map { item -> URLQueryItem in
            let value = sensitiveQueryParameters.contains(normalized(item.name))
            ? privacy.replacement
            : item.value

            return URLQueryItem(name: item.name, value: value)
        }

        components.queryItems = sanitizedItems.isEmpty ? nil : sanitizedItems

        let redactedPathIndices = privacy.pathRules
            .filter { $0.matches(url) }
            .reduce(into: Set<Int>()) { result, rule in
                result.formUnion(rule.componentIndices)
            }

        if !redactedPathIndices.isEmpty {
            redactPath(in: &components, indices: redactedPathIndices)
        }

        let sanitizedURL = components.url ?? Self.fallbackURL
        let queryParameters = sanitizedItems.map {
            QueryParameter(name: $0.name, value: $0.value)
        }

        return (sanitizedURL, queryParameters)
    }

    public func sanitize(body: RawBody?, inferredContentType: String?) -> NetworkPayload? {
        guard let body else { return nil }

        let byteCount = body.data.count
        let contentType = normalizedContentType(body.contentType ?? inferredContentType)

        guard capture.capturesBodies else {
            return NetworkPayload(
                contentType: contentType,
                originalByteCount: byteCount,
                wasTruncated: false,
                content: .omitted(.captureDisabled)
            )
        }

        guard byteCount <= capture.maximumBodySize else {
            return NetworkPayload(
                contentType: contentType,
                originalByteCount: byteCount,
                wasTruncated: true,
                content: .omitted(.exceedsSizeLimit)
            )
        }

        guard !body.data.isEmpty else {
            return NetworkPayload(
                contentType: contentType, originalByteCount: 0, wasTruncated: false, content: .empty
            )
        }

        guard let contentType else {
            return NetworkPayload(
                contentType: nil,
                originalByteCount: byteCount,
                wasTruncated: false,
                content: .omitted(.missingContentType)
            )
        }

        if isJSON(contentType) {
            return sanitizeJSON(body.data, contentType: contentType)
        }

        if contentType == "application/x-www-form-urlencoded" {
            return sanitizeForm(body.data, contentType: contentType)
        }

        return NetworkPayload(
            contentType: contentType,
            originalByteCount: byteCount,
            wasTruncated: false,
            content: .omitted(.unsupportedContentType)
        )
    }

    private func sanitizeJSON(_ data: Data, contentType: String) -> NetworkPayload {
        do {
            let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
            let sanitized = redact(json: decoded)

            return NetworkPayload(
                contentType: contentType,
                originalByteCount: data.count,
                wasTruncated: false,
                content: .json(sanitized)
            )
        } catch {
            return NetworkPayload(
                contentType: contentType,
                originalByteCount: data.count,
                wasTruncated: false,
                content: .omitted(.malformedBody)
            )
        }
    }

    private func sanitizeForm(_ data: Data, contentType: String) -> NetworkPayload {
        guard let string = String(data: data, encoding: .utf8) else {
            return NetworkPayload(
                contentType: contentType,
                originalByteCount: data.count,
                wasTruncated: false,
                content: .omitted(.malformedBody)
            )
        }

        guard let fields = parseForm(string) else {
            return NetworkPayload(
                contentType: contentType,
                originalByteCount: data.count,
                wasTruncated: false,
                content: .omitted(.malformedBody)
            )
        }

        let sanitized = fields.map { field in
            FormField(
                name: field.name,
                value: sensitiveFormFields.contains(normalized(field.name)) ? privacy
                    .replacement : field.value
            )
        }

        return NetworkPayload(
            contentType: contentType,
            originalByteCount: data.count,
            wasTruncated: false,
            content: .formURLEncoded(sanitized)
        )
    }

    private func redact(json value: JSONValue) -> JSONValue {
        switch value {
        case let .object(object):
            var sanitized: [String: JSONValue] = [:]
            sanitized.reserveCapacity(object.count)

            for (key, nestedValue) in object {
                if sensitiveJSONKeys.contains(normalized(key)) {
                    sanitized[key] = .string(privacy.replacement)
                } else {
                    sanitized[key] = redact(json: nestedValue)
                }
            }

            return .object(sanitized)

        case let .array(values):
            return .array(values.map(redact(json:)))

        case .string, .integer, .number, .bool, .null:
            return value
        }
    }

    private func parseForm(_ string: String) -> [FormField]? {
        if string.isEmpty {
            return []
        }

        return string
            .split(separator: "&", omittingEmptySubsequences: false)
            .map(String.init)
            .reduce(into: Optional<[FormField]>([])) { result, component in
                guard var fields = result else { return }

                let pieces = component.split(
                    separator: "=",
                    maxSplits: 1,
                    omittingEmptySubsequences: false
                )

                guard let rawName = pieces.first,
                      let name = decodeFormComponent(String(rawName)) else {
                    result = nil
                    return
                }

                let value: String?

                if pieces.count == 2 {
                    guard let decoded = decodeFormComponent(String(pieces[1])) else {
                        result = nil
                        return
                    }

                    value = decoded
                } else {
                    value = nil
                }

                fields.append(FormField(name: name, value: value))
                result = fields
            }
    }

    private func decodeFormComponent(_ value: String) -> String? {
        value
            .replacingOccurrences(of: "+", with: " ")
            .removingPercentEncoding
    }

    private func redactPath(in components: inout URLComponents, indices: Set<Int>) {
        var encodedParts = components.percentEncodedPath
            .split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)

        var logicalIndex = 0

        for index in encodedParts.indices where !encodedParts[index].isEmpty {
            if indices.contains(logicalIndex) {
                encodedParts[index] = "%5BREDACTED%5D"
            }

            logicalIndex += 1
        }

        components.percentEncodedPath = encodedParts.joined(separator: "/")
    }

    private func sanitizeErrorDomain(_ domain: String) -> String {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              trimmed.count <= 128,
              trimmed.unicodeScalars.allSatisfy({
                  CharacterSet.alphanumerics
                      .union(CharacterSet(charactersIn: "._-"))
                      .contains($0)
              }) else {
            return "RedactedErrorDomain"
        }

        return trimmed
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedContentType(_ value: String?) -> String? {
        value?
            .split(separator: ";", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func isJSON(_ contentType: String) -> Bool {
        contentType == "application/json" || contentType.hasSuffix("+json")
    }
}
