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

    private let recorder: NetworkRecorder

    // MARK: - INITIALIZER -
    init() {
        let configuration = try! InspectorConfiguration(
            recordingEnabled: true,
            environment: .debug,
            capture: CaptureConfiguration(
                capturesHeaders: true,
                capturesBodies: true,
                maximumBodySize: 256_000,
            ),
            retention: RetentionConfiguration(
                maximumRecords: 100
            )
        )

        recorder = try! NetworkRecorder(configuration: configuration)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(recorder: recorder)
        }
    }
}
