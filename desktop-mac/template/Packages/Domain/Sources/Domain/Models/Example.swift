import Foundation
import GRDB

/// モデルは struct。GRDB の Record プロトコルで DB と往復する。
public struct Example: Identifiable, Codable, Equatable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "example"

    public var id: Int64?
    public var name: String
    public var createdAt: Date

    public init(id: Int64? = nil, name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
