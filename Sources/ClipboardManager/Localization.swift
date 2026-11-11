import Foundation

/// Resolves the bundle used for app strings.
///
/// Precedence: in-app choice > macOS per-app language > system language.
/// The system cases are handled by `Bundle.main` (the system already picked the
/// matching `.lproj`); an explicit in-app choice loads that `.lproj` directly.
/// We deliberately do not write `AppleLanguages`, so the system per-app setting
/// is preserved when the user chooses "Follow System".
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