import AppKit
import SwiftUI

struct ShortcutSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var isRecording = false

    var body: some View {
        Form {
            Section("Quick check in shortcut") {
                HStack {
                    Text("Press from anywhere to answer the latest check in")
                    Spacer()
                    ShortcutRecorderButton(isRecording: $isRecording) { keyCode, modifiers in
                        container.prefs.shortcutKeyCode = keyCode
                        container.prefs.shortcutModifiers = modifiers
                        container.shortcuts.registerFromPrefs()
                    } currentLabel: {
                        QuickAnswerShortcutManager.describe(
                            keyCode: container.prefs.shortcutKeyCode,
                            modifiers: container.prefs.shortcutModifiers
                        )
                    }
                }
                if !container.shortcuts.registrationOK {
                    Label(
                        "That combination could not be registered. It is probably taken by the system. Try another.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
                Text("Click the shortcut, then press any keys with at least one modifier. Esc cancels recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Reset to Control + Option + Space") {
                    container.prefs.shortcutKeyCode = 49
                    container.prefs.shortcutModifiers = PreferencesStore.defaultModifiers
                    container.shortcuts.registerFromPrefs()
                }
            }
            Section("What it does") {
                Label("A check in is showing: focuses it so keys 1, 2, 3 answer instantly", systemImage: "1.circle")
                Label("Nothing showing: brings back the last unanswered check in", systemImage: "arrow.uturn.left.circle")
                Label("Otherwise: a quiet status bubble with quick actions", systemImage: "sparkles")
            }
            .font(.perchRounded(11.5))
            .foregroundStyle(.secondary)
            Section {
                Button("Try it now") {
                    container.coordinator.quickAnswerPressed()
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutRecorderButton: View {
    @Binding var isRecording: Bool
    let onRecorded: (Int, UInt) -> Void
    let currentLabel: () -> String

    @State private var keyMonitor: Any?
    @State private var flagsMonitor: Any?
    @State private var liveModifiers: UInt = 0

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(labelText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(minWidth: 150)
        }
        .buttonStyle(.bordered)
        .tint(isRecording ? .orange : nil)
        .onDisappear { stopRecording() }
    }

    private var labelText: String {
        guard isRecording else { return currentLabel() }
        let symbols = QuickAnswerShortcutManager.modifierSymbols(liveModifiers)
        return symbols.isEmpty ? "Press shortcut..." : symbols + "..."
    }

    private func startRecording() {
        ShortcutRecordingCoordinator.shared.begin(stop: stopRecording)
        isRecording = true
        liveModifiers = 0
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            liveModifiers = event.modifierFlags
                .intersection([.command, .option, .control, .shift])
                .rawValue
            return event
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == 53 && flags.isEmpty {
                stopRecording()
                return nil
            }
            guard !flags.isEmpty else { return nil }
            onRecorded(Int(event.keyCode), flags.rawValue)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        liveModifiers = 0
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        keyMonitor = nil
        flagsMonitor = nil
        ShortcutRecordingCoordinator.shared.end()
    }
}

@MainActor
private final class ShortcutRecordingCoordinator {
    static let shared = ShortcutRecordingCoordinator()
    private var stopActive: (() -> Void)?

    func begin(stop: @escaping () -> Void) {
        stopActive?()
        stopActive = stop
    }

    func end() {
        stopActive = nil
    }
}
