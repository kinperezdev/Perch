import SwiftUI

struct ActiveAppsSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var apps: [AppEntry] = []
    @State private var searchText = ""

    private var filteredApps: [AppEntry] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        @Bindable var prefs = container.prefs
        Form {
            Section("Where Perch watches") {
                Picker("", selection: $prefs.focusAppMode) {
                    Text("All apps").tag(FocusAppMode.allApps)
                    Text("Specific apps only").tag(FocusAppMode.specificApps)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(
                    prefs.focusAppMode == .allApps
                        ? "Perch checks in no matter which app is in front."
                        : "Perch only checks in while one of the apps below is in front, like Terminal or Xcode while you're building."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if prefs.focusAppMode == .specificApps {
                Section("Active apps") {
                    if apps.isEmpty {
                        Text("No apps found on this Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        searchField
                        if filteredApps.isEmpty {
                            Text("No apps match \"\(searchText)\".")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredApps) { app in
                                appRow(app, prefs: prefs)
                            }
                        }
                    }
                    Button("Refresh app list") { refresh(selected: prefs.allowedAppBundleIDs) }
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .task { refresh(selected: prefs.allowedAppBundleIDs) }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search apps", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func appRow(_ app: AppEntry, prefs: PreferencesStore) -> some View {
        let isOn = prefs.allowedAppBundleIDs.contains(app.bundleID)
        return Toggle(isOn: Binding(
            get: { isOn },
            set: { newValue in
                var current = prefs.allowedAppBundleIDs
                if newValue { current.insert(app.bundleID) } else { current.remove(app.bundleID) }
                prefs.allowedAppBundleIDs = current
            }
        )) {
            HStack(spacing: 8) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(app.name)
            }
        }
    }

    private func refresh(selected: Set<String>) {
        apps = RunningAppsProvider.allAppsPickerList(selected: selected)
    }
}
