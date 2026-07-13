import AppIntents

/// System integration: Perch actions in Spotlight, Shortcuts, and Siri.
struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Log a glass of water in Perch.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await AppContainer.shared.memory.logWater()
        return .result(dialog: "Logged. Stay hydrated.")
    }
}

struct CheckOnMeIntent: AppIntent {
    static let title: LocalizedStringResource = "Check On Me"
    static let description = IntentDescription("Ask Perch for a wellbeing check in right now.")

    func perform() async throws -> some IntentResult {
        await AppContainer.shared.engine.forceCheckIn()
        return .result()
    }
}

struct TakeBreakIntent: AppIntent {
    static let title: LocalizedStringResource = "I Took a Break"
    static let description = IntentDescription("Tell Perch you stepped away for a real break.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await AppContainer.shared.tracker.creditBreak()
        return .result(dialog: "Nice reset. Back to it.")
    }
}

struct PerchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: ["Log water in \(.applicationName)"],
            shortTitle: "Log water",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: CheckOnMeIntent(),
            phrases: ["Check on me in \(.applicationName)"],
            shortTitle: "Check on me",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: TakeBreakIntent(),
            phrases: ["I took a break in \(.applicationName)"],
            shortTitle: "Took a break",
            systemImageName: "figure.walk"
        )
    }
}
