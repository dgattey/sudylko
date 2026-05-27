#if os(macOS)
import AppKit
import SwiftUI

/// Aligns the NSWindow with the in-app appearance picker and publishes `NSApp.isActive`.
struct WindowConfigurator: NSViewRepresentable {
    let appearanceMode: AppearanceMode
    var minimumWindowSize: CGSize = CGSize(width: 780, height: 640)
    @Binding var isAppActive: Bool
    @Binding var isWindowMiniaturized: Bool
    @Binding var isWindowFullscreen: Bool

    func makeNSView(context: Context) -> ThemedWindowAnchor {
        let view = ThemedWindowAnchor()
        view.onSystemAppearanceChange = {
            NotificationCenter.default.post(name: .sudylkoSystemThemeDidChange, object: nil)
        }
        view.onApplicationActiveChange = { active in
            isAppActive = active
        }
        view.onWindowMiniaturizedChange = { miniaturized in
            isWindowMiniaturized = miniaturized
        }
        view.onWindowFullscreenChange = { fullscreen in
            isWindowFullscreen = fullscreen
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
        nsView.onWindowMiniaturizedChange = { miniaturized in
            isWindowMiniaturized = miniaturized
        }
        nsView.onWindowFullscreenChange = { fullscreen in
            isWindowFullscreen = fullscreen
        }
        DispatchQueue.main.async {
            configure(nsView.window, mode: appearanceMode, minimumSize: minimumWindowSize)
            isAppActive = NSApp.isActive
            isWindowMiniaturized = nsView.window?.isMiniaturized ?? false
            isWindowFullscreen = nsView.window?.styleMask.contains(.fullScreen) == true
        }
    }

    private func configure(_ window: NSWindow?, mode: AppearanceMode, minimumSize: CGSize) {
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
        window.minSize = minimumSize
        if window.frame.width < minimumSize.width {
            var frame = window.frame
            frame.size.width = minimumSize.width
            window.setFrame(frame, display: true, animate: true)
        }
    }
}

/// Observes macOS light/dark changes and application active state.
final class ThemedWindowAnchor: NSView {
    var onSystemAppearanceChange: (() -> Void)?
    var onApplicationActiveChange: ((Bool) -> Void)?
    var onWindowMiniaturizedChange: ((Bool) -> Void)?
    var onWindowFullscreenChange: ((Bool) -> Void)?

    private var themeObserver: NSObjectProtocol?
    private var appActiveObservers: [NSObjectProtocol] = []
    private var windowMiniaturizeObservers: [NSObjectProtocol] = []
    private var windowFullscreenObservers: [NSObjectProtocol] = []
    private static var installedAppActiveObservers = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installThemeObserverIfNeeded()
        installApplicationActiveObserversIfNeeded()
        installWindowMiniaturizeObserversIfNeeded()
        installWindowFullscreenObserversIfNeeded()
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

    private func installWindowMiniaturizeObserversIfNeeded() {
        for observer in windowMiniaturizeObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowMiniaturizeObservers.removeAll()

        guard let window else {
            onWindowMiniaturizedChange?(false)
            return
        }

        let center = NotificationCenter.default
        windowMiniaturizeObservers.append(center.addObserver(
            forName: NSWindow.willMiniaturizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.onWindowMiniaturizedChange?(true)
        })
        windowMiniaturizeObservers.append(center.addObserver(
            forName: NSWindow.didDeminiaturizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.onWindowMiniaturizedChange?(false)
        })
        onWindowMiniaturizedChange?(window.isMiniaturized)
    }

    private func installWindowFullscreenObserversIfNeeded() {
        for observer in windowFullscreenObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowFullscreenObservers.removeAll()

        guard let window else {
            onWindowFullscreenChange?(false)
            return
        }

        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.willEnterFullScreenNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.willExitFullScreenNotification,
            NSWindow.didExitFullScreenNotification,
        ]
        for name in names {
            windowFullscreenObservers.append(center.addObserver(
                forName: name,
                object: window,
                queue: .main
            ) { [weak self] notification in
                self?.handleWindowFullscreenNotification(notification)
            })
        }
        onWindowFullscreenChange?(window.styleMask.contains(.fullScreen))
    }

    private func handleWindowFullscreenNotification(_ notification: Notification) {
        switch notification.name {
        case NSWindow.willEnterFullScreenNotification, NSWindow.didEnterFullScreenNotification:
            onWindowFullscreenChange?(true)
        case NSWindow.willExitFullScreenNotification, NSWindow.didExitFullScreenNotification:
            onWindowFullscreenChange?(false)
        default:
            onWindowFullscreenChange?(window?.styleMask.contains(.fullScreen) == true)
        }
    }

    deinit {
        if let themeObserver {
            DistributedNotificationCenter.default().removeObserver(themeObserver)
        }
        for observer in windowMiniaturizeObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        for observer in windowFullscreenObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
#endif
