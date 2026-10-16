//
//  APIInspector.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import APIInspectorCore

public enum APIInspector {

    public static let version = "0.1.0"

    public static func makeRecorder(
        configuration: InspectorConfiguration = .default,
        repository: (any RecordRepository)? = nil,
        timestamps: TimestampProvider = .system
    ) throws -> NetworkRecorder {
        try NetworkRecorder(
            configuration: configuration,
            repository: repository,
            timestamps: timestamps
        )
    }
}
