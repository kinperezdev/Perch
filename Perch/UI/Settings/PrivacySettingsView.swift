import SwiftUI

struct PrivacySettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var showWipeConfirm = false
    @State private var calendarRequested = false
    @State private var showOnlineWarning = false

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
            Section("What Perch never touches") {
                Label("Messages, documents, and passwords", systemImage: "xmark.circle")
                Label("Browser content and screen contents", systemImage: "xmark.circle")
                Label("Anything leaving this Mac. Memory and AI stay on device", systemImage: "xmark.circle")
            }
            .font(.perchRounded(12))
            .foregroundStyle(.secondary)
            Section("AI Privacy") {
                Toggle("Enable Online Cloud AI (OpenAI)", isOn: Binding(
                    get: { prefs.onlineMode },
                    set: { newValue in
                        if newValue {
                            showOnlineWarning = true
                        } else {
                            prefs.onlineMode = false
                        }
                    }
                ))
                .alert("Enable Online Cloud AI?", isPresented: $showOnlineWarning) {
                    Button("Cancel", role: .cancel) {
                        prefs.onlineMode = false
                    }
                    Button("Enable") {
                        prefs.onlineMode = true
                    }
                } message: {
                    Text("If you enable this, your private chat messages and thoughts will be sent over the internet to OpenAI servers instead of staying 100% private on your Mac. You must also provide an API key, which will incur real-world costs.")
                }
                if prefs.onlineMode {
                    VStack(spacing: 12) {
                        SecureField("OpenAI API Key (sk-...)", text: $prefs.openAiApiKey)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Gemini API Key", text: $prefs.geminiApiKey)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Anthropic API Key", text: $prefs.anthropicApiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 4)
                    
                    Text("Keys are stored securely in your Mac's Keychain.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("By default, Perch runs entirely on-device. Turning this on sacrifices privacy for slightly smarter reasoning.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
            }
            Section("Your memory") {
                Text("Habit memory lives in a local JSON file you can delete at any time. Chat conversations are never saved.")
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
                        container.chat.clear()
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
