import SwiftUI

struct RemindersSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var newRoutineLabel = ""
    @State private var newRoutineTime = Date()
    @State private var newRoutineMessage = ""

    var body: some View {
        @Bindable var prefs = container.prefs
        Form {
            Section("How closely should I look after you?") {
                Picker("Intensity", selection: $prefs.intensity) {
                    ForEach(ReminderIntensity.allCases) { intensity in
                        Text(intensity.displayName).tag(intensity)
                    }
                }
                .pickerStyle(.segmented)
                Text(prefs.intensity.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Wellbeing check ins") {
                ForEach(wellbeingKinds) { kind in
                    kindToggle(kind, prefs: prefs)
                }
                Text("Meal and shower times, work hours, and quiet hours are set in General.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Schedule awareness") {
                ForEach(calendarKinds) { kind in
                    kindToggle(kind, prefs: prefs, locked: !container.subscriptions.gate.calendarAwareness)
                }
                if !container.subscriptions.gate.calendarAwareness {
                    lockedFootnote
                } else if !container.calendar.isAuthorized {
                    Text("These need calendar access to work. Grant it in Privacy.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Section("Personal routines") {
                routinesList(prefs: prefs)
                HStack {
                    TextField("Routine", text: $newRoutineLabel, prompt: Text("e.g. Take vitamins"))
                    DatePicker("", selection: $newRoutineTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Button("Add") { addRoutine(prefs: prefs) }
                        .disabled(
                            newRoutineLabel.trimmingCharacters(in: .whitespaces).isEmpty
                                || prefs.routines.count >= container.subscriptions.gate.maxRoutines
                        )
                }
                TextField(
                    "In your words",
                    text: $newRoutineMessage,
                    prompt: Text("Optional: exactly what Perch should say")
                )
                Text("Leave it blank and Perch phrases the reminder in its own personality. Write it and Perch says your exact words. {name} becomes what Perch calls you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if prefs.routines.count >= container.subscriptions.gate.maxRoutines {
                    Text("Free plan includes \(container.subscriptions.gate.maxRoutines) routines. Pro unlocks more.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var wellbeingKinds: [ReminderKind] {
        ReminderKind.togglable.filter { !$0.requiresCalendar }
    }

    private var calendarKinds: [ReminderKind] {
        ReminderKind.togglable.filter(\.requiresCalendar)
    }

    private func kindToggle(_ kind: ReminderKind, prefs: PreferencesStore, locked: Bool = false) -> some View {
        Toggle(isOn: Binding(
            get: { prefs.enabledKinds.contains(kind) },
            set: { enabled in
                var kinds = prefs.enabledKinds
                if enabled { kinds.insert(kind) } else { kinds.remove(kind) }
                prefs.enabledKinds = kinds
            }
        )) {
            HStack(spacing: 8) {
                Image(systemName: kind.symbolName)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(kind.displayName)
                if locked { ProTag() }
            }
        }
        .disabled(locked)
    }

    private var lockedFootnote: some View {
        HStack(spacing: 6) {
            Text("Calendar awareness is part of Pro.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("See plans") { WindowPresenter.shared.showPaywall(container) }
                .font(.caption)
        }
    }

    private func routinesList(prefs: PreferencesStore) -> some View {
        ForEach(prefs.routines) { routine in
            HStack {
                Toggle(isOn: Binding(
                    get: { routine.enabled },
                    set: { enabled in
                        prefs.routines = prefs.routines.map {
                            var copy = $0
                            if copy.id == routine.id { copy.enabled = enabled }
                            return copy
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.label)
                        if let message = routine.trimmedMessage {
                            Text("\u{201C}\(message)\u{201D}")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                Spacer()
                Text(timeLabel(routine.minuteOfDay))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button {
                    prefs.routines = prefs.routines.filter { $0.id != routine.id }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func addRoutine(prefs: PreferencesStore) {
        guard prefs.routines.count < container.subscriptions.gate.maxRoutines else { return }
        let message = newRoutineMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let routine = RoutineReminder(
            label: newRoutineLabel.trimmingCharacters(in: .whitespaces),
            minuteOfDay: minutesOfDay(newRoutineTime),
            message: message.isEmpty ? nil : message
        )
        prefs.routines = prefs.routines + [routine]
        newRoutineLabel = ""
        newRoutineMessage = ""
    }

    private func timeLabel(_ minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
