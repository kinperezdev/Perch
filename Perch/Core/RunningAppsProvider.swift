import AppKit
import UniformTypeIdentifiers

struct AppEntry: Identifiable, Hashable {
    let bundleID: String
    let name: String
    var id: String { bundleID }

    @MainActor
    var icon: NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSWorkspace.shared.icon(for: .application)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

@MainActor
enum RunningAppsProvider {
    /// Currently running regular (Dock-visible) apps, excluding Perch itself.
    static func runningApps() -> [AppEntry] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier else { return nil }
                return AppEntry(bundleID: bundleID, name: app.localizedName ?? bundleID)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Resolves a bundle ID to a display name even if the app isn't currently running,
    /// so previously chosen apps still show up correctly in the picker.
    static func resolve(bundleID: String) -> AppEntry {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: url) {
            let name = (bundle.infoDictionary?["CFBundleName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? bundleID
            return AppEntry(bundleID: bundleID, name: name)
        }
        return AppEntry(bundleID: bundleID, name: bundleID)
    }

    /// Running apps plus any already-selected apps that aren't currently running,
    /// so the picker never silently drops a saved selection.
    static func pickerList(selected: Set<String>) -> [AppEntry] {
        var byID: [String: AppEntry] = [:]
        for entry in runningApps() { byID[entry.bundleID] = entry }
        for bundleID in selected where byID[bundleID] == nil {
            byID[bundleID] = resolve(bundleID: bundleID)
        }
        return byID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
