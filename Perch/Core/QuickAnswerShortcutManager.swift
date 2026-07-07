import AppKit
import Carbon.HIToolbox
import Observation


@MainActor
@Observable
final class QuickAnswerShortcutManager {

    @ObservationIgnored var onPressed: (() -> Void)?

    private(set) var registrationOK = true

    @ObservationIgnored private let prefs: PreferencesStore
    @ObservationIgnored private var answerHotKeyRef: EventHotKeyRef?
    @ObservationIgnored private var handlerRef: EventHandlerRef?

    private static let answerHotKeyID: UInt32 = 1

    init(prefs: PreferencesStore) {
        self.prefs = prefs
    }

    func registerFromPrefs() {
        unregister()
        installHandlerIfNeeded()
        registrationOK = register(
            id: Self.answerHotKeyID,
            keyCode: prefs.shortcutKeyCode,
            modifiers: prefs.shortcutModifiers,
            ref: &answerHotKeyRef
        )
    }

    func unregister() {
        if let answerHotKeyRef {
            UnregisterEventHotKey(answerHotKeyRef)
            self.answerHotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    private func register(id: UInt32, keyCode: Int, modifiers: UInt, ref: inout EventHotKeyRef?) -> Bool {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        let hotKeyID = EventHotKeyID(signature: OSType(0x5052_4348), id: id)
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            Self.carbonModifiers(from: flags),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        return status == noErr && ref != nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                let manager = Unmanaged<QuickAnswerShortcutManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in
                    manager.onPressed?()
                }
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

        // MARK: Key describing

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    static func modifierSymbols(_ modifiers: UInt) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var parts = ""
        if flags.contains(.control) { parts += "⌃" }
        if flags.contains(.option) { parts += "⌥" }
        if flags.contains(.shift) { parts += "⇧" }
        if flags.contains(.command) { parts += "⌘" }
        return parts
    }

    static func describe(keyCode: Int, modifiers: UInt) -> String {
        modifierSymbols(modifiers) + keyName(for: keyCode)
    }

    static func keyName(for keyCode: Int) -> String {
        if let special = specialKeys[keyCode] { return special }
        let letters: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 25: "9", 26: "7", 28: "8", 29: "0", 31: "O", 32: "U",
            34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        ]
        return letters[keyCode] ?? "Key \(keyCode)"
    }

    private static let specialKeys: [Int: String] = [
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}
