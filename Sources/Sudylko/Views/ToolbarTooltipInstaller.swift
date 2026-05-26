import SwiftUI
#if os(macOS)
import AppKit

/// Attaches a native `toolTip` to the nearest AppKit control (toolbar buttons sometimes skip SwiftUI `.help`).
struct ToolbarTooltipInstaller: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.tooltipText = text
        return view
    }

    func updateNSView(_ nsView: InstallerView, context: Context) {
        nsView.tooltipText = text
        nsView.installTooltip()
    }

    final class InstallerView: NSView {
        var tooltipText = ""

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            installTooltip()
        }

        override func layout() {
            super.layout()
            installTooltip()
        }

        func installTooltip() {
            guard !tooltipText.isEmpty else { return }
            var node: NSView? = superview
            while let current = node {
                if let control = current as? NSControl {
                    control.toolTip = tooltipText
                    return
                }
                node = current.superview
            }
        }
    }
}
#endif

extension View {
    /// Standard macOS hover tool tip; on iOS uses SwiftUI `.help` only.
    func macOSTooltip(_ text: String) -> some View {
        #if os(macOS)
        help(text)
            .background(ToolbarTooltipInstaller(text: text))
        #else
        help(text)
        #endif
    }
}
