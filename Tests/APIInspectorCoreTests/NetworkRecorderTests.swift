//
//  NetworkRecorderTests.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation
import Testing
@testable import APIInspectorCore

@Suite("Network recorder")
struct NetworkRecorderTests {
    @Test
    func recordsCompletedRequest() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )

        let id = try #require(
            try await recorder.begin(TestFixtures.request())
        )

        let record = try await recorder.complete(
            id,
            response: TestFixtures.response
        )

        #expect(record.state == .completed)
        #expect(record.response?.statusCode == 200)
        #expect(await recorder.activeRequestCount() == 0)
        #expect(try await recorder.records() == [record])
    }

    @Test
    func serverErrorsAreCompletedResponses() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )

        let id = try #require(
            try await recorder.begin(TestFixtures.request())
        )

        let record = try await recorder.complete(
            id,
            response: HTTPResponseInput(statusCode: 500)
        )

        #expect(record.state == .completed)
        #expect(record.response?.isServerError == true)
        #expect(record.error == nil)
    }

    @Test
    func cancellationProducesCancellationRecord() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )

        let id = try #require(
            try await recorder.begin(TestFixtures.request())
        )

        let record = try await recorder.cancel(id)

        #expect(record.state == .cancelled)
        #expect(record.error?.kind == .cancellation)
    }

    @Test
    func duplicateCompletionIsRejected() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )

        let id = try #require(
            try await recorder.begin(TestFixtures.request())
        )

        _ = try await recorder.complete(
            id,
            response: TestFixtures.response
        )

        await #expect(
            throws: RequestTracker.Error.self
        ) {
            try await recorder.complete(
                id,
                response: TestFixtures.response
            )
        }
    }

    @Test
    func disabledRecorderDoesNotAcceptRequests() async throws {
        let recorder = try NetworkRecorder(
            configuration: .default
        )

        let id = try await recorder.begin(
            TestFixtures.request()
        )

        #expect(id == nil)
        #expect(await recorder.activeRequestCount() == 0)
    }

    @Test
    func stopRejectsNewRequestsButAllowsInflightCompletion()
        async throws
    {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )

        let existingID = try #require(
            try await recorder.begin(TestFixtures.request())
        )

        await recorder.stop()

        let ignoredID = try await recorder.begin(
            TestFixtures.request(index: 1)
        )

        let completed = try await recorder.complete(
            existingID,
            response: TestFixtures.response
        )

        #expect(ignoredID == nil)
        #expect(completed.state == .completed)
    }

    @Test
    func retentionLimitKeepsNewestRecords() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration(
                maximumRecords: 10
            )
        )

        for index in 0 ..< 30 {
            let id = RequestID(
                rawValue: UUID(
                    uuidString: String(
                        format:
                            "00000000-0000-0000-0000-%012d",
                        index + 1
                    )
                )!
            )

            let accepted = try await recorder.begin(
                TestFixtures.request(index: index),
                id: id
            )

            #expect(accepted == id)

            _ = try await recorder.complete(
                id,
                response: TestFixtures.response
            )
        }

        let records = try await recorder.records()

        #expect(records.count == 10)
        #expect(
            records.first?.request.url.path
                == "/items/20"
        )
        #expect(
            records.last?.request.url.path
                == "/items/29"
        )
    }

    @Test
    func concurrentRequestsRemainIndependent() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration(
                maximumRecords: 500
            )
        )

        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 250 {
                group.addTask {
                    do {
                        guard let id = try await recorder.begin(
                            TestFixtures.request(index: index)
                        ) else {
                            Issue.record(
                                "Request was unexpectedly ignored"
                            )
                            return
                        }

                        _ = try await recorder.complete(
                            id,
                            response: TestFixtures.response
                        )
                    } catch {
                        Issue.record(
                            "Unexpected recorder error: \(error)"
                        )
                    }
                }
            }
        }

        #expect(await recorder.activeRequestCount() == 0)
        #expect(try await recorder.records().count == 250)
    }

    @Test
    func subscribersReceiveIndependentEventStreams()
        async throws
    {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )
        let firstStream = try await recorder.events(
            bufferingNewest: 8
        )
        let secondStream = try await recorder.events(
            bufferingNewest: 8
        )

        let id = try #require(
            try await recorder.begin(TestFixtures.request())
        )
        _ = try await recorder.complete(
            id,
            response: TestFixtures.response
        )

        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()

        let firstStart = await firstIterator.next()
        let firstCompletion = await firstIterator.next()
        let secondStart = await secondIterator.next()
        let secondCompletion = await secondIterator.next()

        guard case .requestStarted? = firstStart,
              case .recordStored? = firstCompletion,
              case .requestStarted? = secondStart,
              case .recordStored? = secondCompletion
        else {
            Issue.record(
                "Both subscribers should receive both events."
            )
            return
        }
    }

    @Test
    func boundedSubscriberKeepsNewestEvent() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )
        let stream = try await recorder.events(
            bufferingNewest: 1
        )

        let firstID = try #require(
            try await recorder.begin(
                TestFixtures.request(index: 1)
            )
        )
        _ = try await recorder.complete(
            firstID,
            response: TestFixtures.response
        )

        let secondID = try #require(
            try await recorder.begin(
                TestFixtures.request(index: 2)
            )
        )
        let finalRecord = try await recorder.complete(
            secondID,
            response: TestFixtures.response
        )

        var iterator = stream.makeAsyncIterator()
        let bufferedEvent = await iterator.next()

        guard case let .recordStored(record)? = bufferedEvent else {
            Issue.record("Expected newest buffered event")
            return
        }

        #expect(record.id == finalRecord.id)
    }

    @Test
    func rawSecretsNeverReachEventsOrRepository() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )
        let events = try await recorder.events(
            bufferingNewest: 4
        )

        let request = HTTPRequestInput(
            method: .post,
            url: TestFixtures.url(
                "https://example.com/login?token=url-secret"
            ),
            headers: [
                "Authorization": "Bearer header-secret",
                "Content-Type": "application/json"
            ],
            body: RawBody(
                data: Data(
                    """
                    {
                      "email": "person@example.com",
                      "password": "body-secret"
                    }
                    """.utf8
                ),
                contentType: "application/json"
            )
        )

        let id = try #require(
            try await recorder.begin(request)
        )
        _ = try await recorder.complete(
            id,
            response: TestFixtures.response
        )

        var iterator = events.makeAsyncIterator()
        let startEvent = await iterator.next()
        let storedEvent = await iterator.next()

        let eventDescription = String(
            describing: [startEvent, storedEvent]
        )
        let encodedRecords = try JSONEncoder().encode(
            await recorder.records()
        )
        let persistedDescription = String(
            decoding: encodedRecords,
            as: UTF8.self
        )
        let combined = eventDescription + persistedDescription

        #expect(combined.contains("url-secret") == false)
        #expect(combined.contains("header-secret") == false)
        #expect(combined.contains("body-secret") == false)
        #expect(combined.contains("person@example.com") == false)
    }

    @Test
    func transportFailureProducesFailedRecord() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )
        let id = try #require(
            try await recorder.begin(TestFixtures.request())
        )

        let record = try await recorder.fail(
            id,
            error: NetworkErrorInput(
                domain: "NSURLErrorDomain",
                code: -1_001
            )
        )

        #expect(record.state == .failed)
        #expect(record.response == nil)
        #expect(record.error?.kind == .transport)
        #expect(record.error?.code == -1_001)
    }

    @Test
    func recordsCompletedTransactionInput() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )
        let startedAt = Date(timeIntervalSince1970: 100)
        let endedAt = Date(timeIntervalSince1970: 101)

        let record = try #require(
            try await recorder.record(
                NetworkTransactionInput(
                    request: TestFixtures.request(),
                    outcome: .response(TestFixtures.response),
                    startedAt: startedAt,
                    endedAt: endedAt
                )
            )
        )

        #expect(record.timing.startedAt == startedAt)
        #expect(record.timing.endedAt == endedAt)
        #expect(record.timing.duration == 1)
    }

    @Test
    func excludedHostNeverEntersTrackingOrEvents() async throws {
        let configuration = try InspectorConfiguration(
            recordingEnabled: true,
            environment: .testing,
            capture: CaptureConfiguration(
                ignoredHosts: ["api.example.com"]
            )
        )
        let recorder = try NetworkRecorder(configuration: configuration)
        let id = try await recorder.begin(TestFixtures.request())

        #expect(id == nil)
        #expect(await recorder.activeRequestCount() == 0)
        #expect(try await recorder.records().isEmpty)
    }

    @Test
    func eventBufferCapacityMustBePositive() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )

        await #expect(throws: EventSubscriptionError.self) {
            try await recorder.events(bufferingNewest: 0)
        }
    }

    @Test
    func simultaneousTerminalCallbacksStoreExactlyOneRecord() async throws {
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration()
        )
        let id = try #require(
            try await recorder.begin(TestFixtures.request())
        )

        let successCount = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                (try? await recorder.complete(
                    id,
                    response: TestFixtures.response
                )) != nil
            }
            group.addTask {
                (try? await recorder.fail(
                    id,
                    error: NetworkErrorInput(domain: "Test", code: 1)
                )) != nil
            }
            group.addTask {
                (try? await recorder.cancel(id)) != nil
            }

            var successes = 0
            for await didSucceed in group where didSucceed {
                successes += 1
            }
            return successes
        }

        #expect(successCount == 1)
        #expect(try await recorder.records().count == 1)
        #expect(await recorder.activeRequestCount() == 0)
    }

    @Test
    func retentionPeriodRemovesExpiredRecords() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        let configuration = try InspectorConfiguration(
            recordingEnabled: true,
            environment: .testing,
            retention: RetentionConfiguration(
                maximumRecords: 10,
                retentionPeriod: 60
            )
        )
        let recorder = try NetworkRecorder(
            configuration: configuration,
            timestamps: TimestampProvider { now }
        )
        let id = try #require(
            try await recorder.begin(
                TestFixtures.request(),
                startedAt: now.addingTimeInterval(-121)
            )
        )
        _ = try await recorder.complete(
            id,
            response: TestFixtures.response,
            endedAt: now.addingTimeInterval(-120)
        )

        #expect(try await recorder.records().isEmpty)
    }

    @Test
    func clearWaitsForInProgressFinalization() async throws {
        let repository = BlockingRecordRepository()
        let recorder = try NetworkRecorder(
            configuration: TestFixtures.configuration(),
            repository: repository
        )
        let id = try #require(
            try await recorder.begin(TestFixtures.request())
        )

        let completion = Task {
            try await recorder.complete(
                id,
                response: TestFixtures.response
            )
        }
        await repository.waitUntilInsertStarts()

        let clearing = Task {
            try await recorder.clear()
        }
        await Task.yield()
        await repository.releaseInsert()

        _ = try await completion.value
        try await clearing.value

        #expect(try await recorder.records().isEmpty)
    }
}
