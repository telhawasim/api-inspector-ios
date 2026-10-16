//
//  ContentView.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import SwiftUI
import APIInspectorCore

struct ContentView: View {
    let recorder: NetworkRecorder

    @State private var status = "No sample transaction recorded."

    var body: some View {
        VStack(spacing: 20) {
            Text("APIInspector Phase 1")
                .font(.title.bold())

            Text(status)
                .multilineTextAlignment(.center)

            Button("Record sanitized sample") {
                Task {
                    await recordSample()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func recordSample() async {
        do {
            let request = HTTPRequestInput(
                method: .post,
                url: URL(
                    string:
                        "https://api.example.com/login"
                        + "?token=private-token"
                )!,
                headers: [
                    "Authorization": "Bearer private-token",
                    "Content-Type": "application/json"
                ],
                body: RawBody(
                    data: Data(
                        """
                        {
                          "email": "developer@example.com",
                          "password": "private-password"
                        }
                        """.utf8
                    ),
                    contentType: "application/json"
                )
            )

            guard let id = try await recorder.begin(request) else {
                status = "Recording is disabled or excluded."
                return
            }

            _ = try await recorder.complete(
                id,
                response: HTTPResponseInput(
                    statusCode: 200,
                    headers: [
                        "Content-Type": "application/json"
                    ],
                    body: RawBody(
                        data: Data(
                            #"{"access_token":"response-secret"}"#.utf8
                        ),
                        contentType: "application/json"
                    )
                )
            )

            let records = try await recorder.records()
            status = "Stored \(records.count) sanitized record(s)."
        } catch {
            status = "Recorder error: \(error)"
        }
    }
}
