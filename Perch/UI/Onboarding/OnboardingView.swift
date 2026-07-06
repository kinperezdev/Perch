import ServiceManagement
import SwiftUI

/// First run flow: meet the companion, pick a personality with a live
struct OnboardingView: View {
    @Environment(AppContainer.self) private var container
    let onFinish: () -> Void

    @State private var page = 0
    @State private var lockedNote = false
    @State private var recordingShortcut = false
    @State private var welcomeStage = 0
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let lastPage = 8

    private var accent: [Color] { container.prefs.activePersonality.accentColors }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                ZStack {
                    Group { content }
                        .id(page)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                navBar
            }
            .padding(30)
        }
        .frame(width: 700, height: 560)
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: page)
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(hex: 0x0B0B0E), Color(hex: 0x121216)],
                startPoint: .top,
                endPoint: .bottom
            )
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
        }
        .ignoresSafeArea()
    }

    /// Editorial step label that carries the accent quietly.
    private func kicker(_ text: String) -> some View {
        Text("\(String(format: "%02d", page + 1)) / \(String(format: "%02d", lastPage + 1))  ·  \(text)")
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .tracking(2.2)
            .foregroundStyle(accent[0].opacity(0.9))
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case 0: welcomePage
        case 1: namePage
        case 2: personalityPage
        case 3: customRulesPage
        case 4: rhythmPage
        case 5: carePage
        case 6: permissionsPage
        case 7: shortcutPage
        default: planPage
        }
    }

    // MARK: Welcome

    private var welcomePage: some View {
        VStack(spacing: 16) {
            CompanionFaceView(state: .excited, accent: accent, size: 76)
                .opacity(welcomeStage >= 1 ? 1 : 0)
                .scaleEffect(welcomeStage >= 1 ? 1 : 0.5)
            Text("Perch")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .opacity(welcomeStage >= 2 ? 1 : 0)
                .offset(y: welcomeStage >= 2 ? 0 : 12)
            Text("Protect the builder while they build.")
                .font(.perchRounded(15, weight: .medium))
                .foregroundStyle(.secondary)
                .opacity(welcomeStage >= 3 ? 1 : 0)
            Text("I live near your notch. While you're locked in, I quietly watch the safe stuff: how long you've been going, what's on your calendar, what you usually need. Then I check in at the right moments. No tracking dashboards, no guilt.")
                .font(.perchRounded(12.5))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
                .opacity(welcomeStage >= 3 ? 1 : 0)
                .offset(y: welcomeStage >= 3 ? 0 : 8)
        }
        .task {
            guard welcomeStage == 0 else { return }
            for stage in 1...3 {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { welcomeStage = stage }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    // MARK: Name

    private var namePage: some View {
        @Bindable var prefs = container.prefs
        return VStack(spacing: 18) {
            CompanionFaceView(state: .happy, accent: accent, size: 52)
            kicker("Getting to know you")
            Text("What should I call you?")
                .font(.perchRounded(24, weight: .bold))
            TextField("", text: $prefs.userName, prompt: Text("Your name"))
                .textFieldStyle(.plain)
                .font(.perchRounded(20, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .frame(width: 280)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onSubmit { advance() }
            Text("Some personalities will call you something warmer anyway.")
                .font(.perchRounded(11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Personality

    private var personalityPage: some View {
        VStack(spacing: 12) {
            kicker("Personality")
            Text("Pick my vibe")
                .font(.perchRounded(24, weight: .bold))
            Text("Same care, different voice. You can change this anytime.")
                .font(.perchRounded(11))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Personality.allCases) { personality in
                    personalityChip(personality)
                }
            }
            .frame(maxWidth: 560)
            notchPreview
            if lockedNote {
                Text("That one unlocks with Pro. You'll get the chance in a moment.")
                    .font(.perchRounded(10.5))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var customRulesPage: some View {
        VStack(spacing: 16) {
            kicker("Intelligence")
            Text("Custom AI Rules")
                .font(.perchRounded(24, weight: .bold))
            Text("Write your own system prompt or import a brain to control exactly how Perch thinks and speaks.")
                .font(.perchRounded(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            
            @Bindable var prefs = container.prefs
            if container.subscriptions.gate.customPersonality {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Toggle("Override intelligence rules", isOn: $prefs.usesCustomPersonality)
                            .font(.perchRounded(14, weight: .semibold))
                        Spacer()
                        if prefs.usesCustomPersonality {
                            Button("Import Brain") {
                                importBrain(prefs: prefs)
                            }
                            .buttonStyle(.plain)
                            .font(.perchRounded(13, weight: .semibold))
                            .foregroundStyle(.blue)
                        }
                    }
                    if prefs.usesCustomPersonality {
                        TextEditor(text: $prefs.customInstructions)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(height: 120)
                            .padding(8)
                            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .frame(maxWidth: 500)
                .padding(.top, 10)
            } else {
                VStack(spacing: 12) {
                    ProTag(text: "PRO FEATURE")
                    Text("Unlock custom intelligence with Perch Pro.")
                        .font(.perchRounded(12))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
            }
        }
    }

    private func personalityChip(_ personality: Personality) -> some View {
        let isSelected = container.prefs.personality == personality
        let isLocked = personality.requiresPro && !container.subscriptions.gate.allPersonalities
        return Button {
            if isLocked {
                lockedNote = true
            } else {
                lockedNote = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    container.prefs.personality = personality
                }
                container.voice.preview(MessageLibrary.sample(personality: personality))
            }
        } label: {
            HStack(spacing: 8) {
                CompanionFaceView(
                    state: isSelected ? .excited : .idle,
                    accent: personality.accentColors,
                    size: 22
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(personality.displayName)
                        .font(.perchRounded(12, weight: .semibold))
                    Text(personality.tagline)
                        .font(.perchRounded(8.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if isLocked {
                    ProTag()
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(personality.accentColors[0])
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected
                        ? AnyShapeStyle(personality.accentColors[0].opacity(0.14))
                        : AnyShapeStyle(.white.opacity(0.05)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(isSelected ? personality.accentColors[0].opacity(0.6) : .clear, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    /// Live mock of the notch bubble, speaking in the selected voice.
    private var notchPreview: some View {
        let personality = container.prefs.personality
        let shape = UnevenRoundedRectangle(
            cornerRadii: .init(topLeading: 0, bottomLeading: 22, bottomTrailing: 22, topTrailing: 0),
            style: .continuous
        )
        return VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                CompanionFaceView(state: .talking, accent: personality.accentColors, size: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PREVIEW")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.4))
                    Text(MessageLibrary.sample(personality: personality))
                        .font(.perchRounded(12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.94))
                        .fixedSize(horizontal: false, vertical: true)
                        .id(personality)
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(width: 410)
        .background(shape.fill(.black))
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [personality.accentColors[0].opacity(0.45), personality.accentColors[1].opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: personality)
    }

    // MARK: Rhythm

    private var rhythmPage: some View {
        @Bindable var prefs = container.prefs
        return VStack(spacing: 18) {
            kicker("Your rhythm")
            Text("Your usual day")
                .font(.perchRounded(24, weight: .bold))
            Text("So I know when you're overworking and when meals matter.")
                .font(.perchRounded(11.5))
                .foregroundStyle(.secondary)
            Grid(horizontalSpacing: 24, verticalSpacing: 14) {
                GridRow {
                    rhythmPicker("Work starts", selection: timeOfDayBinding($prefs.workStartMinutes))
                    rhythmPicker("Work ends", selection: timeOfDayBinding($prefs.workEndMinutes))
                }
                GridRow {
                    rhythmPicker("Lunch", selection: timeOfDayBinding($prefs.lunchMinutes))
                    rhythmPicker("Dinner", selection: timeOfDayBinding($prefs.dinnerMinutes))
                }
            }
            .padding(18)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func rhythmPicker(_ label: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.perchRounded(12.5, weight: .medium))
                .frame(width: 84, alignment: .leading)
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .datePickerStyle(.stepperField)
                .labelsHidden()
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Care

    private var carePage: some View {
        @Bindable var prefs = container.prefs
        return VStack(spacing: 16) {
            kicker("Care preferences")
            Text("What should I watch for?")
                .font(.perchRounded(24, weight: .bold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(ReminderKind.togglable.filter { !$0.requiresCalendar }) { kind in
                    careChip(kind, prefs: prefs)
                }
            }
            .frame(maxWidth: 500)
            Picker("", selection: $prefs.intensity) {
                ForEach(ReminderIntensity.allCases) { intensity in
                    Text(intensity.displayName).tag(intensity)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 300)
            Text(prefs.intensity.blurb)
                .font(.perchRounded(11))
                .foregroundStyle(.secondary)
        }
    }

    private func careChip(_ kind: ReminderKind, prefs: PreferencesStore) -> some View {
        let isOn = prefs.enabledKinds.contains(kind)
        return Button {
            var kinds = prefs.enabledKinds
            if isOn { kinds.remove(kind) } else { kinds.insert(kind) }
            prefs.enabledKinds = kinds
        } label: {
            HStack(spacing: 6) {
                Image(systemName: kind.symbolName)
                    .font(.system(size: 10, weight: .semibold))
                Text(kind.displayName)
                    .font(.perchRounded(11.5, weight: .medium))
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                    .foregroundStyle(isOn ? accent[0] : .white.opacity(0.25))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? accent[0].opacity(0.14) : .white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Permissions

    private var permissionsPage: some View {
        VStack(spacing: 14) {
            kicker("Privacy and permissions")
            Text("You stay in control")
                .font(.perchRounded(24, weight: .bold))
            Text("Everything lives on your Mac. Grant only what you want.")
                .font(.perchRounded(11.5))
                .foregroundStyle(.secondary)
            VStack(spacing: 10) {
                permissionRow(
                    symbol: "bell.badge.fill",
                    title: "Notifications",
                    detail: "Optional mirror of check ins",
                    granted: container.notifications.authorized
                ) {
                    Task { await container.notifications.requestAuthorization() }
                }
                permissionRow(
                    symbol: "calendar",
                    title: "Calendar",
                    detail: "Meeting prep and recovery. Pro feature, read only",
                    granted: container.calendar.isAuthorized
                ) {
                    Task { _ = await container.calendar.requestAccess() }
                }
                permissionRow(
                    symbol: "mic.fill",
                    title: "Microphone and speech",
                    detail: "Voice replies and dictation, recognized on device",
                    granted: container.voice.listeningAuthorized
                ) {
                    Task { _ = await container.voice.requestListeningPermissions() }
                }
                permissionRow(
                    symbol: "macwindow",
                    title: "Launch at login",
                    detail: "Start Perch automatically when you turn on your Mac",
                    granted: launchAtLogin
                ) {
                    try? SMAppService.mainApp.register()
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
            .frame(maxWidth: 460)
        }
    }

    private func permissionRow(
        symbol: String,
        title: String,
        detail: String,
        granted: Bool,
        buttonLabel: String = "Allow",
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(accent[0])
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.perchRounded(13, weight: .semibold))
                Text(detail).font(.perchRounded(10.5)).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.perchRounded(11))
                    .foregroundStyle(.green)
            } else {
                Button(buttonLabel, action: action)
                    .buttonStyle(.glass)
                    .font(.perchRounded(11.5))
            }
        }
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Shortcut

    private var shortcutPage: some View {
        VStack(spacing: 16) {
            kicker("Quick answers")
            Text("Your quick answer key")
                .font(.perchRounded(24, weight: .bold))
            Text("When I check in, press it from any app to answer without touching the mouse.")
                .font(.perchRounded(11.5))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)
                .multilineTextAlignment(.center)
            ShortcutRecorderButton(isRecording: $recordingShortcut) { keyCode, modifiers in
                container.prefs.shortcutKeyCode = keyCode
                container.prefs.shortcutModifiers = modifiers
                container.shortcuts.registerFromPrefs()
            } currentLabel: {
                QuickAnswerShortcutManager.describe(
                    keyCode: container.prefs.shortcutKeyCode,
                    modifiers: container.prefs.shortcutModifiers
                )
            }
            .scaleEffect(1.25)
            .padding(.vertical, 8)
            if !container.shortcuts.registrationOK {
                Text("That combination is taken by the system. Try another.")
                    .font(.perchRounded(10.5))
                    .foregroundStyle(.orange)
            }
            VStack(spacing: 4) {
                Text("1 answers, 2 starts a reset timer, 3 snoozes, Esc dismisses.")
                Text("Click the shortcut to change it.")
            }
            .font(.perchRounded(10.5))
            .foregroundStyle(.secondary)
        }
    }

    // MARK: Plan

    private var planPage: some View {
        VStack(spacing: 14) {
            CompanionFaceView(state: .happy, accent: accent, size: 52)
            kicker("Ready")
            Text("I've got you, \(container.prefs.activePersonality.callName(userName: container.prefs.userName))")
                .font(.perchRounded(24, weight: .bold))
            Text("\"\(MessageLibrary.sample(personality: container.prefs.activePersonality))\"")
                .font(.perchRounded(12.5))
                .italic()
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Text("Start free with smart check ins, or unlock AI memory, voice, chat, and calendar awareness with Pro.")
                .font(.perchRounded(11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack(spacing: 12) {
                Button("See Pro plans") {
                    finish()
                    WindowPresenter.shared.showPaywall(container)
                }
                .buttonStyle(.glass)
                Button("Start free") { finish() }
                    .buttonStyle(BigActionButtonStyle(accent: accent))
            }
            .padding(.top, 6)
        }
    }

    // MARK: Navigation

    private var navBar: some View {
        HStack {
            if page > 0 {
                Button { back() } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(IconPillButtonStyle())
            }
            Spacer()
            HStack(spacing: 5) {
                ForEach(0...lastPage, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? accent[0] : .white.opacity(0.18))
                        .frame(width: index == page ? 18 : 5, height: 5)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
            Spacer()
            if page < lastPage {
                Button("Continue") { advance() }
                    .buttonStyle(BigActionButtonStyle(accent: accent))
            }
        }
    }

    private func advance() {
        guard page < lastPage else { return }
        page += 1
    }

    private func back() {
        guard page > 0 else { return }
        page -= 1
    }

    private func finish() {
        container.prefs.hasOnboarded = true
        onFinish()
    }

    private func importBrain(prefs: PreferencesStore) {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                prefs.customInstructions = text
            }
        }
    }
}
