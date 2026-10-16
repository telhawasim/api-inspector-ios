//
//  JSONValue.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation

public enum JSONValue: Hashable, Codable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case integer(Int64)
    case number(Double)
    case bool(Bool)
    case null

    // MARK: - PROPERTIES -

    /// Computed
    public var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }

        return value
    }

    public subscript(key: String) -> JSONValue? {
        guard case let .object(object) = self else {
            return nil
        }

        return object[key]
    }

    // MARK: - INITIALIZER -
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError
                .dataCorruptedError(in: container, debugDescription: "Unsupported JSON value.")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .object(let dictionary):
            try container.encode(dictionary)
        case .array(let array):
            try container.encode(array)
        case .string(let string):
            try container.encode(string)
        case .integer(let int64):
            try container.encode(int64)
        case .number(let double):
            try container.encode(double)
        case .bool(let bool):
            try container.encode(bool)
        case .null:
            try container.encodeNil()
        }
    }
}
