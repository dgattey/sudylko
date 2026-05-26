import AppKit
import SwiftUI

public enum AppAccentColor: String, CaseIterable, Identifiable, Sendable {
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green

    public var id: String { rawValue }

    /// Swatch and vivid fills (color picker dots).
    public var color: Color {
        switch self {
        case .blue: Color(red: 0.0, green: 0.48, blue: 1.0)
        case .purple: Color(red: 0.69, green: 0.32, blue: 0.87)
        case .pink: Color(red: 1.0, green: 0.18, blue: 0.57)
        case .red: Color(red: 1.0, green: 0.23, blue: 0.19)
        case .orange: Color(red: 1.0, green: 0.58, blue: 0.0)
        case .yellow: Color(red: 1.0, green: 0.8, blue: 0.0)
        case .green: Color(red: 0.2, green: 0.78, blue: 0.35)
        }
    }

    /// Prominent buttons and large fills — softened on light backgrounds when needed.
    public func displayColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .yellow where colorScheme == .light:
            return Color(red: 0.96, green: 0.76, blue: 0.0)
        case .orange where colorScheme == .light:
            return Color(red: 0.95, green: 0.55, blue: 0.04)
        default:
            return color
        }
    }

    /// Text, icons, and board digits.
    public func interactiveForeground(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .yellow:
            if colorScheme == .dark {
                return Color(red: 1.0, green: 0.84, blue: 0.12)
            }
            return Color(red: 0.82, green: 0.66, blue: 0.0)
        case .orange:
            if colorScheme == .dark {
                return Color(red: 1.0, green: 0.62, blue: 0.06)
            }
            return Color(red: 0.86, green: 0.50, blue: 0.02)
        case .green:
            if colorScheme == .dark {
                return Color(red: 0.08, green: 0.52, blue: 0.28)
            }
            return Color(red: 0.11, green: 0.56, blue: 0.31)
        default:
            return color
        }
    }

    public func selectionFill(for colorScheme: ColorScheme) -> Color {
        interactiveForeground(for: colorScheme).opacity(0.12)
    }

    public func selectionBorder(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .yellow, .orange, .green:
            interactiveForeground(for: colorScheme).opacity(0.65)
        default:
            color.opacity(0.55)
        }
    }

    public var prefersStrongSelectionBorder: Bool {
        switch self {
        case .yellow, .orange, .green: true
        default: false
        }
    }

    public func nsAccentForeground(for colorScheme: ColorScheme) -> NSColor {
        NSColor(interactiveForeground(for: colorScheme))
    }
}
