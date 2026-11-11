import Foundation

/// Carbon-compatible modifier bits (cmdKey/shiftKey/optionKey/controlKey).
public struct HotkeyModifiers: OptionSet, Hashable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let command = HotkeyModifiers(rawValue: 256)
    public static let shift = HotkeyModifiers(rawValue: 512)
    public static let option = HotkeyModifiers(rawValue: 2048)
    public static let control = HotkeyModifiers(rawValue: 4096)

    /// At least one of these is required; Shift alone is not enough.
    public static let required: HotkeyModifiers = [.command, .option, .control]
}

public struct HotkeyConfig: Equatable, Hashable {
    public var keyCode: UInt32
    public var modifiers: HotkeyModifiers

    public static let `default` = HotkeyConfig(keyCode: 9, modifiers: [.command, .shift])

    public init(keyCode: UInt32, modifiers: HotkeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var hasRequiredModifier: Bool {
        !modifiers.intersection(.required).isEmpty
    }

    /// The recorder only produces a config on a real keyDown, so the key code is
    /// always a real key (note: key code 0 is the "A" key, not "none").
    public var isValid: Bool { hasRequiredModifier }

    // MARK: - Preferences

    public static func load(from defaults: UserDefaults) -> HotkeyConfig {
        guard defaults.object(forKey: "hotkeyKeyCode") != nil else { return .default }
        let keyCode = UInt32(defaults.integer(forKey: "hotkeyKeyCode"))
        let rawModifiers = UInt32(defaults.integer(forKey: "hotkeyModifiers"))
        let config = HotkeyConfig(keyCode: keyCode, modifiers: HotkeyModifiers(rawValue: rawModifiers))
        return config.isValid ? config : .default
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(Int(keyCode), forKey: "hotkeyKeyCode")
        defaults.set(Int(modifiers.rawValue), forKey: "hotkeyModifiers")
    }
}