import SwiftUI

/// 設定は @AppStorage。キーは SettingsKeys に定数化。
struct SettingsView: View {
    @AppStorage(SettingsKeys.checkForUpdates) private var checkForUpdates = true

    var body: some View {
        Form {
            Toggle("Check for updates automatically", isOn: $checkForUpdates)
        }
        .padding()
        .frame(width: 360)
    }
}

enum SettingsKeys {
    static let checkForUpdates = "settings.checkForUpdates"
}
