import SwiftUI

/// A color palette derived from the selected ``ThemeMode``.
///
/// System/Light/Dark rely on `preferredColorScheme` + semantic colors. Light Amber
/// is a custom warm palette applied on top of a forced light scheme.
struct ThemePalette: Equatable {
    var windowBackground: Color
    var surface: Color
    var cellBackground: Color
    var cellBorder: Color
    var focusRing: Color
    var primaryText: Color
    var secondaryText: Color
    var accent: Color
    /// True for the custom Light Amber palette where explicit colors should override
    /// the system's semantic colors.
    var usesCustomColors: Bool

    static func palette(for theme: ThemeMode) -> ThemePalette {
        switch theme {
        case .lightAmber:
            return ThemePalette(
                windowBackground: Color(red: 0.98, green: 0.94, blue: 0.86),
                surface: Color(red: 0.99, green: 0.96, blue: 0.90),
                cellBackground: Color(red: 1.0, green: 0.99, blue: 0.95),
                cellBorder: Color(red: 0.80, green: 0.68, blue: 0.47),
                focusRing: Color(red: 0.85, green: 0.55, blue: 0.10),
                primaryText: Color(red: 0.24, green: 0.17, blue: 0.05),
                secondaryText: Color(red: 0.45, green: 0.36, blue: 0.22),
                accent: Color(red: 0.80, green: 0.49, blue: 0.05),
                usesCustomColors: true
            )
        case .system, .light, .dark:
            return ThemePalette(
                windowBackground: Color(nsColor: .windowBackgroundColor),
                surface: Color(nsColor: .controlBackgroundColor),
                cellBackground: Color(nsColor: .textBackgroundColor),
                cellBorder: Color(nsColor: .separatorColor),
                focusRing: Color.accentColor,
                primaryText: Color(nsColor: .labelColor),
                secondaryText: Color(nsColor: .secondaryLabelColor),
                accent: Color.accentColor,
                usesCustomColors: false
            )
        }
    }
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue: ThemePalette = .palette(for: .system)
}

extension EnvironmentValues {
    var palette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}
