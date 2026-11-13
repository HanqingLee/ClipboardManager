import AppKit
import Carbon.HIToolbox
import ClipboardManagerCore

enum HotkeyRecordOutcome {
    case accepted
    case conflict
    case invalid
}

enum HotkeyFormatter {
    static func string(for config: HotkeyConfig) -> String {
        var result = ""
        if config.modifiers.contains(.control) { result += "⌃" }
        if config.modifiers.contains(.option) { result += "⌥" }
        if config.modifiers.contains(.shift) { result += "⇧" }
        if config.modifiers.contains(.command) { result += "⌘" }
        result += keyName(config.keyCode)
        return result
    }

    static func keyName(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "␣"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: break
        }
        if let character = layoutCharacter(keyCode) {
            return character.uppercased()
        }
        return "Key \(keyCode)"
    }

    /// Resolves the character printed on the current keyboard layout.
    private static func layoutCharacter(_ keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        return data.withUnsafeBytes { raw -> String? in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
            var deadKeyState: UInt32 = 0
            var characters = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(layout,
                                        UInt16(keyCode),
                                        UInt16(kUCKeyActionDisplay),
                                        0,
                                        UInt32(LMGetKbdType()),
                                        OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                        &deadKeyState,
                                        characters.count,
                                        &length,
                                        &characters)
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: characters, count: length)
        }
    }
}

/// A button that displays the current shortcut and captures a new one on click.
final class HotkeyRecorderButton: NSButton {
    var config: HotkeyConfig = .default {
        didSet { updateTitle() }
    }

    /// Called with a candidate config. Return `.accepted` to apply, `.conflict`
    /// or `.invalid` to keep recording and let the caller show a message.
    var onRecord: ((HotkeyConfig) -> HotkeyRecordOutcome)?
    /// Called when the captured combination is invalid (no required modifier).
    var onInvalid: (() -> Void)?

    private var monitor: Any?
    private var isRecording = false

    init() {
        super.init(frame: .zero)
        setButtonType(.momentaryPushIn)
        bezelStyle = .rounded
        target = self
        action = #selector(toggleRecording)
        widthAnchor.constraint(equalToConstant: 170).isActive = true
        updateTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool { true }

    override func resignFirstResponder() -> Bool {
        stopRecording(restoreOldValue: true)
        return super.resignFirstResponder()
    }

    @objc private func toggleRecording() {
        if isRecording {
            stopRecording(restoreOldValue: true)
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        title = L("settings.pressShortcut")
        window?.makeFirstResponder(self)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            return self.handle(event)
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 { // Esc cancels
            stopRecording(restoreOldValue: true)
            return nil
        }

        var modifiers: HotkeyModifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }

        let candidate = HotkeyConfig(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        guard candidate.isValid else {
            onInvalid?()
            return nil
        }

        switch onRecord?(candidate) ?? .invalid {
        case .accepted:
            config = candidate
            stopRecording(restoreOldValue: false)
        case .conflict, .invalid:
            // Keep recording so the user can try another combination.
            break
        }
        return nil
    }

    private func stopRecording(restoreOldValue: Bool) {
        guard isRecording else { return }
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if restoreOldValue {
            updateTitle()
        }
    }

    private func updateTitle() {
        if isRecording { return }
        title = HotkeyFormatter.string(for: config)
    }

    #if DEBUG
    /// Feeds a synthetic key event through the same capture path (tests only).
    func simulateKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        guard let event = NSEvent.keyEvent(with: .keyDown,
                                           location: .zero,
                                           modifierFlags: modifiers,
                                           timestamp: 0,
                                           windowNumber: window?.windowNumber ?? 0,
                                           context: nil,
                                           characters: "",
                                           charactersIgnoringModifiers: "",
                                           isARepeat: false,
                                           keyCode: keyCode) else { return }
        _ = handle(event)
    }
    #endif
}