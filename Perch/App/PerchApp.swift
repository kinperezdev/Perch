import SwiftUI

@main
struct PerchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(AppContainer.shared)
                .environment(\.dynamicTypeSize, .medium)
        } label: {
            Image(systemName: "face.smiling.fill")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(AppContainer.shared)
        }
    }
}
