import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("windowBackgroundMaterial") private var materialRaw = WindowBackgroundMaterial.default.rawValue

    private var material: WindowBackgroundMaterial {
        WindowBackgroundMaterial(rawValue: materialRaw) ?? .default
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(
                material: material.nsMaterial,
                blendingMode: .behindWindow,
                colorScheme: colorScheme
            )
            if colorScheme == .dark {
                Color.black.opacity(darkOverlayOpacity)
            }
        }
        .ignoresSafeArea()
    }

    private var darkOverlayOpacity: CGFloat {
        switch material {
        case .solid: 0.38
        case .soft: 0.24
        case .standard: 0.32
        case .translucent: 0.16
        case .light: 0.2
        case .hud: 0.28
        }
    }
}

extension View {
    func appBackground() -> some View {
        background {
            AppBackground()
        }
    }
}
