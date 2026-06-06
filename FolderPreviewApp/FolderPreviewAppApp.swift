import SwiftUI

@main
struct FolderPreviewAppApp: App {
    init() {
        PreviewSettings.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 780, height: 560)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}
