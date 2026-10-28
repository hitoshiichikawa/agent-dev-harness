import Testing
@testable import Domain

/// Swift Testing。in-memory の実 SQLite で回す。モックしない。
@Suite struct ExampleServiceTests {
    private func makeService() throws -> ExampleService {
        ExampleService(repo: GRDBExampleRepository(db: try AppDatabase.inMemory()))
    }

    @Test func addTrimsAndPersists() async throws {
        let svc = try makeService()
        let added = try await svc.add(name: "  hello  ")
        #expect(added.name == "hello")
        #expect(added.id != nil)
        let all = try await svc.list()
        #expect(all.count == 1)
    }

    @Test func addRejectsBlank() async throws {
        let svc = try makeService()
        await #expect(throws: DomainError.validation("name is empty")) {
            try await svc.add(name: "   ")
        }
    }

    @Test func removeDeletes() async throws {
        let svc = try makeService()
        let added = try await svc.add(name: "x")
        try await svc.remove(id: added.id!)
        #expect(try await svc.list().isEmpty)
    }
}
