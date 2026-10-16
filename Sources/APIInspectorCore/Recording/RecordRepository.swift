//
//  RecordRepository.swift
//  APIInspector
//
//  Created by Telha Wasim on 16/10/2026.
//

import Foundation

public protocol RecordRepository: Sendable {
    func insert(
        _ record: NetworkRecord,
        retention: RetentionConfiguration,
        relativeTo now: Date
    ) async throws

    func records(
        retention: RetentionConfiguration,
        relativeTo now: Date
    ) async throws -> [NetworkRecord]

    func clear() async throws
}

public actor InMemoryRecordRepository: RecordRepository {

    public enum RepositoryError: Error, Sendable {
        case nonTerminalRecord
    }

    // MARK: - PROPERTIES -

    /// Normal
    private var storage: [NetworkRecord] = []

    // MARK: - INITIALIZER -
    public init() { }

    public func insert(
        _ record: NetworkRecord,
        retention: RetentionConfiguration,
        relativeTo now: Date
    ) async throws {
        guard record.state.isTerminal else {
            throw RepositoryError.nonTerminalRecord
        }

        pruneExpired(cutoff: retention.cutoff(relativeTo: now))

        storage.removeAll { $0.id == record.id }
        storage.append(record)

        let overflow = storage.count - retention.maximumRecords

        if overflow > 0 {
            storage.removeFirst(overflow)
        }
    }

    public func records(
        retention: RetentionConfiguration,
        relativeTo now: Date
    ) async throws -> [NetworkRecord] {
        pruneExpired(cutoff: retention.cutoff(relativeTo: now))

        return storage
    }

    public func clear() {
        storage.removeAll(keepingCapacity: true)
    }

    private func pruneExpired(cutoff: Date?) {
        guard let cutoff else { return }

        storage.removeAll { record in
            let terminalDate = record.timing.endedAt ?? record.timing.startedAt
            return terminalDate < cutoff
        }
    }
}
