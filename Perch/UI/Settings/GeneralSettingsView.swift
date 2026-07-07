import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var body: some View {
        @Bindable var prefs = container.prefs
        Form {
            Section("You") {
                TextField("Your name", text: $prefs.userName, prompt: Text("How should I call you?"))
            }
            Section("Your rhythm") {
                DatePicker("Work starts", selection: timeOfDayBinding($prefs.workStartMinutes), displayedComponents: .hourAndMinute)
                DatePicker("Work ends", selection: timeOfDayBinding($prefs.workEndMinutes), displayedComponents: .hourAndMinute)
                DatePicker("Usual breakfast", selection: timeOfDayBinding($prefs.breakfastMinutes), displayedComponents: .hourAndMinute)
                DatePicker("Usual lunch", selection: timeOfDayBinding($prefs.lunchMinutes), displayedComponents: .hourAndMinute)
                DatePicker("Usual dinner", selection: timeOfDayBinding($prefs.dinnerMinutes), displayedComponents: .hourAndMinute)
                DatePicker("Usual shower", selection: timeOfDayBinding($prefs.showerMinutes), displayedComponents: .hourAndMinute)
                Text("These times shape my check ins: meals and shower near their windows, overwork and wind down around your work hours.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Quiet hours") {
                DatePicker("Quiet from", selection: timeOfDayBinding($prefs.quietStartMinutes), displayedComponents: .hourAndMinute)
                DatePicker("Quiet until", selection: timeOfDayBinding($prefs.quietEndMinutes), displayedComponents: .hourAndMinute)
                Text("No bubbles, no voice, no interruptions inside quiet hours.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("System") {
                Toggle("Launch Perch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enable in
                        updateLoginItem(enable)
                    }
                if let loginItemError {
                    Text(loginItemError).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Demo") {
                Toggle("Demo mode (time runs 60x faster)", isOn: $prefs.demoMode)
                Text("For trying Perch without waiting hours. One real second counts as one minute of focus.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Setup") {
                Button("Run setup again") {
                    WindowPresenter.shared.showOnboarding(container)
                }
                Text("Reopens the first run walkthrough: personality, rhythm, care preferences, permissions, and shortcut.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func updateLoginItem(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "Could not update login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
