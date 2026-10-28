#if DEVELOPERID
    import Sparkle
    import SwiftUI

    /// DeveloperID（DMG 配布）レーンでのみコンパイルされる。App Store レーンでは Sparkle を含めない。
    struct SparkleCommands: Commands {
        private static let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        var body: some Commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { Self.updater.checkForUpdates(nil) }
            }
        }
    }
#endif
