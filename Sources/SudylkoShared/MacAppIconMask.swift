#if os(macOS)
import AppKit
import SwiftUI

/// Masks runtime dock artwork to the same squircle as bundled `AppIcon.icns`.
public enum MacAppIconMask {
    /// When set (e.g. icon export after the `.app` is assembled), mask shape matches that bundle.
    public static var maskBundlePath: String?

    private static var maskTemplateCache: [Int: NSImage] = [:]

    /// Clips artwork to the app squircle (from `AppIcon.icns` alpha), not a rounded rect.
    public static func applyingMask(to image: NSImage) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }

        let template = squircleAlphaMask(size: size)
        let masked = NSImage(size: size)
        masked.lockFocus()
        defer { masked.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        image.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
        template.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
        return masked
    }

    /// Opaque inside the squircle, transparent outside — shape from bundled icon assets.
    public static func squircleAlphaMask(size: NSSize) -> NSImage {
        let key = Int(size.width.rounded())
        if let cached = maskTemplateCache[key] {
            return cached
        }

        let template: NSImage
        if let icon = loadBundledIcon(scaledTo: size) {
            template = icon
        } else {
            template = fallbackSquircleMask(size: size)
        }

        maskTemplateCache[key] = template
        return template
    }

    // MARK: - Bundled icon

    private static func bundledIconURL() -> URL? {
        if let bundlePath = maskBundlePath {
            let icns = URL(fileURLWithPath: bundlePath)
                .appendingPathComponent("Contents/Resources/AppIcon.icns")
            if FileManager.default.fileExists(atPath: icns.path) {
                return icns
            }
        }
        return Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
    }

    private static func loadBundledIcon(scaledTo size: NSSize) -> NSImage? {
        guard let url = bundledIconURL(),
              let image = NSImage(contentsOf: url),
              image.size.width > 0,
              image.size.height > 0 else {
            return nil
        }
        return scaleImage(image, to: size)
    }

    private static func scaleImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let scaled = NSImage(size: size)
        scaled.lockFocus()
        defer { scaled.unlockFocus() }
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1
        )
        return scaled
    }

    private static func fallbackSquircleMask(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        guard let context = NSGraphicsContext.current?.cgContext else { return image }

        let rect = CGRect(origin: .zero, size: size)
        context.clear(rect)
        context.setFillColor(NSColor.white.cgColor)
        context.addPath(continuousSquirclePath(in: rect))
        context.fillPath()
        return image
    }

    /// macOS app-icon superellipse (~22.37% corner radius, continuous curve).
    private static func continuousSquirclePath(in rect: CGRect) -> CGPath {
        let radius = min(rect.width, rect.height) * 0.2237
        let swiftUIPath = Path(
            roundedRect: rect,
            cornerRadius: radius,
            style: .continuous
        )
        var transform = CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -rect.height)
        return swiftUIPath.cgPath.copy(using: &transform) ?? swiftUIPath.cgPath
    }
}
#endif
