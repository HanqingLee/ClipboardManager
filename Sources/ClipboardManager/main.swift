import AppKit
import Foundation

// Apply the in-app language override before AppKit initializes. Setting
// AppleLanguages here makes both the localized resources and the interface
// layout direction (RTL for Arabic/Hebrew) correct. The previous value is
// backed up so "Follow System" can restore it.
let defaults = UserDefaults.standard
let preferredLanguage = defaults.string(forKey: "preferredLanguage") ?? ""
let languageBackupKey = "systemAppleLanguagesBackup"

if !preferredLanguage.isEmpty {
    if defaults.object(forKey: languageBackupKey) == nil {
        let original = defaults.array(forKey: "AppleLanguages") as? [String] ?? []
        defaults.set(original, forKey: languageBackupKey)
    }
    defaults.set([preferredLanguage], forKey: "AppleLanguages")
} else if let backup = defaults.array(forKey: languageBackupKey) as? [String] {
    if backup.isEmpty {
        defaults.removeObject(forKey: "AppleLanguages")
    } else {
        defaults.set(backup, forKey: "AppleLanguages")
    }
    defaults.removeObject(forKey: languageBackupKey)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()