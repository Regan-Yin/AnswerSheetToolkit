import Foundation
import SwiftUI

/// Visual appearance options for the app.
enum ThemeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark
    case lightAmber

    var id: String { rawValue }

    /// Localization key for the human-readable name.
    var localizationKey: String {
        switch self {
        case .system: return "theme.system"
        case .light: return "theme.light"
        case .dark: return "theme.dark"
        case .lightAmber: return "theme.lightAmber"
        }
    }

    /// The SwiftUI color scheme this theme forces, or `nil` to follow the system.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light, .lightAmber: return .light
        case .dark: return .dark
        }
    }
}
