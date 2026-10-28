import Foundation
import GRDB

/// Service が必要とする操作だけを protocol に。
public protocol ExampleRepository: Sendable {
    func all() async throws -> [Example]
    func insert(_ example: Example) async throws -> Example
    func delete(id: Int64) async throws
}

public struct GRDBExampleRepository: ExampleRepository {
    private let db: AppDatabase
    public init(db: AppDatabase) { self.db = db }

    public func all() async throws -> [Example] {
        try await db.read { try Example.order(Column("createdAt").desc).fetchAll($0) }
    }

    public func insert(_ example: Example) async throws -> Example {
        try await db.write { try example.inserted($0) }
    }

    public func delete(id: Int64) async throws {
        _ = try await db.write { try Example.deleteOne($0, key: id) }
    }
}
