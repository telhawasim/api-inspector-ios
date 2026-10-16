import Foundation
@testable import APIInspectorCore

actor BlockingRecordRepository: RecordRepository {
    private var storage: [NetworkRecord] = []
    private var insertStarted = false
    private var insertReleased = false
    private var insertStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var insertReleaseWaiters: [CheckedContinuation<Void, Never>] = []

    func insert(
        _ record: NetworkRecord,
        retention: RetentionConfiguration,
        relativeTo now: Date
    ) async throws {
        insertStarted = true

        let startWaiters = insertStartWaiters
        insertStartWaiters.removeAll()
        for waiter in startWaiters {
            waiter.resume()
        }

        if !insertReleased {
            await withCheckedContinuation { continuation in
                insertReleaseWaiters.append(continuation)
            }
        }

        storage.append(record)
    }

    func records(
        retention: RetentionConfiguration,
        relativeTo now: Date
    ) -> [NetworkRecord] {
        storage
    }

    func clear() {
        storage.removeAll()
    }

    func waitUntilInsertStarts() async {
        guard !insertStarted else {
            return
        }

        await withCheckedContinuation { continuation in
            insertStartWaiters.append(continuation)
        }
    }

    func releaseInsert() {
        insertReleased = true
        let waiters = insertReleaseWaiters
        insertReleaseWaiters.removeAll()

        for waiter in waiters {
            waiter.resume()
        }
    }
}
