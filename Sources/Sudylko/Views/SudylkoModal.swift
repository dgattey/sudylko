import SwiftUI

enum SudylkoModalLayout {
    static let width: CGFloat = 420
    static let padding: CGFloat = 24
    static let footerSpacing: CGFloat = 20
    static let cornerRadius: CGFloat = 14
}

extension View {
    /// Shared modal surface: opaque material, hairline border, and a layered shadow so dialogs
    /// read clearly above the dimmed content behind them.
    func sudylkoModalSurface(cornerRadius: CGFloat = SudylkoModalLayout.cornerRadius) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thickMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.34), radius: 32, y: 18)
                .shadow(color: .black.opacity(0.16), radius: 7, y: 2)
        }
    }
}

/// Shared sheet/dialog chrome: title, optional subtitle, body, and large footer actions.
struct SudylkoModal<Content: View, Footer: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: FormLayout.groupSpacing) {
            InspectorPageHeader(title: title, subtitle: subtitle)
            content()
            footer()
        }
        .padding(SudylkoModalLayout.padding)
        .frame(width: SudylkoModalLayout.width)
        .fixedSize(horizontal: false, vertical: true)
        .sudylkoModalSurface()
    }
}

/// Cancel + primary actions sized like sidebar “New game”.
struct SudylkoModalFooter: View {
    var cancelTitle = "Cancel"
    var onCancel: () -> Void
    var primaryTitle: String
    var primaryRole: ButtonRole?
    var isPrimaryDisabled = false
    var onPrimary: () -> Void

    @Environment(\.appAccentProminentTint) private var prominentTint

    var body: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            Button(cancelTitle, role: .cancel, action: onCancel)
                .font(.headline)
                .buttonStyle(.bordered)
                .controlSize(.large)
            Button(primaryTitle, role: primaryRole, action: onPrimary)
                .font(.headline)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(primaryRole == .destructive ? .red : prominentTint)
                .disabled(isPrimaryDisabled)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.top, SudylkoModalLayout.footerSpacing - FormLayout.groupSpacing)
    }
}

// MARK: - Standard modals

struct ArchiveSaveModal: View {
    let gameTitle: String
    var onCancel: () -> Void
    var onArchive: () -> Void

    var body: some View {
        SudylkoModal(
            title: ArchiveSaveConfirmation.title(gameTitle: gameTitle),
            subtitle: ArchiveSaveConfirmation.inProgressMessage
        ) {
            EmptyView()
        } footer: {
            SudylkoModalFooter(
                onCancel: onCancel,
                primaryTitle: "Archive",
                primaryRole: .destructive,
                onPrimary: onArchive
            )
        }
    }
}

struct DeleteAllSavesModal: View {
    var onCancel: () -> Void
    var onDelete: () -> Void

    var body: some View {
        SudylkoModal(
            title: "Delete all saves?",
            subtitle: "Removes every saved game from this Mac. Achievements and lifetime statistics are not changed."
        ) {
            EmptyView()
        } footer: {
            SudylkoModalFooter(
                onCancel: onCancel,
                primaryTitle: "Delete all",
                primaryRole: .destructive,
                onPrimary: onDelete
            )
        }
    }
}

struct RestartPuzzleModal: View {
    var onCancel: () -> Void
    var onRestart: () -> Void

    var body: some View {
        SudylkoModal(
            title: "Restart this puzzle?",
            subtitle: "Your progress on this puzzle will be lost."
        ) {
            EmptyView()
        } footer: {
            SudylkoModalFooter(
                onCancel: onCancel,
                primaryTitle: "Restart",
                primaryRole: .destructive,
                onPrimary: onRestart
            )
        }
    }
}

// MARK: - Detail-column modal host (sidebar stays interactive on macOS)

/// Dims only the detail pane; tap the scrim to dismiss. Use with explicit `onDismiss` (not `\.dismiss`).
struct SudylkoDetailModalOverlay<Modal: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder var modal: () -> Modal

    @Environment(\.colorScheme) private var colorScheme

    private var scrimOpacity: Double {
        colorScheme == .dark ? 0.42 : 0.26
    }

    var body: some View {
        ZStack {
            Color.black.opacity(scrimOpacity)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
                .accessibilityLabel("Dismiss")
                .accessibilityAddTraits(.isButton)

            modal()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .onExitCommand(perform: onDismiss)
        #endif
    }
}
