import SwiftUI
import SudylkoShared

private struct AppAccentColorKey: EnvironmentKey {
    static let defaultValue: AppAccentColor = .blue
}

private struct AppAccentTintKey: EnvironmentKey {
    static let defaultValue: Color = AppAccentColor.blue.color
}

private struct AppAccentProminentTintKey: EnvironmentKey {
    static let defaultValue: Color = AppAccentColor.blue.color
}

extension EnvironmentValues {
    var appAccent: AppAccentColor {
        get { self[AppAccentColorKey.self] }
        set { self[AppAccentColorKey.self] = newValue }
    }

    /// Resolved interactive accent `Color` (digits, icons, bordered controls).
    var appAccentTint: Color {
        get { self[AppAccentTintKey.self] }
        set { self[AppAccentTintKey.self] = newValue }
    }

    /// Prominent button fills (e.g. “New game”).
    var appAccentProminentTint: Color {
        get { self[AppAccentProminentTintKey.self] }
        set { self[AppAccentProminentTintKey.self] = newValue }
    }
}

/// Pushes accent + SwiftUI `tint` into the environment for this hierarchy and presentations (sheets, popovers).
struct AppAccentPropagationModifier: ViewModifier {
    @ObservedObject var appAccent: AppAccentModel

    func body(content: Content) -> some View {
        content
            .environment(\.appAccent, appAccent.accent)
            .environment(\.appAccentTint, appAccent.interactiveTint)
            .environment(\.appAccentProminentTint, appAccent.prominentTint)
            .tint(appAccent.interactiveTint)
    }
}

extension View {
    func sudylkoFocusSuppressed() -> some View {
        focusEffectDisabled()
    }

    /// Apply at the app root (see `SudylkoApp`) so descendants and sheets inherit accent tint.
    func appAccentPropagation(_ appAccent: AppAccentModel) -> some View {
        modifier(AppAccentPropagationModifier(appAccent: appAccent))
    }

    /// Uses `\.appAccentTint` from the environment (set by `appAccentPropagation()`).
    func appAccentForeground() -> some View {
        modifier(AppAccentForegroundModifier())
    }
}

private struct AppAccentForegroundModifier: ViewModifier {
    @Environment(\.appAccentTint) private var tint

    func body(content: Content) -> some View {
        content.foregroundStyle(tint)
    }
}
