//
//  HTTPModels.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation

public struct RequestID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {

    // MARK: - PROPERTIES -

    /// Normal
    public let rawValue: UUID
    /// Computed
    public var description: String {
        rawValue.uuidString
    }

    // MARK: - INITIALIZER -
    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    public init() {
        self.init(rawValue: UUID())
    }
}

public enum HTTPMethod: Hashable, Sendable, Codable, CustomStringConvertible {
    case get
    case head
    case post
    case put
    case patch
    case delete
    case options
    case trace
    case connect
    case custom(String)

    // MARK: - PROPERTIES -

    /// Computed
    public var rawValue: String {
        switch self {
        case .get: "GET"
        case .head: "HEAD"
        case .post: "POST"
        case .put: "PUT"
        case .patch: "PATCH"
        case .delete: "DELETE"
        case .options: "OPTIONS"
        case .trace: "TRACE"
        case .connect: "CONNECT"
        case let .custom(value): value
        }
    }

    public var description: String {
        rawValue
    }

    // MARK: - INITIALIZER -
    public init(_ value: String) {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        switch normalized {
        case "GET": self = .get
        case "HEAD": self = .head
        case "POST": self = .post
        case "PUT": self = .put
        case "PATCH": self = .patch
        case "DELETE": self = .delete
        case "OPTIONS": self = .options
        case "TRACE": self = .trace
        case "CONNECT": self = .connect
        default: self = .custom(normalized)
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(String.self))
    }

    // MARK: - ENCODE -
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct HTTPHeaders: Hashable, Codable, Sendable, ExpressibleByDictionaryLiteral {

    /// Helper Models
    public struct Entry: Hashable, Codable, Sendable {
        public let name: String
        public let value: String

        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }

    // MARK: - PROPERTIES -

    /// Normal
    public let entries: [Entry]
    /// Computed
    public var isEmpty: Bool {
        entries.isEmpty
    }

    // MARK: - INITIALIZER -
    public init(entries: [Entry] = []) {
        self.entries = entries
    }

    public init(_ fields: [String: String]) {
        self.entries = fields
            .map(Entry.init(name:value:))
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    public init(dictionaryLiteral elements: (String, String)...) {
        self.init(entries: elements.map {
            Entry(name: $0.0, value: $0.1)
        })
    }

    public func values(for name: String) -> [String] {
        entries.compactMap {
            $0.name.caseInsensitiveCompare(name) == .orderedSame ? $0.value : nil
        }
    }

    public func firstValue(for name: String) -> String? {
        values(for: name).first
    }

    public func contains(_ name: String) -> Bool {
        firstValue(for: name) != nil
    }
}

public struct QueryParameter: Hashable, Codable, Sendable {

    // MARK: - PROPERTIES -

    /// Normal
    public let name: String
    public let value: String?

    // MARK: - INITIALIZER -
    public init(name: String, value: String?) {
        self.name = name
        self.value = value
    }
}

public struct FormField: Hashable, Codable, Sendable {

    // MARK: - PROPERTIES -

    /// Normal
    public let name: String
    public let value: String?

    public init(name: String, value: String?) {
        self.name = name
        self.value = value
    }
}

public enum RequestSource: String, Hashable, Codable, Sendable {
    case application
    case replay
    case mock
}

public enum RequestState: String, Hashable, Codable, Sendable {
    case started
    case completed
    case failed
    case cancelled

    public var isTerminal: Bool {
        switch self {
        case .started:
            false
        case .completed, .failed, .cancelled:
            true
        }
    }
}
