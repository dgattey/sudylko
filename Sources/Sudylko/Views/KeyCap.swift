import SwiftUI

/// Single key cap styled like macOS shortcut reference UI.
struct KeyCap: View {
    enum Content {
        case text(String)
        case systemImage(String)
    }

    let content: Content
    var minWidth: CGFloat = 26

    @Environment(\.colorScheme) private var colorScheme

    init(_ text: String, minWidth: CGFloat = 26) {
        content = .text(text)
        self.minWidth = minWidth
    }

    init(systemImage: String, minWidth: CGFloat = 26) {
        content = .systemImage(systemImage)
        self.minWidth = minWidth
    }

    private var keyFont: Font {
        .system(size: 13, weight: .medium, design: .monospaced)
    }

    var body: some View {
        Group {
            switch content {
            case .text(let string):
                Text(string)
                    .font(keyFont)
                    .monospacedDigit()
            case .systemImage(let name):
                Image(systemName: name)
                    .font(.system(size: 13, weight: .medium))
                    .symbolRenderingMode(.monochrome)
            }
        }
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(width: minWidth, height: 26)
        .multilineTextAlignment(.center)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(capFill)
                .shadow(color: .black.opacity(shadowOpacity), radius: 0.5, x: 0, y: 1.5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(capStroke, lineWidth: 0.5)
        }
    }

    private var capFill: Color {
        colorScheme == .dark
            ? Color(white: 0.22)
            : Color(white: 0.97)
    }

    private var capStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.black.opacity(0.14)
    }

    private var shadowOpacity: Double {
        colorScheme == .dark ? 0.45 : 0.08
    }
}

/// Separates key caps in a shortcut row.
struct ShortcutOrLabel: View {
    var body: some View {
        Text("or")
            .font(.subheadline)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 2)
    }
}
