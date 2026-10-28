import Foundation

/// ビジネスロジック。UI も SQL も知らない。
public struct ExampleService: Sendable {
    private let repo: any ExampleRepository
    public init(repo: any ExampleRepository) { self.repo = repo }

    public func list() async throws -> [Example] {
        try await repo.all()
    }

    public func add(name: String) async throws -> Example {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.validation("name is empty") }
        return try await repo.insert(Example(name: trimmed))
    }

    public func remove(id: Int64) async throws {
        try await repo.delete(id: id)
    }
}

public enum DomainError: Error, Equatable, Sendable {
    case validation(String)
    case notFound
}
