import AppKit
import SwiftUI

/// Aligns the NSWindow with the in-app appearance picker and publishes `NSApp.isActive`.
struct WindowConfigurator: NSViewRepresentable {
    let appearanceMode: AppearanceMode
    @Binding var isAppActive: Bool

    func makeNSView(context: Context) -> ThemedWindowAnchor {
        let view = ThemedWindowAnchor()
        view.onSystemAppearanceChange = {
            NotificationCenter.default.post(name: .sudylkoSystemThemeDidChange, object: nil)
        }
        view.onApplicationActiveChange = { active in
            isAppActive = active
        }
        return view
    }

    func updateNSView(_ nsView: ThemedWindowAnchor, context: Context) {
        nsView.onSystemAppearanceChange = {
            NotificationCenter.default.post(name: .sudylkoSystemThemeDidChange, object: nil)
        }
        nsView.onApplicationActiveChange = { active in
            isAppActive = active
        }
        DispatchQueue.main.async {
            configure(nsView.window, mode: appearanceMode)
            isAppActive = NSApp.isActive
        }
    }

    private func configure(_ window: NSWindow?, mode: AppearanceMode) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.appearance = mode.resolvedNSAppearance() ?? NSApp.effectiveAppearance
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.titlebarSeparatorStyle = .none
    }
}

/// Observes macOS light/dark changes and application active state.
final class ThemedWindowAnchor: NSView {
    var onSystemAppearanceChange: (() -> Void)?
    var onApplicationActiveChange: ((Bool) -> Void)?

    private var themeObserver: NSObjectProtocol?
    private var appActiveObservers: [NSObjectProtocol] = []
    private static var installedAppActiveObservers = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installThemeObserverIfNeeded()
        installApplicationActiveObserversIfNeeded()
    }

    private func installThemeObserverIfNeeded() {
        guard themeObserver == nil else { return }
        themeObserver = DistributedNotificationCenter.default().addObserver(
            forName: AppearanceMode.systemThemeDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onSystemAppearanceChange?()
        }
    }

    private func installApplicationActiveObserversIfNeeded() {
        guard !Self.installedAppActiveObservers else { return }
        Self.installedAppActiveObservers = true
        let center = NotificationCenter.default
        appActiveObservers.append(center.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onApplicationActiveChange?(false)
        })
        appActiveObservers.append(center.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onApplicationActiveChange?(true)
        })
        onApplicationActiveChange?(NSApp.isActive)
    }

    deinit {
        if let themeObserver {
            DistributedNotificationCenter.default().removeObserver(themeObserver)
        }
    }
}
