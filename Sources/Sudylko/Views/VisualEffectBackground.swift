import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

private let glassMaterialTintOpacity: CGFloat = 0.16

#if os(macOS)
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var colorScheme: ColorScheme

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        apply(view)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        apply(nsView)
    }

    private func apply(_ view: NSVisualEffectView) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = colorScheme == .light
        view.alphaValue = 1
        view.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
    }
}
#endif

extension View {
    @ViewBuilder
    private func glassMaterialStack(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        material: WindowBackgroundMaterial
    ) -> some View {
        ZStack {
            #if os(macOS)
            VisualEffectBackground(
                material: material.nsMaterial,
                blendingMode: .behindWindow,
                colorScheme: colorScheme
            )
            #else
            Rectangle()
                .fill(.clear)
                .background(material.swiftUIMaterial)
            #endif
            AppTheme.sidebarTint(accent: accent, colorScheme: colorScheme)
                .opacity(glassMaterialTintOpacity)
        }
    }

    func glassSidebar(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        material: WindowBackgroundMaterial
    ) -> some View {
        background {
            glassMaterialStack(accent: accent, colorScheme: colorScheme, material: material)
                .ignoresSafeArea()
        }
    }

    /// Sidebar-style vibrancy and accent tint, clipped to a rounded rect (e.g. quick-start tiles).
    func glassPanel(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        material: WindowBackgroundMaterial,
        cornerRadius: CGFloat = 14
    ) -> some View {
        background {
            glassMaterialStack(accent: accent, colorScheme: colorScheme, material: material)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
