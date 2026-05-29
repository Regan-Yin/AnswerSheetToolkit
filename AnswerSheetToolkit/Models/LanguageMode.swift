import Foundation

/// Supported UI languages.
enum LanguageMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case english
    case simplifiedChinese

    var id: String { rawValue }

    /// The `.lproj` / bundle language code used to resolve localized strings.
    var bundleCode: String {
        switch self {
        case .english: return "en"
        case .simplifiedChinese: return "zh-Hans"
        }
    }

    /// Localization key for the human-readable name.
    var localizationKey: String {
        switch self {
        case .english: return "language.english"
        case .simplifiedChinese: return "language.simplifiedChinese"
        }
    }
}
