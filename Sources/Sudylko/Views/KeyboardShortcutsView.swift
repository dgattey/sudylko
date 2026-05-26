import SwiftUI

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Keyboard shortcuts")
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 28)

                VStack(alignment: .leading, spacing: 14) {
                    shortcutRow("Pause or resume the timer") {
                        KeyCap("Space", minWidth: 52)
                    }

                    shortcutRow("Move the selected cell") {
                        KeyCap(systemImage: "arrow.up")
                        KeyCap(systemImage: "arrow.down")
                        KeyCap(systemImage: "arrow.left")
                        KeyCap(systemImage: "arrow.right")
                        ShortcutOrLabel()
                        KeyCap("W", minWidth: 28)
                        KeyCap("A", minWidth: 28)
                        KeyCap("S", minWidth: 28)
                        KeyCap("D", minWidth: 28)
                    }

                    shortcutRow("Enter a digit in the selected cell") {
                        KeyCap("1")
                        Text("–")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        KeyCap("9")
                    }

                    shortcutRow("Clear the selected cell") {
                        KeyCap("E")
                        ShortcutOrLabel()
                        KeyCap(systemImage: "delete.backward")
                        ShortcutOrLabel()
                        KeyCap(systemImage: "delete.forward")
                    }

                    shortcutRow("Save game and return home") {
                        KeyCap(systemImage: "escape", minWidth: 32)
                    }

                    shortcutRow("Toggle the sidebar") {
                        KeyCap(systemImage: "command", minWidth: 28)
                        KeyCap("S", minWidth: 28)
                    }

                    shortcutRow("Open keyboard shortcuts") {
                        KeyCap(systemImage: "shift", minWidth: 28)
                        KeyCap("?", minWidth: 28)
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.monochrome)
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .appAccentForeground()
            .keyboardShortcut(.cancelAction)
            .macOSTooltip("Close")
        }
        .padding(24)
        .frame(width: 580)
    }

    private func shortcutRow(
        _ description: String,
        @ViewBuilder keys: () -> some View
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 5) {
                keys()
            }
            .fixedSize(horizontal: true, vertical: false)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
