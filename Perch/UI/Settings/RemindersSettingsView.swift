import SwiftUI

struct RemindersSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var newRoutineLabel = ""
    @State private var newRoutineTime = Date()

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
            }
            Section("Schedule awareness") {
                ForEach(calendarKinds) { kind in
                    kindToggle(kind, prefs: prefs, locked: !container.subscriptions.gate.calendarAwareness)
                }
                if !container.subscriptions.gate.calendarAwareness {
                    lockedFootnote
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
                    Text(routine.label)
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
        let routine = RoutineReminder(
            label: newRoutineLabel.trimmingCharacters(in: .whitespaces),
            minuteOfDay: minutesOfDay(newRoutineTime)
        )
        prefs.routines = prefs.routines + [routine]
        newRoutineLabel = ""
    }

    private func timeLabel(_ minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
