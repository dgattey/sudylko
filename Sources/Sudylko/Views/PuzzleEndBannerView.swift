import SwiftUI

struct PuzzleEndBannerView: View {
    enum Kind {
        case won
        case lost
    }

    let kind: Kind
    let formattedElapsed: String
    let buttonTint: Color
    let colorScheme: ColorScheme
    var onDismiss: () -> Void
    var onButton: () -> Void

    @State private var isVisible = false

    private var accentColor: Color {
        switch kind {
        case .won: .green
        case .lost: .red
        }
    }

    private var systemImage: String {
        switch kind {
        case .won: "checkmark.seal.fill"
        case .lost: "xmark.octagon.fill"
        }
    }

    private var title: String {
        switch kind {
        case .won: "You solved it!"
        case .lost: "Puzzle lost"
        }
    }

    private var subtitle: String? {
        switch kind {
        case .won: "Every cell matches — nice work."
        case .lost: "Impossible mode ends the run on the first mistake."
        }
    }

    private var buttonTitle: String {
        "Back to home"
    }

    var body: some View {
        GameOverlayCardChrome(accent: accentColor, colorScheme: colorScheme) {
            VStack(spacing: 22) {
                Image(systemName: systemImage)
                    .sudylkoSymbolFont(.puzzleEndBanner)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(accentColor, accentColor.opacity(0.25))
                    .symbolEffect(.bounce, value: isVisible)

                VStack(spacing: 10) {
                    Text(title)
                        .font(.title)
                        .multilineTextAlignment(.center)

                    if let subtitle {
                        Text(subtitle)
                            .font(.title3).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(spacing: 6) {
                    Text("Time")
                        .font(.footnote).foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(formattedElapsed)
                        .font(.title)
                        .monospacedDigit()
                }
                .padding(.vertical, 4)

                Button(buttonTitle, action: onButton)
                    .font(.title3)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(minWidth: 240)
                    .padding(.vertical, 6)
                    .tint(buttonTint)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(10)
            .help("Dismiss")
            .accessibilityLabel("Dismiss")
        }
        .scaleEffect(isVisible ? 1 : 0.9)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                isVisible = true
            }
        }
        #if os(macOS)
        .onExitCommand(perform: onDismiss)
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityHint("Tap outside the card, press Escape, or use the close button to dismiss and keep browsing saves.")
    }
}
