import Foundation

/// Resolves localized strings from per-language `.lproj` bundles so the UI language
/// can be switched at runtime without relaunching the app.
final class LocalizationService {
    static let shared = LocalizationService()

    private var bundleCache: [String: Bundle] = [:]

    private func bundle(for language: LanguageMode) -> Bundle {
        let code = language.bundleCode
        if let cached = bundleCache[code] { return cached }
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            bundleCache[code] = bundle
            return bundle
        }
        return .main
    }

    /// Looks up `key` in the given language, falling back to the key itself.
    func string(_ key: String, language: LanguageMode) -> String {
        let bundle = bundle(for: language)
        let value = bundle.localizedString(forKey: key, value: nil, table: nil)
        if value != key { return value }
        // Fallback to English if a key is missing in the selected language.
        if language != .english {
            return self.string(key, language: .english)
        }
        return value
    }
}
