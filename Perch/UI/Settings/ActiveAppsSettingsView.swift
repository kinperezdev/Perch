import SwiftUI

struct ActiveAppsSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var apps: [AppEntry] = []
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var filteredApps: [AppEntry] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        @Bindable var prefs = container.prefs
        Form {
            Section {
                Text(
                    prefs.focusAppMode == .allApps
                        ? "Perch checks in no matter which app is in front."
                        : "Perch only checks in while one of the apps below is in front, like Terminal or Xcode while you're building."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                HStack {
                    Text("Where Perch watches")
                    Spacer()
                    Toggle("All apps", isOn: Binding(
                        get: { prefs.focusAppMode == .allApps },
                        set: { prefs.focusAppMode = $0 ? .allApps : .specificApps }
                    ))
                    .font(.caption)
                }
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
                .focused($searchFocused)
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
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
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
