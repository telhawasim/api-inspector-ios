//
//  APIInspectorDemoApp.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import SwiftUI
import APIInspectorCore

@main
struct APIInspectorDemoApp: App {

    private let recorder: NetworkRecorder?

    // MARK: - INITIALIZER -
    init() {
        guard let capture = try? CaptureConfiguration(
            capturesHeaders: true,
            capturesBodies: true,
            maximumBodySize: 256_000
        ),
        let retention = try? RetentionConfiguration(maximumRecords: 100),
        let configuration = try? InspectorConfiguration(
            recordingEnabled: true,
            environment: .debug,
            capture: capture,
            retention: retention
        ) else {
            recorder = nil
            return
        }

        recorder = try? NetworkRecorder(configuration: configuration)
    }

    var body: some Scene {
        WindowGroup {
            if let recorder {
                ContentView(recorder: recorder)
            } else {
                Text("Unable to create the APIInspector recorder.")
                    .padding()
            }
        }
    }
}
