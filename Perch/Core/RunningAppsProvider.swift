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
    /// Every installed app found in the usual Applications folders, running or
    /// not, so the picker isn't limited to whatever happens to be open right now.
    static func allInstalledApps() -> [AppEntry] {
        let directories = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications",
        ]
        let ownBundleID = Bundle.main.bundleIdentifier
        var byID: [String: AppEntry] = [:]
        for directory in directories {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let url = URL(fileURLWithPath: directory).appendingPathComponent(item)
                guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier, bundleID != ownBundleID else { continue }
                let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                    ?? item.replacingOccurrences(of: ".app", with: "")
                byID[bundleID] = AppEntry(bundleID: bundleID, name: name)
            }
        }
        return byID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

    /// Every installed app plus any already-selected apps not found in the
    /// usual Applications folders, so the picker never silently drops a saved
    /// selection while still letting you pick apps that aren't open yet.
    static func allAppsPickerList(selected: Set<String>) -> [AppEntry] {
        var byID: [String: AppEntry] = [:]
        for entry in allInstalledApps() { byID[entry.bundleID] = entry }
        for bundleID in selected where byID[bundleID] == nil {
            byID[bundleID] = resolve(bundleID: bundleID)
        }
        return byID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
