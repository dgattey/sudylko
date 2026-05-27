#if os(macOS)
import AppKit
import SwiftUI

/// Product icon — one bitmap (`masterIconImage`), no custom mask or reflection.
///
/// - **Running:** `applicationIconImage` (built-in Dock chrome).
/// - **Quit:** `NSDockTilePlugIn` shows the same bitmap in `contentView` (accent from preferences).
/// - **Finder:** bundled `AppIcon.icns` from the same renderer at build time.
public enum DockIconRenderer {
    private enum Layout {
        static let canvas: CGFloat = 1024
        /// Grid fill vs canvas (zoom); macOS applies icon shape — do not pre-mask.
        static let gridFill: CGFloat = 1.08
        static let masterPixels = 512
        static let dockTilePoints: CGFloat = 128
        /// `contentView` has no system margin; inset to match `applicationIconImage` weight.
        static let dockTileBodyFraction: CGFloat = 0.82
    }

    private static let accentDefaultsKey = "accentColor"
    private static let appearanceDefaultsKey = "appearanceMode"

    private struct IconKey: Equatable {
        let accent: AppAccentColor
        let colorScheme: ColorScheme
    }

    private struct IconPalette {
        let canvas: NSColor
        let cellNeutral: NSColor
        let grid: NSColor
        let givenDigit: NSColor
        let accentCellFillAlpha: CGFloat

        static func make(colorScheme: ColorScheme) -> IconPalette {
            switch colorScheme {
            case .dark:
                IconPalette(
                    canvas: NSColor(white: 0.12, alpha: 1),
                    cellNeutral: NSColor(white: 0.18, alpha: 1),
                    grid: NSColor(white: 0.42, alpha: 1),
                    givenDigit: NSColor(white: 0.92, alpha: 1),
                    accentCellFillAlpha: 0.22
                )
            default:
                IconPalette(
                    canvas: .white,
                    cellNeutral: NSColor(white: 0.97, alpha: 1),
                    grid: NSColor(white: 0.78, alpha: 1),
                    givenDigit: NSColor(white: 0.12, alpha: 1),
                    accentCellFillAlpha: 0.14
                )
            }
        }
    }

    private static var cachedKey: IconKey?
    private static var cachedMasterImage: NSImage?
    private static var lastBadgeLabel: String?

    private static let digits: [(row: Int, col: Int, text: String, isGiven: Bool)] = [
        (0, 0, "9", true),
        (0, 2, "7", false),
        (1, 0, "3", false),
        (1, 1, "2", true),
        (2, 1, "5", true),
        (2, 2, "1", false),
    ]

    private static let iconsetSizes: [(name: String, pixels: Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    public static func configureHostApplicationMask() {}

    public static func resolvedDockColorScheme() -> ColorScheme {
        let raw = SudylkoPreferenceAccess.string(forKey: appearanceDefaultsKey)
            ?? UserDefaults.standard.string(forKey: appearanceDefaultsKey)
            ?? "system"
        switch raw {
        case "light": return .light
        case "dark": return .dark
        default:
            let appearance = NSApp?.effectiveAppearance ?? NSAppearance.currentDrawing()
            return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        }
    }

    public static func invalidateCache() {
        cachedKey = nil
        cachedMasterImage = nil
    }

    public static func applySavedAccentDockArtwork() {
        updateDockIcon(
            accent: savedAccent(),
            colorScheme: resolvedDockColorScheme(),
            inGame: false,
            showPaused: false,
            timerText: nil
        )
    }

    /// Quit: same master bitmap as running (plug-in has no `applicationIconImage`).
    /// Refreshes the dock-plugin pref cache before reading so we see the host's last-written
    /// accent/appearance; the host owns the mirror and the plug-in only reads from it.
    public static func applyQuitStateDockTile(_ dockTile: NSDockTile) {
        SudylkoPreferenceAccess.refreshDockPluginCache()
        let image = masterIconImage(
            accent: savedAccent(),
            colorScheme: resolvedDockColorScheme()
        )
        applyQuitDockTileContent(image, on: dockTile)
        applyBadgeLabel(nil, on: dockTile)
    }

    public static func updateDockIcon(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        inGame: Bool,
        showPaused: Bool,
        timerText: String?
    ) {
        applyRunningDockIcon(accent: accent, colorScheme: colorScheme)

        let badgeLabel: String?
        if inGame, showPaused {
            badgeLabel = "Paused"
        } else if inGame, let timerText, !timerText.isEmpty {
            badgeLabel = timerText
        } else {
            badgeLabel = nil
        }
        applyBadgeLabel(badgeLabel, on: NSApplication.shared.dockTile)
    }

    public static func exportIconSet(
        to iconsetDirectory: URL,
        accent: AppAccentColor,
        colorScheme: ColorScheme? = nil
    ) {
        let scheme = colorScheme ?? resolvedDockColorScheme()
        let fm = FileManager.default
        try? fm.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)
        for entry in iconsetSizes {
            let url = iconsetDirectory.appendingPathComponent(entry.name)
            let image = iconImage(
                accent: accent,
                colorScheme: scheme,
                pixelSize: entry.pixels
            )
            guard let data = pngData(from: image) else { continue }
            try? data.write(to: url)
        }
    }

    public static func renderIcon(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        applyAccentDigits: Bool
    ) -> NSImage {
        iconImage(
            accent: accent,
            colorScheme: colorScheme,
            pixelSize: Int(Layout.canvas),
            applyAccentDigits: applyAccentDigits
        )
    }

    private static func savedAccent() -> AppAccentColor {
        let raw = SudylkoPreferenceAccess.string(forKey: accentDefaultsKey)
            ?? UserDefaults.standard.string(forKey: accentDefaultsKey)
            ?? AppAccentColor.blue.rawValue
        return AppAccentColor(rawValue: raw) ?? .blue
    }

    private static func applyRunningDockIcon(accent: AppAccentColor, colorScheme: ColorScheme) {
        let app = NSApplication.shared
        app.dockTile.contentView = nil
        app.applicationIconImage = masterIconImage(accent: accent, colorScheme: colorScheme)
        app.dockTile.display()
    }

    private static func applyQuitDockTileContent(_ image: NSImage, on dockTile: NSDockTile) {
        let tile = Layout.dockTilePoints
        let body = tile * Layout.dockTileBodyFraction
        let origin = (tile - body) / 2

        let container = NSView(frame: NSRect(x: 0, y: 0, width: tile, height: tile))
        let imageView = NSImageView(frame: NSRect(x: origin, y: origin, width: body, height: body))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignCenter

        container.subviews.forEach { $0.removeFromSuperview() }
        container.addSubview(imageView)
        dockTile.contentView = container
        dockTile.display()
    }

    private static func applyBadgeLabel(_ label: String?, on dockTile: NSDockTile) {
        guard label != lastBadgeLabel else { return }
        lastBadgeLabel = label
        dockTile.badgeLabel = label
        dockTile.display()
    }

    private static func masterIconImage(accent: AppAccentColor, colorScheme: ColorScheme) -> NSImage {
        let key = IconKey(accent: accent, colorScheme: colorScheme)
        if cachedKey == key, let cachedMasterImage {
            return cachedMasterImage
        }
        let image = iconImage(
            accent: accent,
            colorScheme: colorScheme,
            pixelSize: Layout.masterPixels
        )
        cachedKey = key
        cachedMasterImage = image
        return image
    }

    private static func iconImage(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        pixelSize: Int,
        applyAccentDigits: Bool = true
    ) -> NSImage {
        let artwork = renderProductIcon(
            accent: accent,
            colorScheme: colorScheme,
            applyAccentDigits: applyAccentDigits
        )
        return scaleImage(artwork, to: pixelSize)
    }

    /// Square master artwork; macOS applies icon shape and Dock chrome.
    private static func renderProductIcon(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        applyAccentDigits: Bool
    ) -> NSImage {
        let palette = IconPalette.make(colorScheme: colorScheme)
        let size = NSSize(width: Layout.canvas, height: Layout.canvas)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let fullRect = NSRect(origin: .zero, size: size)
        palette.canvas.setFill()
        fullRect.fill()

        let gridSide = Layout.canvas * Layout.gridFill
        let gridRect = NSRect(
            x: fullRect.midX - gridSide / 2,
            y: fullRect.midY - gridSide / 2,
            width: gridSide,
            height: gridSide
        )

        drawCellBackgrounds(
            in: gridRect,
            accent: accent,
            colorScheme: colorScheme,
            palette: palette,
            applyAccentDigits: applyAccentDigits
        )
        drawGrid(in: gridRect, palette: palette)
        drawDigits(
            in: gridRect,
            accent: accent,
            colorScheme: colorScheme,
            palette: palette,
            applyAccentDigits: applyAccentDigits
        )

        return image
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private static func scaleImage(_ image: NSImage, to pixelSize: Int) -> NSImage {
        let target = NSSize(width: pixelSize, height: pixelSize)
        let scaled = NSImage(size: target)
        scaled.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: target),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1
        )
        scaled.unlockFocus()
        return scaled
    }

    private static func drawCellBackgrounds(
        in rect: NSRect,
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        palette: IconPalette,
        applyAccentDigits: Bool
    ) {
        let cellW = rect.width / 3
        let cellH = rect.height / 3
        let accentFill = accent.nsAccentForeground(for: colorScheme)
        for spec in digits {
            let cellRect = NSRect(
                x: rect.minX + CGFloat(spec.col) * cellW,
                y: rect.minY + CGFloat(2 - spec.row) * cellH,
                width: cellW,
                height: cellH
            )
            let fill: NSColor
            if applyAccentDigits, !spec.isGiven {
                fill = accentFill.withAlphaComponent(palette.accentCellFillAlpha)
            } else {
                fill = palette.cellNeutral
            }
            fill.setFill()
            cellRect.fill()
        }
    }

    private static func drawGrid(in rect: NSRect, palette: IconPalette) {
        let cellW = rect.width / 3
        let cellH = rect.height / 3
        palette.grid.setStroke()
        for i in 0...3 {
            let x = rect.minX + CGFloat(i) * cellW
            let y = rect.minY + CGFloat(i) * cellH
            let vertical = NSBezierPath()
            vertical.move(to: NSPoint(x: x, y: rect.minY))
            vertical.line(to: NSPoint(x: x, y: rect.maxY))
            vertical.lineWidth = 4
            vertical.stroke()
            let horizontal = NSBezierPath()
            horizontal.move(to: NSPoint(x: rect.minX, y: y))
            horizontal.line(to: NSPoint(x: rect.maxX, y: y))
            horizontal.lineWidth = 4
            horizontal.stroke()
        }
    }

    private static func drawDigits(
        in rect: NSRect,
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        palette: IconPalette,
        applyAccentDigits: Bool
    ) {
        let cellW = rect.width / 3
        let cellH = rect.height / 3
        let accentColor = accent.nsAccentForeground(for: colorScheme)
        for spec in digits {
            let useAccent = applyAccentDigits && !spec.isGiven
            let fontSize = min(cellW, cellH) * 0.58
            let font = NSFont.systemFont(
                ofSize: fontSize,
                weight: spec.isGiven ? .bold : .semibold
            )
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: useAccent ? accentColor : palette.givenDigit,
            ]
            let str = NSAttributedString(string: spec.text, attributes: attrs)
            let strSize = str.size()
            let cx = rect.minX + (CGFloat(spec.col) + 0.5) * cellW
            let cy = rect.minY + (CGFloat(2 - spec.row) + 0.5) * cellH
            str.draw(at: NSPoint(x: cx - strSize.width / 2, y: cy - strSize.height / 2))
        }
    }
}
#endif
