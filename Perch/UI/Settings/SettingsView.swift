import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container

    @State private var selection: String? = "General"
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var sky = SkyService()

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                Label("General", systemImage: "gearshape").tag("General")
                Label("Care", systemImage: "heart").tag("Care")
                Label("Vibe & Voice", systemImage: "face.smiling").tag("Vibe")
                Label("Active Apps", systemImage: "square.stack.3d.up").tag("ActiveApps")
                Label("Shortcut", systemImage: "keyboard").tag("Shortcut")
                Label("Privacy", systemImage: "lock.shield").tag("Privacy")
                Label("Plan", systemImage: "crown").tag("Plan")
            }
            .scrollContentBackground(.hidden)
            .background(sidebarBackground)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 2) {
                    Text("Perch")
                        .font(.perchRounded(11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Version \(appVersion)")
                        .font(.perchRounded(9))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch selection {
                case "General": GeneralSettingsView()
                case "Care": RemindersSettingsView()
                case "Vibe": PersonalitySettingsView()
                case "ActiveApps": ActiveAppsSettingsView()
                case "Shortcut": ShortcutSettingsView()
                case "Privacy": PrivacySettingsView()
                case "Plan": SubscriptionSettingsView()
                default: Text("Select a setting section")
                }
            }
            .scrollContentBackground(.hidden)
            .overlay(alignment: .top) { edgeFade(.top) }
            .overlay(alignment: .bottom) { edgeFade(.bottom) }
            .overlay { ScrollSparkOverlay() }
            .background(detailBackground)
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
        .preferredColorScheme(.dark)
        .task { sky.refreshIfNeeded() }
    }

    private var sidebarBackground: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(hex: 0x0B0B0E), Color(hex: 0x121216)],
                startPoint: .top,
                endPoint: .bottom
            )
            SkyTintOverlay(tint: sky.topTint, height: 140)
                .allowsHitTesting(false)
            SkyLayer(isNight: sky.isNight, condition: sky.condition)
                .frame(height: 160)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.55),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
    }

    private var detailBackground: some View {
        LinearGradient(
            colors: [Color(hex: 0x0B0B0E), Color(hex: 0x121216)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func edgeFade(_ edge: VerticalEdge) -> some View {
        LinearGradient(
            colors: edge == .top
                ? [Color(hex: 0x0B0B0E), Color(hex: 0x0B0B0E).opacity(0)]
                : [Color(hex: 0x0B0B0E).opacity(0), Color(hex: 0x0B0B0E)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 34)
        .allowsHitTesting(false)
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
