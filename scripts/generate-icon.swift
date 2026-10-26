// Writes the release icon into build/: the Icon Composer AppIcon.icon that actool compiles, and AppIcon.icns for
// macOS before 26. release-kit runs it with the repo root as the only argument when build/AppIcon.icns is missing or
// older than this script.
//
// The artwork is the blue light and dark tiles the app draws on its Dock tile at launch (`DockIconRenderer`), which
// re-tints the running icon to the chosen accent.
import AppKit
import Foundation

enum Appearance {
    case light
    case dark
}

struct Palette {
    let canvas: NSColor
    let cellNeutral: NSColor
    let grid: NSColor
    let givenDigit: NSColor
    let accent: NSColor
    let accentCellFillAlpha: CGFloat

    static func make(_ appearance: Appearance) -> Palette {
        switch appearance {
        case .light:
            Palette(
                canvas: .white,
                cellNeutral: NSColor(white: 0.97, alpha: 1),
                grid: NSColor(white: 0.78, alpha: 1),
                givenDigit: NSColor(white: 0.12, alpha: 1),
                accent: NSColor(srgbRed: 0, green: 0.48, blue: 1, alpha: 1),
                accentCellFillAlpha: 0.14
            )
        case .dark:
            Palette(
                canvas: NSColor(white: 0.12, alpha: 1),
                cellNeutral: NSColor(white: 0.18, alpha: 1),
                grid: NSColor(white: 0.42, alpha: 1),
                givenDigit: NSColor(white: 0.92, alpha: 1),
                accent: NSColor(srgbRed: 0, green: 0.48, blue: 1, alpha: 1),
                accentCellFillAlpha: 0.22
            )
        }
    }
}

/// Same corner of a puzzle as `DockIconRenderer.digits`: givens in the digit color, entries in the accent.
let digits: [(row: Int, col: Int, text: String, isGiven: Bool)] = [
    (0, 0, "9", true),
    (0, 2, "7", false),
    (1, 0, "3", false),
    (1, 1, "2", true),
    (2, 1, "5", true),
    (2, 2, "1", false),
]

let canvas: CGFloat = 1024
/// The grid overflows the canvas slightly so the outer lines sit under the icon mask.
let gridFill: CGFloat = 1.08
/// Apple's macOS icon template: an 824 pt body centered on the 1024 pt canvas.
let templateBody: CGFloat = 824
let templateCornerFraction: CGFloat = 185.4 / 824

func drawArtwork(in rect: NSRect, palette: Palette) {
    palette.canvas.setFill()
    rect.fill()

    let side = rect.width * gridFill
    let grid = NSRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
    let cell = side / 3

    func cellRect(row: Int, col: Int) -> NSRect {
        NSRect(x: grid.minX + CGFloat(col) * cell, y: grid.minY + CGFloat(2 - row) * cell, width: cell, height: cell)
    }

    for spec in digits {
        let fill = spec.isGiven ? palette.cellNeutral : palette.accent.withAlphaComponent(palette.accentCellFillAlpha)
        fill.setFill()
        cellRect(row: spec.row, col: spec.col).fill()
    }

    palette.grid.setStroke()
    for index in 0...3 {
        let offset = CGFloat(index) * cell
        let vertical = NSBezierPath()
        vertical.move(to: NSPoint(x: grid.minX + offset, y: grid.minY))
        vertical.line(to: NSPoint(x: grid.minX + offset, y: grid.maxY))
        vertical.lineWidth = 4 * rect.width / canvas
        vertical.stroke()
        let horizontal = NSBezierPath()
        horizontal.move(to: NSPoint(x: grid.minX, y: grid.minY + offset))
        horizontal.line(to: NSPoint(x: grid.maxX, y: grid.minY + offset))
        horizontal.lineWidth = 4 * rect.width / canvas
        horizontal.stroke()
    }

    for spec in digits {
        let font = NSFont.systemFont(ofSize: cell * 0.58, weight: spec.isGiven ? .bold : .semibold)
        let text = NSAttributedString(
            string: spec.text,
            attributes: [.font: font, .foregroundColor: spec.isGiven ? palette.givenDigit : palette.accent]
        )
        let size = text.size()
        let target = cellRect(row: spec.row, col: spec.col)
        text.draw(at: NSPoint(x: target.midX - size.width / 2, y: target.midY - size.height / 2))
    }
}

enum Surface {
    /// Square and opaque, for Icon Composer, which applies the shape, glass and shadow itself.
    case fullBleed
    /// The template body clipped to its rounded rectangle on a transparent canvas, for `.icns`.
    case macOSTemplate
}

func render(pixels: Int, appearance: Appearance, surface: Surface) -> Data? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    bitmap.size = NSSize(width: canvas, height: canvas)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let palette = Palette.make(appearance)
    switch surface {
    case .fullBleed:
        drawArtwork(in: NSRect(x: 0, y: 0, width: canvas, height: canvas), palette: palette)
    case .macOSTemplate:
        let origin = (canvas - templateBody) / 2
        let body = NSRect(x: origin, y: origin, width: templateBody, height: templateBody)
        let radius = templateBody * templateCornerFraction
        NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius).addClip()
        drawArtwork(in: body, palette: palette)
    }
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

func write(_ data: Data?, to url: URL) throws {
    guard let data else {
        fputs("generate-icon: could not render \(url.lastPathComponent)\n", stderr)
        exit(1)
    }
    try data.write(to: url)
}

func writeIconComposerBundle(in build: URL) throws {
    let bundle = build.appending(path: "AppIcon.icon", directoryHint: .isDirectory)
    try? FileManager.default.removeItem(at: bundle)
    let assets = bundle.appending(path: "Assets", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
    try write(render(pixels: 1024, appearance: .light, surface: .fullBleed), to: assets.appending(path: "grid-light.png"))
    try write(render(pixels: 1024, appearance: .dark, surface: .fullBleed), to: assets.appending(path: "grid-dark.png"))
    let json = """
    {
      "fill-specializations" : [
        { "value" : { "solid" : "srgb:1.00000,1.00000,1.00000,1.00000" } },
        { "appearance" : "dark", "value" : { "solid" : "srgb:0.12000,0.12000,0.12000,1.00000" } }
      ],
      "groups" : [
        {
          "layers" : [
            {
              "image-name-specializations" : [
                { "value" : "grid-light.png" },
                { "appearance" : "dark", "value" : "grid-dark.png" }
              ],
              "name" : "Grid"
            }
          ],
          "name" : "Grid"
        }
      ],
      "supported-platforms" : {
        "squares" : "shared"
      }
    }
    """
    try json.write(to: bundle.appending(path: "icon.json"), atomically: true, encoding: .utf8)
}

func writeIcns(in build: URL) throws {
    let iconset = build.appending(path: "AppIcon.iconset", directoryHint: .isDirectory)
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    for points in [16, 32, 128, 256, 512] {
        try write(
            render(pixels: points, appearance: .light, surface: .macOSTemplate),
            to: iconset.appending(path: "icon_\(points)x\(points).png"))
        try write(
            render(pixels: points * 2, appearance: .light, surface: .macOSTemplate),
            to: iconset.appending(path: "icon_\(points)x\(points)@2x.png"))
    }
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", build.appending(path: "AppIcon.icns").path]
    try iconutil.run()
    iconutil.waitUntilExit()
    guard iconutil.terminationStatus == 0 else {
        fputs("generate-icon: iconutil exited \(iconutil.terminationStatus)\n", stderr)
        exit(iconutil.terminationStatus)
    }
}

let root = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    : URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let build = root.appending(path: "build", directoryHint: .isDirectory)
do {
    try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
    try writeIconComposerBundle(in: build)
    try writeIcns(in: build)
} catch {
    fputs("generate-icon: \(error)\n", stderr)
    exit(1)
}
