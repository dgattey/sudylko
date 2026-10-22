#if os(macOS)
import AppKit
import SwiftUI

/// The running app's icon, tinted to the chosen accent and appearance, with the timer or "Paused" as the Dock badge.
///
/// The image goes on both `applicationIconImage` (Cmd-Tab, About, notifications) and `dockTile.contentView`, which
/// the Dock prefers. Finder and the quit Dock tile use the bundled blue icon from `scripts/generate-icon.swift`,
/// which draws the same artwork.
@MainActor
enum DockIconRenderer {
    private enum Layout {
        static let canvas: CGFloat = 1024
        /// Grid fill vs canvas (zoom); macOS applies icon shape — do not pre-mask.
        static let gridFill: CGFloat = 1.08
        static let masterPixels = 512
        static let dockTilePoints: CGFloat = 128
        /// macOS Big Sur+ icon template: the visible body fills 824/1024 of the canvas
        /// (≈80%), leaving ≈10% margin per side so the dock tile matches other system apps.
        static let templateBodyFraction: CGFloat = 824.0 / 1024.0
        /// Squircle corner radius as a fraction of body size, per Apple's icon template.
        static let templateCornerFraction: CGFloat = 185.4 / 824.0
    }

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

    private static var installedKey: IconKey?
    private static var lastBadgeLabel: String?

    private static let digits: [(row: Int, col: Int, text: String, isGiven: Bool)] = [
        (0, 0, "9", true),
        (0, 2, "7", false),
        (1, 0, "3", false),
        (1, 1, "2", true),
        (2, 1, "5", true),
        (2, 2, "1", false),
    ]

    static func updateDockIcon(
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

    /// Re-installs the dock tile only when accent or appearance changed. Without this guard
    /// the per-second timer tick would rebuild the contentView and IPC to the Dock every call.
    private static func applyRunningDockIcon(accent: AppAccentColor, colorScheme: ColorScheme) {
        let key = IconKey(accent: accent, colorScheme: colorScheme)
        guard installedKey != key else { return }
        let master = iconImage(accent: accent, colorScheme: colorScheme, pixelSize: Layout.masterPixels)
        let image = squircleClippedDockImage(from: master, tilePoints: Layout.dockTilePoints)
        let app = NSApplication.shared
        app.applicationIconImage = image
        installDockTileContentView(image, on: app.dockTile)
        installedKey = key
    }

    /// Draws the master into a centered body the size of the Apple template (≈80% of the
    /// tile) and clips to that body's squircle. The transparent margin around the body is
    /// what makes the icon line up visually with Terminal, Settings, and other system apps
    /// in the Dock.
    private static func squircleClippedDockImage(from master: NSImage, tilePoints: CGFloat) -> NSImage {
        let body = tilePoints * Layout.templateBodyFraction
        let origin = (tilePoints - body) / 2

        let size = NSSize(width: tilePoints, height: tilePoints)
        let clipped = NSImage(size: size)
        clipped.lockFocus()
        NSGraphicsContext.saveGraphicsState()
        defer {
            NSGraphicsContext.restoreGraphicsState()
            clipped.unlockFocus()
        }
        let bodyRect = NSRect(x: origin, y: origin, width: body, height: body)
        let radius = body * Layout.templateCornerFraction
        NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius).addClip()
        master.draw(
            in: bodyRect,
            from: NSRect(origin: .zero, size: master.size),
            operation: .copy,
            fraction: 1
        )
        return clipped
    }

    private static func installDockTileContentView(_ image: NSImage, on dockTile: NSDockTile) {
        let tile = Layout.dockTilePoints
        let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: tile, height: tile))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        dockTile.contentView = imageView
        dockTile.display()
    }

    private static func applyBadgeLabel(_ label: String?, on dockTile: NSDockTile) {
        guard label != lastBadgeLabel else { return }
        lastBadgeLabel = label
        dockTile.badgeLabel = label
        dockTile.display()
    }

    private static func iconImage(
        accent: AppAccentColor,
        colorScheme: ColorScheme,
        pixelSize: Int
    ) -> NSImage {
        let artwork = renderProductIcon(accent: accent, colorScheme: colorScheme)
        return scaleImage(artwork, to: pixelSize)
    }

    /// Square master artwork; macOS applies icon shape and Dock chrome.
    private static func renderProductIcon(accent: AppAccentColor, colorScheme: ColorScheme) -> NSImage {
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

        drawCellBackgrounds(in: gridRect, accent: accent, colorScheme: colorScheme, palette: palette)
        drawGrid(in: gridRect, palette: palette)
        drawDigits(in: gridRect, accent: accent, colorScheme: colorScheme, palette: palette)

        return image
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
        palette: IconPalette
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
            let fill = spec.isGiven ? palette.cellNeutral : accentFill.withAlphaComponent(palette.accentCellFillAlpha)
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
        palette: IconPalette
    ) {
        let cellW = rect.width / 3
        let cellH = rect.height / 3
        let accentColor = accent.nsAccentForeground(for: colorScheme)
        for spec in digits {
            let fontSize = min(cellW, cellH) * 0.58
            let font = NSFont.systemFont(
                ofSize: fontSize,
                weight: spec.isGiven ? .bold : .semibold
            )
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: spec.isGiven ? palette.givenDigit : accentColor,
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
