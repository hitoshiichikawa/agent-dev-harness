import Domain
import Foundation
import Observation

/// @Observable + @MainActor。Domain の Service を呼ぶだけ。GRDB を直接触らない。
@Observable @MainActor
final class ExampleViewModel {
    private(set) var items: [Example] = []
    private(set) var isLoading = false
    var error: String?
    var draftName = ""

    private let service: ExampleService

    init(service: ExampleService) {
        self.service = service
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do { items = try await service.list() } catch { self.error = "\(error)" }
    }

    func add() async {
        do {
            let added = try await service.add(name: draftName)
            items.insert(added, at: 0)
            draftName = ""
        } catch DomainError.validation(let msg) {
            error = msg
        } catch {
            self.error = "\(error)"
        }
    }

    func remove(_ item: Example) async {
        guard let id = item.id else { return }
        do {
            try await service.remove(id: id)
            items.removeAll { $0.id == id }
        } catch { self.error = "\(error)" }
    }
}
