import Foundation

/// Resolves which language the app should use.
///
/// Precedence: explicit in-app choice > macOS per-app language > system language.
public enum LanguageResolver {
    public static func isRightToLeft(_ languageCode: String) -> Bool {
        ["ar", "he", "fa", "ur"].contains(languageCode)
    }

    public static func effective(preferred: String?,
                                 perApp: [String]?,
                                 system: [String]) -> String {
        if let preferred = preferred?.trimmingCharacters(in: .whitespacesAndNewlines),
           !preferred.isEmpty {
            return preferred
        }
        if let perApp = perApp?.first, !perApp.isEmpty {
            return perApp
        }
        return system.first ?? "en"
    }
}