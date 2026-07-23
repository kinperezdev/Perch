import SwiftUI

struct PrivacySettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var showWipeConfirm = false
    @State private var calendarRequested = false

    var body: some View {
        @Bindable var prefs = container.prefs
        Form {
            Section("What Perch can see") {
                Label("How long you've been actively working", systemImage: "clock")
                Label("How long you've been idle", systemImage: "moon.zzz")
                Label("Upcoming calendar events, only with permission", systemImage: "calendar")
                Label("How you respond to check ins", systemImage: "hand.tap")
            }
            .font(.perchRounded(12))
            Section("What stays private") {
                Label("Messages, documents, and passwords", systemImage: "xmark.circle")
                Label("Browser content and screen contents", systemImage: "xmark.circle")
                Label("Memory and AI stay on this Mac. Nothing is sent to the cloud", systemImage: "lock.circle")
            }
            .font(.perchRounded(12))
            .foregroundStyle(.secondary)
            Section("Permissions") {
                HStack {
                    Text("Calendar")
                    Spacer()
                    if container.calendar.isAuthorized {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button(calendarRequested ? "Open System Settings" : "Allow calendar access") {
                            requestCalendar()
                        }
                    }
                }
                HStack {
                    Text("Notifications")
                    Spacer()
                    if container.notifications.authorized {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Allow notifications") {
                            Task { await container.notifications.requestAuthorization() }
                        }
                    }
                }
                Toggle("Also deliver check ins as notifications", isOn: $prefs.notificationsMirror)
                Toggle("Allow Goodnight to put this Mac to sleep", isOn: $prefs.allowSleepAtGoodnight)
                Text("Calendar unlocks meeting prep and recovery check ins. Notifications catch check ins you miss when the bubble times out.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Your memory") {
                Text("Habit memory and brain memory stay in local files on this Mac. You can delete them at any time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Delete all memory", role: .destructive) {
                    showWipeConfirm = true
                }
                .confirmationDialog(
                    "Delete everything Perch has learned about your habits?",
                    isPresented: $showWipeConfirm
                ) {
                    Button("Delete memory", role: .destructive) {
                        container.memory.wipe()
                        container.brain.wipe(keepingUserName: container.prefs.userName)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func requestCalendar() {
        if calendarRequested {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
            if let url { NSWorkspace.shared.open(url) }
            return
        }
        calendarRequested = true
        Task { _ = await container.calendar.requestAccess() }
    }
}
