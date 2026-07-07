import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container

    @State private var selection: String? = "General"
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                Label("General", systemImage: "gearshape").tag("General")
                Label("Care", systemImage: "heart").tag("Care")
                Label("Vibe & Voice", systemImage: "face.smiling").tag("Vibe")
                Label("Shortcut", systemImage: "keyboard").tag("Shortcut")
                Label("Privacy", systemImage: "lock.shield").tag("Privacy")
                Label("Plan", systemImage: "crown").tag("Plan")
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch selection {
                case "General": GeneralSettingsView()
                case "Care": RemindersSettingsView()
                case "Vibe": PersonalitySettingsView()
                case "Shortcut": ShortcutSettingsView()
                case "Privacy": PrivacySettingsView()
                case "Plan": SubscriptionSettingsView()
                default: Text("Select a setting section")
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation {
                            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .help("Show or hide the sidebar")
                }
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}


func timeOfDayBinding(_ source: Binding<Int>) -> Binding<Date> {
    Binding<Date>(
        get: {
            Calendar.current.date(
                bySettingHour: source.wrappedValue / 60,
                minute: source.wrappedValue % 60,
                second: 0,
                of: Date()
            ) ?? Date()
        },
        set: { source.wrappedValue = minutesOfDay($0) }
    )
}
