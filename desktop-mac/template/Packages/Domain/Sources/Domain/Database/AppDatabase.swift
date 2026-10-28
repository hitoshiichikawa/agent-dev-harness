import Foundation
import GRDB

/// DB 接続とマイグレーション。View / ViewModel からは触らない。
public final class AppDatabase: Sendable {
    private let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try migrator.migrate(writer)
    }

    /// サンドボックス内の Application Support に置く。
    public static func onDisk(appName: String) throws -> AppDatabase {
        let dir = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: appName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let pool = try DatabasePool(path: dir.appending(path: "db.sqlite").path)
        return try AppDatabase(pool)
    }

    /// テスト用。
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    public func read<T: Sendable>(_ block: @Sendable (Database) throws -> T) async throws -> T {
        try await writer.read(block)
    }

    public func write<T: Sendable>(_ block: @Sendable (Database) throws -> T) async throws -> T {
        try await writer.write(block)
    }

    /// 既存マイグレーションは書き換えない。追加は末尾に registerMigration。
    private var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        #if DEBUG
            m.eraseDatabaseOnSchemaChange = true
        #endif
        m.registerMigration("v1_create_example") { db in
            try db.create(table: "example") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }
        }
        return m
    }
}
