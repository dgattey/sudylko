import AppKit
import SwiftUI

/// Dock icon artwork plus standard `NSDockTile` badge labels (timer / Paused).
///
/// Mac App Store: only `NSApplication.applicationIconImage` may change the Dock icon at runtime.
/// Do not modify the app bundle on disk (`NSWorkspace.setIcon`, rewriting `AppIcon.icns`, etc.).
/// The quit-state icon comes from the signed `AppIcon.icns` produced at build time.
public enum DockIconRenderer {
    private static let canvasSize: CGFloat = 1024
    /// Standard macOS icon content inset (~9% margin).
    private static let iconInset: CGFloat = 96
    /// Base point size for the Dock tile; rasterized at screen scale for sharpness.
    private static let dockIconPointSize: CGFloat = 128

    private static var dockRasterPixelSize: Int {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        return max(128, Int((dockIconPointSize * scale).rounded()))
    }
    private static let accentDefaultsKey = "accentColor"
    private static let appearanceDefaultsKey = "appearanceMode"

    private struct CacheKey: Equatable {
        let accent: AppAccentColor
        let colorScheme: ColorScheme
        let applyAccentDigits: Bool
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

    private static var cachedKey: CacheKey?
    private static var cachedImage: NSImage?
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

    /// Resolves appearance from stored settings (same keys as the app).
    public static func resolvedDockColorScheme() -> ColorScheme {
        let raw = UserDefaults.standard.string(forKey: appearanceDefaultsKey) ?? "system"
        switch raw {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? .dark : .light
        }
    }

    /// Applies saved accent and appearance artwork on launch (before first window).
    public static func applySavedAccentDockArtwork() {
        let raw = UserDefaults.standard.string(forKey: accentDefaultsKey)
            ?? AppAccentColor.blue.rawValue
        let accent = AppAccentColor(rawValue: raw) ?? .blue
        let colorScheme = resolvedDockColorScheme()
        applyDockArtwork(accent: accent, colorScheme: colorScheme, applyAccentDigits: true)
        applyBadgeLabel(nil)
    }

    public static func updateDockIcon(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        inGame: Bool,
        showPaused: Bool,
        timerText: String?
    ) {
        applyDockArtwork(accent: accent, colorScheme: colorScheme, applyAccentDigits: true)

        let badgeLabel: String?
        if inGame, showPaused {
            badgeLabel = "Paused"
        } else if inGame, let timerText, !timerText.isEmpty {
            badgeLabel = timerText
        } else {
            badgeLabel = nil
        }
        applyBadgeLabel(badgeLabel)
    }

    /// Writes `AppIcon.iconset` using the same masked pipeline as the running Dock tile.
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
            let image = maskedIconImage(
                pixelSize: entry.pixels,
                accent: accent,
                colorScheme: scheme,
                applyAccentDigits: true
            )
            guard let data = pngData(from: image) else { continue }
            try? data.write(to: url)
        }
    }

    private static func applyDockArtwork(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        applyAccentDigits: Bool
    ) {
        let key = CacheKey(accent: accent, colorScheme: colorScheme, applyAccentDigits: applyAccentDigits)
        if cachedKey != key || cachedImage == nil {
            cachedKey = key
            cachedImage = dockTileImage(
                accent: accent,
                colorScheme: colorScheme,
                applyAccentDigits: applyAccentDigits
            )
            NSApplication.shared.applicationIconImage = cachedImage
        }
    }

    /// Running Dock tile: squircle interior from live artwork, outer glow from system compositing.
    ///
    /// `NSWorkspace`’s full icon at dock sizes is a rounded rect; only pixels *outside* the
    /// bundled squircle mask are taken from it so quit and running silhouettes match.
    private static func dockTileImage(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        applyAccentDigits: Bool
    ) -> NSImage {
        let pixelSize = dockRasterPixelSize
        let size = NSSize(width: pixelSize, height: pixelSize)
        let artwork = maskedIconImage(
            pixelSize: pixelSize,
            accent: accent,
            colorScheme: colorScheme,
            applyAccentDigits: applyAccentDigits
        )

        let composite = NSImage(size: size)
        composite.lockFocus()
        defer { composite.unlockFocus() }
        let rect = NSRect(origin: .zero, size: size)

        if let glowRing = dockGlowRing(size: size) {
            glowRing.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
        }
        artwork.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        return composite
    }

    /// Workspace icon with squircle interior removed — bezel / shadow only.
    private static func dockGlowRing(size: NSSize) -> NSImage? {
        let bundlePath = MacAppIconMask.maskBundlePath ?? Bundle.main.bundlePath
        guard FileManager.default.fileExists(atPath: bundlePath) else { return nil }

        // Sample large so the outer ring is not lost when the Dock scales down.
        let sampleSide = max(size.width, 512)
        let sampleSize = NSSize(width: sampleSide, height: sampleSide)

        let workspace = NSWorkspace.shared.icon(forFile: bundlePath)
        workspace.size = sampleSize
        let squircleMask = MacAppIconMask.squircleAlphaMask(size: sampleSize)

        let sampleGlow = NSImage(size: sampleSize)
        sampleGlow.lockFocus()
        defer { sampleGlow.unlockFocus() }
        let sampleRect = NSRect(origin: .zero, size: sampleSize)
        workspace.draw(in: sampleRect, from: .zero, operation: .copy, fraction: 1)
        squircleMask.draw(in: sampleRect, from: .zero, operation: .destinationOut, fraction: 1)

        return scaleImage(sampleGlow, to: Int(size.width.rounded()))
    }

    /// Scale artwork, then clip to the app squircle — used for `AppIcon.icns` export (no Dock chrome baked in).
    private static func maskedIconImage(
        pixelSize: Int,
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        applyAccentDigits: Bool
    ) -> NSImage {
        let artwork = renderArtwork(accent: accent, colorScheme: colorScheme, applyAccentDigits: applyAccentDigits)
        let scaled = scaleImage(artwork, to: pixelSize)
        return MacAppIconMask.applyingMask(to: scaled)
    }

    private static func applyBadgeLabel(_ label: String?) {
        guard label != lastBadgeLabel else { return }
        lastBadgeLabel = label
        let dockTile = NSApplication.shared.dockTile
        dockTile.badgeLabel = label
        dockTile.display()
    }

    public static func renderIcon(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        applyAccentDigits: Bool
    ) -> NSImage {
        renderArtwork(accent: accent, colorScheme: colorScheme, applyAccentDigits: applyAccentDigits)
    }

    private static func renderArtwork(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        applyAccentDigits: Bool
    ) -> NSImage {
        let palette = IconPalette.make(colorScheme: colorScheme)
        let size = NSSize(width: canvasSize, height: canvasSize)
        let image = NSImage(size: size)
        image.lockFocus()

        let fullRect = NSRect(origin: .zero, size: size)
        palette.canvas.setFill()
        fullRect.fill()

        let iconRect = fullRect.insetBy(dx: iconInset, dy: iconInset)
        let gridScale: CGFloat = 1.22 * 0.95
        let gridSide = iconRect.width * gridScale
        let gridRect = NSRect(
            x: iconRect.midX - gridSide / 2,
            y: iconRect.midY - gridSide / 2,
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

        image.unlockFocus()
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
