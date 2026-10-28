import Domain
import SwiftUI

/// @main。DI と WindowGroup だけ。ロジックを置かない。
@main
struct MyApp: App {
    private let container: AppContainer

    init() {
        do {
            container = try AppContainer(db: .onDisk(appName: "MyApp"))
        } catch {
            fatalError("database init failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ExampleView(viewModel: ExampleViewModel(service: container.exampleService))
        }
        .commands {
            #if DEVELOPERID
                SparkleCommands()
            #endif
        }
        Settings {
            SettingsView()
        }
    }
}

/// 依存の組み立て。Service を増やすときはここに足す。
struct AppContainer {
    let db: AppDatabase
    let exampleService: ExampleService

    init(db: AppDatabase) {
        self.db = db
        exampleService = ExampleService(repo: GRDBExampleRepository(db: db))
    }
}
