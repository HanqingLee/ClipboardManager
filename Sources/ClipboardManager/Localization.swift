import AppKit
import Foundation
import ClipboardManagerCore

/// Resolves the bundle used for app strings.
///
/// Precedence: in-app choice > macOS per-app language > system language.
/// The system cases are handled by `Bundle.main` (the system already picked the
/// matching `.lproj`); an explicit in-app choice loads that `.lproj` directly.
/// The in-app choice is written to AppleLanguages (with the previous value
/// backed up) so AppKit also picks the correct interface direction on restart.
final class LocalizationManager {
    static let shared = LocalizationManager()

    private(set) var bundle: Bundle = .main
    private(set) var appliedLanguage: String = ""

    private init() {}

    /// Call once at launch, before any UI is built.
    func apply(preferredLanguage: String) {
        appliedLanguage = preferredLanguage
        guard !preferredLanguage.isEmpty,
              let path = Bundle.main.path(forResource: preferredLanguage, ofType: "lproj"),
              let selected = Bundle(path: path) else {
            bundle = .main
            return
        }
        bundle = selected
    }

    func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    func string(_ key: String, count: Int) -> String {
        String.localizedStringWithFormat(string(key), count)
    }
}

/// App-string lookup used everywhere in the app.
func L(_ key: String) -> String {
    LocalizationManager.shared.string(key)
}

/// Count-aware lookup for label-style strings such as "Items: 3".
func L(_ key: String, count: Int) -> String {
    LocalizationManager.shared.string(key, count: count)
}

extension LocalizationManager {
    var effectiveLanguageCode: String {
        if !appliedLanguage.isEmpty { return appliedLanguage }
        return Locale.current.language.languageCode?.identifier ?? "en"
    }

    var isRightToLeft: Bool {
        LanguageResolver.isRightToLeft(effectiveLanguageCode)
    }
}

/// AppKit's application-wide direction is read-only and does not follow the
/// in-app language override, so apply the direction explicitly to each view.
func applyLayoutDirection(_ direction: NSUserInterfaceLayoutDirection, to view: NSView) {
    view.userInterfaceLayoutDirection = direction
    for sub in view.subviews { applyLayoutDirection(direction, to: sub) }
}