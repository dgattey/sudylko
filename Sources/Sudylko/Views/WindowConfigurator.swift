#if os(macOS)
import AppKit
import SwiftUI

/// Aligns the NSWindow with the in-app appearance picker and publishes `NSApp.isActive`.
/// Window mutations are deferred off `updateNSView` — setting `isMovableByWindowBackground` during
/// layout can crash SwiftUI's `NSHostingView` KVO (`LazyPreventsWindowDragFeature`).
struct WindowConfigurator: NSViewRepresentable {
    let appearanceMode: AppearanceMode
    var minimumWindowSize: CGSize = CGSize(width: 780, height: 640)
    @Binding var isAppActive: Bool
    @Binding var isWindowMiniaturized: Bool
    @Binding var isWindowFullscreen: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isAppActive: $isAppActive,
            isWindowMiniaturized: $isWindowMiniaturized,
            isWindowFullscreen: $isWindowFullscreen
        )
    }

    func makeNSView(context: Context) -> ThemedWindowAnchor {
        let view = ThemedWindowAnchor()
        context.coordinator.attach(anchor: view)
        return view
    }

    func updateNSView(_ nsView: ThemedWindowAnchor, context: Context) {
        context.coordinator.attach(anchor: nsView)
        context.coordinator.scheduleApply(
            appearanceMode: appearanceMode,
            minimumSize: minimumWindowSize
        )
    }

    final class Coordinator {
        @Binding private var isAppActive: Bool
        @Binding private var isWindowMiniaturized: Bool
        @Binding private var isWindowFullscreen: Bool

        private weak var anchor: ThemedWindowAnchor?
        private var pendingApply: DispatchWorkItem?
        private var lastAppearanceMode: AppearanceMode?
        private var lastMinimumSize: CGSize?

        init(
            isAppActive: Binding<Bool>,
            isWindowMiniaturized: Binding<Bool>,
            isWindowFullscreen: Binding<Bool>
        ) {
            _isAppActive = isAppActive
            _isWindowMiniaturized = isWindowMiniaturized
            _isWindowFullscreen = isWindowFullscreen
        }

        func attach(anchor: ThemedWindowAnchor) {
            self.anchor = anchor
            anchor.onSystemAppearanceChange = { [weak self] in
                NotificationCenter.default.post(name: .sudylkoSystemThemeDidChange, object: nil)
            }
            anchor.onApplicationActiveChange = { [weak self] active in
                self?.publishAppActive(active)
            }
            anchor.onWindowMiniaturizedChange = { [weak self] miniaturized in
                self?.publishMiniaturized(miniaturized)
            }
            anchor.onWindowFullscreenChange = { [weak self] fullscreen in
                self?.publishFullscreen(fullscreen)
            }
        }

        func scheduleApply(appearanceMode: AppearanceMode, minimumSize: CGSize) {
            pendingApply?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.apply(appearanceMode: appearanceMode, minimumSize: minimumSize)
            }
            pendingApply = work
            DispatchQueue.main.async(execute: work)
        }

        private func apply(appearanceMode: AppearanceMode, minimumSize: CGSize) {
            guard let window = anchor?.window else { return }

            anchor?.configureWindowChromeIfNeeded(window)

            let appearance = appearanceMode.resolvedNSAppearance() ?? NSApp.effectiveAppearance
            if lastAppearanceMode != appearanceMode || window.appearance != appearance {
                window.appearance = appearance
                lastAppearanceMode = appearanceMode
            }

            if lastMinimumSize != minimumSize {
                window.minSize = minimumSize
                lastMinimumSize = minimumSize
                if window.frame.width < minimumSize.width {
                    var frame = window.frame
                    frame.size.width = minimumSize.width
                    window.setFrame(frame, display: true, animate: false)
                }
            }

            publishAppActive(NSApp.isActive)
            publishMiniaturized(window.isMiniaturized)
            publishFullscreen(window.styleMask.contains(.fullScreen))
        }

        private func publishAppActive(_ active: Bool) {
            guard isAppActive != active else { return }
            isAppActive = active
        }

        private func publishMiniaturized(_ miniaturized: Bool) {
            guard isWindowMiniaturized != miniaturized else { return }
            isWindowMiniaturized = miniaturized
        }

        private func publishFullscreen(_ fullscreen: Bool) {
            guard isWindowFullscreen != fullscreen else { return }
            isWindowFullscreen = fullscreen
        }
    }
}

/// Observes macOS light/dark changes and application active state.
final class ThemedWindowAnchor: NSView {
    var onSystemAppearanceChange: (() -> Void)?
    var onApplicationActiveChange: ((Bool) -> Void)?
    var onWindowMiniaturizedChange: ((Bool) -> Void)?
    var onWindowFullscreenChange: ((Bool) -> Void)?

    private static var chromeConfiguredWindowIDs = Set<ObjectIdentifier>()

    private var themeObserver: NSObjectProtocol?
    private var appActiveObservers: [NSObjectProtocol] = []
    private var windowMiniaturizeObservers: [NSObjectProtocol] = []
    private var windowFullscreenObservers: [NSObjectProtocol] = []
    private static var installedAppActiveObservers = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            configureWindowChromeIfNeeded(window)
        }
        installThemeObserverIfNeeded()
        installApplicationActiveObserversIfNeeded()
        installWindowMiniaturizeObserversIfNeeded()
        installWindowFullscreenObserversIfNeeded()
    }

    func configureWindowChromeIfNeeded(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        guard !Self.chromeConfiguredWindowIDs.contains(id) else { return }
        Self.chromeConfiguredWindowIDs.insert(id)

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.titlebarSeparatorStyle = .none
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
