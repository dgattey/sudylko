import SwiftUI

// MARK: - Unified fills (raised cards, lists, panels, tracks, chips)

enum InspectorSurface {
    /// Neutral elevated fill shared by summary cards, grouped lists, and chart panels.
    static func raisedFillOpacity(for colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.44 : 0.64
    }

    /// Recessed track behind segmented controls and inset fields.
    static func trackFillOpacity(for colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.10 : 0.06
    }

    static func borderOpacity(for colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.14 : 0.11
    }

    /// Difficulty / status chips (tinted capsule on raised neutrals).
    static let chipFillOpacity: Double = 0.16
    static let chipBorderOpacity: Double = 0.32

    /// Neutral track inside progress bars on inspector panels.
    static func progressTrackOpacity(for colorScheme: ColorScheme) -> Double {
        raisedFillOpacity(for: colorScheme) * 0.55
    }
}

// MARK: - Inspector (home trailing pane + sectioned home content)

struct InspectorPageHeader: View {
    let title: String
    var subtitle: String?
    var trailingSummary: String?
    var showsResetMenu: Bool = false
    var resetPanel: SidebarPanel?
    var onRequestReset: ((ProgressResetKind) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorLayout.pageSubtitleSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.title2)
                Spacer(minLength: 8)
                if let trailingSummary {
                    Text(trailingSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                if showsResetMenu, let resetPanel, let onRequestReset {
                    ProgressResetMenu(panel: resetPanel, onSelect: onRequestReset)
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct InspectorSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Sidebar list section header with disclosure chevron; toggles without animating row removal.
struct CollapsibleSidebarSectionHeader: View {
    let title: String
    @Binding var isCollapsed: Bool

    var body: some View {
        Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isCollapsed.toggle()
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .animation(.easeInOut(duration: 0.15), value: isCollapsed)
                InspectorSectionLabel(title: title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.top, SidebarMetrics.sectionHeaderTopPadding)
        .padding(.bottom, SidebarMetrics.sectionHeaderBottomPadding)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(isCollapsed ? "collapsed" : "expanded")
    }
}

struct InspectorPanelHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorLayout.panelHeadingSpacing) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct InspectorGroupedList<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.vertical, InspectorLayout.groupedListVerticalPadding)
            .inspectorRaisedSurface(cornerRadius: InspectorLayout.listCardCornerRadius)
    }
}

// MARK: - Settings / forms

struct FormSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

struct FormToggleCaption: View {
    let title: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: FormLayout.controlDetailSpacing) {
            Text(title)
                .font(.body)
            Text(caption)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Modifiers

extension View {
    func inspectorScrollPadding() -> some View {
        padding(.vertical, InspectorLayout.scrollVerticalPadding)
    }

    func inspectorListRowPadding() -> some View {
        padding(.horizontal, InspectorLayout.listRowHorizontalPadding)
            .padding(.vertical, InspectorLayout.listRowVerticalPadding)
    }

    func inspectorGlassPanel(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        material: WindowBackgroundMaterial,
        cornerRadius: CGFloat = InspectorLayout.panelCornerRadius
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background {
            InspectorRaisedSurfaceShape(cornerRadius: cornerRadius)
        }
        .glassPanel(
            accent: accent,
            colorScheme: colorScheme,
            material: material,
            cornerRadius: cornerRadius
        )
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                Color.primary.opacity(InspectorSurface.borderOpacity(for: colorScheme)),
                lineWidth: 1
            )
        }
    }

    func inspectorRaisedSurface(cornerRadius: CGFloat) -> some View {
        background {
            InspectorRaisedSurfaceShape(cornerRadius: cornerRadius)
        }
    }

    func inspectorSummaryCard() -> some View {
        inspectorRaisedSurface(cornerRadius: InspectorLayout.summaryCardCornerRadius)
    }

    /// Recessed track (segmented control container, inset text fields).
    func inspectorControlTrack(cornerRadius: CGFloat = InspectorLayout.controlTrackCornerRadius) -> some View {
        modifier(InspectorControlTrackModifier(cornerRadius: cornerRadius))
    }

    func inspectorSegmentSelection(
        isSelected: Bool,
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        cornerRadius: CGFloat = InspectorLayout.controlSegmentCornerRadius
    ) -> some View {
        background {
            if isSelected {
                let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                shape
                    .fill(accent.selectionFill(for: colorScheme))
                    .overlay(
                        shape.strokeBorder(accent.selectionBorder(for: colorScheme), lineWidth: 1)
                    )
            }
        }
    }
}

private struct InspectorControlTrackModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.background(
            Color.primary.opacity(InspectorSurface.trackFillOpacity(for: colorScheme)),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}

private struct InspectorRaisedSurfaceShape: View {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.quaternary.opacity(InspectorSurface.raisedFillOpacity(for: colorScheme)))
            .overlay(
                shape.strokeBorder(
                    Color.primary.opacity(InspectorSurface.borderOpacity(for: colorScheme)),
                    lineWidth: 1
                )
            )
    }
}
