//
//  InspectorConfiguration.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation

public enum InspectorEnvironment: String, Hashable, Codable, Sendable {
    case debug
    case testing
    case release

    // MARK: - PROPERTIES -

    /// Computed
    public static var current: Self {
        #if DEBUG
        .debug
        #else
        .release
        #endif
    }
}

public struct EndpointExclusion: Hashable, Codable, Sendable {

    public enum ValidationError: Error, Sendable {
        case emptyPathPrefix
        case emptyHost
    }

    // MARK: - PROPERTIES -

    /// Normal
    public let method: HTTPMethod?
    public let host: String?
    public let pathPrefix: String

    // MARK: - INITIALIZER -
    public init(method: HTTPMethod? = nil, host: String? = nil, pathPrefix: String) throws {
        guard !pathPrefix.isEmpty,
              pathPrefix.hasPrefix("/") else {
            throw ValidationError.emptyPathPrefix
        }

        let normalizedHost = host?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if host != nil, normalizedHost?.isEmpty != false {
            throw ValidationError.emptyHost
        }

        self.method = method
        self.host = normalizedHost
        self.pathPrefix = pathPrefix
    }

    private enum CodingKeys: String, CodingKey {
        case method
        case host
        case pathPrefix
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            method: container.decodeIfPresent(HTTPMethod.self, forKey: .method),
            host: container.decodeIfPresent(String.self, forKey: .host),
            pathPrefix: container.decode(String.self, forKey: .pathPrefix)
        )
    }

    public func matches(url: URL, method candidateMethod: HTTPMethod) -> Bool {
        if let method, method != candidateMethod {
            return false
        }

        if let host {
            guard Self.host(url.host, matches: host) else {
                return false
            }
        }

        return url.path.hasPrefix(pathPrefix)
    }

    private static func host(_ candidate: String?, matches excludedHost: String) -> Bool {
        guard let candidate = candidate?.lowercased() else {
            return false
        }

        return candidate == excludedHost || candidate.hasSuffix(".\(excludedHost)")
    }
}

public struct CaptureConfiguration: Hashable, Codable, Sendable {

    public enum ValidationError: Error, Sendable {
        case invalidMaximumBodySize
        case emptyIgnoredHost
    }

    // MARK: - PROPERTIES -

    /// Static
    public static let  maximumAllowedBodySize = 10 * 1_024 * 1_024
    /// Normal
    public let capturesHeaders: Bool
    public let capturesBodies: Bool
    public let maximumBodySize: Int
    public let ignoredHosts: [String]
    public let ignoredEndpoints: [EndpointExclusion]
    /// Default
    public static let `default` = CaptureConfiguration(
        uncheckedCapturesHeaders: true,
        capturesBodies: false,
        maximumBodySize: 256_000,
        ignoredHosts: [],
        ignoredEndpoints: []
    )

    // MARK: - INITIALIZER -
    public init(
        capturesHeaders: Bool = true,
        capturesBodies: Bool = false,
        maximumBodySize: Int = 256_000,
        ignoredHosts: [String] = [],
        ignoredEndpoints: [EndpointExclusion] = []
    ) throws {
        guard (1 ... Self.maximumAllowedBodySize).contains(maximumBodySize) else {
            throw ValidationError.invalidMaximumBodySize
        }

        let normalizedHosts = ignoredHosts.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        guard normalizedHosts.allSatisfy({ !$0.isEmpty }) else {
            throw ValidationError.emptyIgnoredHost
        }

        self.init(
            uncheckedCapturesHeaders: capturesHeaders,
            capturesBodies: capturesBodies,
            maximumBodySize: maximumBodySize,
            ignoredHosts: Array(Set(normalizedHosts)).sorted(),
            ignoredEndpoints: ignoredEndpoints
        )
    }

    private enum CodingKeys: String, CodingKey {
        case capturesHeaders
        case capturesBodies
        case maximumBodySize
        case ignoredHosts
        case ignoredEndpoints
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            capturesHeaders: container.decode(Bool.self, forKey: .capturesHeaders),
            capturesBodies: container.decode(Bool.self, forKey: .capturesBodies),
            maximumBodySize: container.decode(Int.self, forKey: .maximumBodySize),
            ignoredHosts: container.decode([String].self, forKey: .ignoredHosts),
            ignoredEndpoints: container.decode(
                [EndpointExclusion].self,
                forKey: .ignoredEndpoints
            )
        )
    }

    private init(
        uncheckedCapturesHeaders: Bool,
        capturesBodies: Bool,
        maximumBodySize: Int,
        ignoredHosts: [String],
        ignoredEndpoints: [EndpointExclusion]
    ) {
        self.capturesHeaders = uncheckedCapturesHeaders
        self.capturesBodies = capturesBodies
        self.maximumBodySize = maximumBodySize
        self.ignoredHosts = ignoredHosts
        self.ignoredEndpoints = ignoredEndpoints
    }

    public func permits(url: URL, method: HTTPMethod) -> Bool {
        if let host = url.host?.lowercased(),
           ignoredHosts.contains(where: {
               host == $0 || host.hasSuffix(".\($0)")
           }) {
            return false
        }

        return !ignoredEndpoints.contains {
            $0.matches(url: url, method: method)
        }
    }
}

public struct URLPathRedactionRule: Hashable, Codable, Sendable {

    public enum ValidationError: Error, Sendable {
        case emptyPathPrefix
        case emptyHost
        case emptyComponentIndices
        case invalidComponentIndex
    }

    // MARK: - PROPERTIES -

    /// Normal
    public let host: String?
    public let pathPrefix: String
    public let componentIndices: Set<Int>

    // MARK: - INITIALIZER -
    public init(host: String? = nil, pathPrefix: String, componentIndices: Set<Int>) throws {
        guard !pathPrefix.isEmpty,
              pathPrefix.hasPrefix("/") else {
            throw ValidationError.emptyPathPrefix
        }

        guard componentIndices.allSatisfy({ $0 >= 0 }) else {
            throw ValidationError.invalidComponentIndex
        }

        guard !componentIndices.isEmpty else {
            throw ValidationError.emptyComponentIndices
        }

        let normalizedHost = host?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if host != nil, normalizedHost?.isEmpty != false {
            throw ValidationError.emptyHost
        }

        self.host = normalizedHost
        self.pathPrefix = pathPrefix
        self.componentIndices = componentIndices
    }

    private enum CodingKeys: String, CodingKey {
        case host
        case pathPrefix
        case componentIndices
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            host: container.decodeIfPresent(String.self, forKey: .host),
            pathPrefix: container.decode(String.self, forKey: .pathPrefix),
            componentIndices: container.decode(Set<Int>.self, forKey: .componentIndices)
        )
    }

    public func matches(_ url: URL) -> Bool {
        if let host {
            guard let candidate = url.host?.lowercased(),
                  candidate == host || candidate.hasSuffix(".\(host)") else {
                return false
            }
        }

        return url.path.hasPrefix(pathPrefix)
    }
}

public struct PrivacyConfiguration: Hashable, Codable, Sendable {

    public enum ValidationError: Error, Sendable {
        case emptySensitiveName
        case emptyPlaceholder
    }

    // MARK: - PROPERTIES -

    /// Normal
    public let sensitiveHeaders: [String]
    public let sensitiveJSONKeys: [String]
    public let sensitiveQueryParameters: [String]
    public let sensitiveFormFields: [String]
    public let pathRules: [URLPathRedactionRule]
    public let replacement: String
    /// Default
    public static let `default` = PrivacyConfiguration(
        uncheckedSensitiveHeaders: [
            "authorization",
            "proxy-authorization",
            "cookie",
            "set-cookie",
            "x-api-key",
            "x-auth-token"
        ],
        sensitiveJSONKeys: [
            "password",
            "passcode",
            "token",
            "access_token",
            "refresh_token",
            "api_key",
            "secret",
            "client_secret",
            "session",
            "email"
        ],
        sensitiveQueryParameters: [
            "password",
            "passcode",
            "token",
            "access_token",
            "refresh_token",
            "api_key",
            "key",
            "secret",
            "client_secret",
            "session",
            "email"
        ],
        sensitiveFormFields: [
            "password",
            "passcode",
            "token",
            "access_token",
            "refresh_token",
            "api_key",
            "secret",
            "client_secret",
            "session",
            "email"
        ],
        pathRules: [],
        replacement: "[REDACTED]"
    )

    // MARK: - INITIALIZER -
    public init(
        sensitiveHeaders: [String] = PrivacyConfiguration.default.sensitiveHeaders,
        sensitiveJSONKeys: [String] = PrivacyConfiguration.default.sensitiveJSONKeys,
        sensitiveQueryParameters: [String] = PrivacyConfiguration.default.sensitiveQueryParameters,
        sensitiveFormFields: [String] = PrivacyConfiguration.default.sensitiveFormFields,
        pathRules: [URLPathRedactionRule] = [],
        replacement: String = "[REDACTED]"
    ) throws {
        let allNames = sensitiveHeaders
        + sensitiveJSONKeys
        + sensitiveQueryParameters
        + sensitiveFormFields

        guard allNames.allSatisfy({
            !$0.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }) else {
            throw ValidationError.emptySensitiveName
        }

        guard !replacement.isEmpty else {
            throw ValidationError.emptyPlaceholder
        }

        self.init(
            uncheckedSensitiveHeaders: sensitiveHeaders,
            sensitiveJSONKeys: sensitiveJSONKeys,
            sensitiveQueryParameters: sensitiveQueryParameters,
            sensitiveFormFields: sensitiveFormFields,
            pathRules: pathRules,
            replacement: replacement
        )
    }

    private enum CodingKeys: String, CodingKey {
        case sensitiveHeaders
        case sensitiveJSONKeys
        case sensitiveQueryParameters
        case sensitiveFormFields
        case pathRules
        case replacement
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            sensitiveHeaders: container.decode([String].self, forKey: .sensitiveHeaders),
            sensitiveJSONKeys: container.decode([String].self, forKey: .sensitiveJSONKeys),
            sensitiveQueryParameters: container.decode(
                [String].self,
                forKey: .sensitiveQueryParameters
            ),
            sensitiveFormFields: container.decode(
                [String].self,
                forKey: .sensitiveFormFields
            ),
            pathRules: container.decode([URLPathRedactionRule].self, forKey: .pathRules),
            replacement: container.decode(String.self, forKey: .replacement)
        )
    }

    private init(
        uncheckedSensitiveHeaders: [String],
        sensitiveJSONKeys: [String],
        sensitiveQueryParameters: [String],
        sensitiveFormFields: [String],
        pathRules: [URLPathRedactionRule],
        replacement: String
    ) {
        func normalize(_ values: [String]) -> [String] {
            Array(Set(values.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            })
            ).sorted()
        }

        self.sensitiveHeaders = normalize(uncheckedSensitiveHeaders)
        self.sensitiveJSONKeys = normalize(sensitiveJSONKeys)
        self.sensitiveQueryParameters = normalize(sensitiveQueryParameters)
        self.sensitiveFormFields = normalize(sensitiveFormFields)
        self.pathRules = pathRules
        self.replacement = replacement
    }
}

public struct RetentionConfiguration: Hashable, Codable, Sendable {

    public enum ValidationError: Error, Sendable {
        case invalidMaximumRecords
        case invalidRetentionPeriod
    }

    // MARK: - PROPERTIES -

    /// Static
    public static let maximumAllowedRecords = 100_000
    /// Normal
    public let maximumRecords: Int
    public let retentionPeriod: TimeInterval?
    /// Default
    public static let `default` = RetentionConfiguration(
        uncheckedMaximumRecords: 1_000,
        retentionPeriod: nil
    )

    // MARK: - INITIALIZER -
    public init(maximumRecords: Int = 1_000, retentionPeriod: TimeInterval? = nil) throws {
        guard (1 ... Self.maximumAllowedRecords).contains(maximumRecords) else {
            throw ValidationError.invalidMaximumRecords
        }

        if let retentionPeriod,
           !retentionPeriod.isFinite || retentionPeriod <= 0 {
            throw ValidationError.invalidRetentionPeriod
        }

        self.init(uncheckedMaximumRecords: maximumRecords, retentionPeriod: retentionPeriod)
    }

    private enum CodingKeys: String, CodingKey {
        case maximumRecords
        case retentionPeriod
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            maximumRecords: container.decode(Int.self, forKey: .maximumRecords),
            retentionPeriod: container.decodeIfPresent(
                TimeInterval.self,
                forKey: .retentionPeriod
            )
        )
    }

    private init(uncheckedMaximumRecords: Int, retentionPeriod: TimeInterval?) {
        self.maximumRecords = uncheckedMaximumRecords
        self.retentionPeriod = retentionPeriod
    }

    public func cutoff(relativeTo date: Date) -> Date? {
        retentionPeriod.map {
            date.addingTimeInterval(-$0)
        }
    }
}

public enum StorageConfiguration: Hashable, Codable, Sendable {
    case memory
    case sqlite(fileName: String)
}

public struct InspectorConfiguration: Hashable, Codable, Sendable {

    public enum ValidationError: Error, Sendable {
        case recordingNotAllowedInRelease
        case emptySQLiteFileName
    }

    // MARK: - PROPERTIES -

    /// Normal
    public let recordingEnabled: Bool
    public let environment: InspectorEnvironment
    public let allowsRecordingInRelease: Bool
    public let capture: CaptureConfiguration
    public let privacy: PrivacyConfiguration
    public let retention: RetentionConfiguration
    public let storage: StorageConfiguration
    public let debugOverlayEnabled: Bool
    /// Default
    public static let `default` = InspectorConfiguration(
        uncheckedRecordingEnabled: false,
        environment: .current,
        allowsRecordingInRelease: false,
        capture: .default,
        privacy: .default,
        retention: .default,
        storage: .memory,
        debugOverlayEnabled: false
    )

    // MARK: - INITIALIZER -
    public init(
        recordingEnabled: Bool = false,
        environment: InspectorEnvironment = .current,
        allowsRecordingInRelease: Bool = false,
        capture: CaptureConfiguration = .default,
        privacy: PrivacyConfiguration = .default,
        retention: RetentionConfiguration = .default,
        storage: StorageConfiguration = .memory,
        debugOverlayEnabled: Bool = false
    ) throws {
        if environment == .release,
           recordingEnabled,
           !allowsRecordingInRelease
        {
            throw ValidationError.recordingNotAllowedInRelease
        }

        if case let .sqlite(fileName) = storage,
           fileName.trimmingCharacters(
            in: .whitespacesAndNewlines
           ).isEmpty
        {
            throw ValidationError.emptySQLiteFileName
        }

        self.init(
            uncheckedRecordingEnabled: recordingEnabled,
            environment: environment,
            allowsRecordingInRelease: allowsRecordingInRelease,
            capture: capture,
            privacy: privacy,
            retention: retention,
            storage: storage,
            debugOverlayEnabled: debugOverlayEnabled
        )
    }

    private enum CodingKeys: String, CodingKey {
        case recordingEnabled
        case environment
        case allowsRecordingInRelease
        case capture
        case privacy
        case retention
        case storage
        case debugOverlayEnabled
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            recordingEnabled: container.decode(Bool.self, forKey: .recordingEnabled),
            environment: container.decode(InspectorEnvironment.self, forKey: .environment),
            allowsRecordingInRelease: container.decode(
                Bool.self,
                forKey: .allowsRecordingInRelease
            ),
            capture: container.decode(CaptureConfiguration.self, forKey: .capture),
            privacy: container.decode(PrivacyConfiguration.self, forKey: .privacy),
            retention: container.decode(RetentionConfiguration.self, forKey: .retention),
            storage: container.decode(StorageConfiguration.self, forKey: .storage),
            debugOverlayEnabled: container.decode(Bool.self, forKey: .debugOverlayEnabled)
        )
    }

    private init(
        uncheckedRecordingEnabled: Bool,
        environment: InspectorEnvironment,
        allowsRecordingInRelease: Bool,
        capture: CaptureConfiguration,
        privacy: PrivacyConfiguration,
        retention: RetentionConfiguration,
        storage: StorageConfiguration,
        debugOverlayEnabled: Bool
    ) {
        self.recordingEnabled = uncheckedRecordingEnabled
        self.environment = environment
        self.allowsRecordingInRelease = allowsRecordingInRelease
        self.capture = capture
        self.privacy = privacy
        self.retention = retention
        self.storage = storage
        self.debugOverlayEnabled = debugOverlayEnabled
    }
}
