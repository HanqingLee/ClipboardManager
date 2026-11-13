import Foundation

public final class Preferences {
    public static let shared = Preferences()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "capacity": 100,
            // Mac App Store 版本默认“仅复制”：自动粘贴需要辅助功能权限，
            // 由用户在菜单里主动开启，避免首次启动就索要系统级权限。
            "autoPaste": false,
            "hotkeyKeyCode": 9,        // kVK_ANSI_V
            "hotkeyModifiers": 768,    // cmdKey | shiftKey
            "preferredLanguage": "",   // empty = follow the system
        ])
    }

    public var capacity: Int {
        get { defaults.integer(forKey: "capacity") }
        set { defaults.set(newValue, forKey: "capacity") }
    }

    public var autoPaste: Bool {
        get { defaults.bool(forKey: "autoPaste") }
        set { defaults.set(newValue, forKey: "autoPaste") }
    }

    public var hotkey: HotkeyConfig {
        get { HotkeyConfig.load(from: defaults) }
        set { newValue.save(to: defaults) }
    }

    public var preferredLanguage: String {
        get { defaults.string(forKey: "preferredLanguage") ?? "" }
        set {
            defaults.set(newValue, forKey: "preferredLanguage")
            applyAppleLanguages(for: newValue)
        }
    }

    /// AppKit reads AppleLanguages at process start, so the in-app choice must
    /// be written immediately; the next launch then has the correct language
    /// and interface direction (RTL for Arabic/Hebrew). The previous value is
    /// backed up so "Follow System" can restore the system/per-app setting.
    private func applyAppleLanguages(for language: String) {
        let backupKey = "systemAppleLanguagesBackup"
        if !language.isEmpty {
            if defaults.object(forKey: backupKey) == nil {
                let original = defaults.array(forKey: "AppleLanguages") as? [String] ?? []
                defaults.set(original, forKey: backupKey)
            }
            defaults.set([language], forKey: "AppleLanguages")
        } else if let backup = defaults.array(forKey: backupKey) as? [String] {
            if backup.isEmpty {
                defaults.removeObject(forKey: "AppleLanguages")
            } else {
                defaults.set(backup, forKey: "AppleLanguages")
            }
            defaults.removeObject(forKey: backupKey)
        }
    }
}
