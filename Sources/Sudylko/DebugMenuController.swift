#if DEBUG && os(macOS)
import AppKit
import Foundation

/// Native AppKit Debug menu (replaces SwiftUI `CommandMenu`, which renders non-standard chrome on macOS).
@objc final class DebugMenuController: NSObject {
    static let shared = DebugMenuController()

    private static let menuTitle = "Debug"
    private static let unlockAchievementTitle = "Unlock achievement"
    private static let pulseAnimationTitle = "Pulse animation"
    private static let deleteAllSavesTitle = "Delete All Saves…"

    static func install() {
        guard let mainMenu = NSApp.mainMenu else { return }
        removeDuplicateDebugMenus(from: mainMenu)

        let debugItem: NSMenuItem
        if let existing = mainMenu.items.first(where: { $0.title == menuTitle }) {
            debugItem = existing
        } else {
            debugItem = NSMenuItem(title: menuTitle, action: nil, keyEquivalent: "")
            debugItem.submenu = NSMenu(title: menuTitle)
            if let helpIndex = mainMenu.items.firstIndex(where: { $0.title == "Help" }) {
                mainMenu.insertItem(debugItem, at: helpIndex)
            } else {
                mainMenu.addItem(debugItem)
            }
        }

        guard let submenu = debugItem.submenu else { return }
        submenu.removeAllItems()
        populate(submenu)
    }

    private static func removeDuplicateDebugMenus(from mainMenu: NSMenu) {
        let matches = mainMenu.items.filter { $0.title == menuTitle }
        guard matches.count > 1 else { return }
        for duplicate in matches.dropFirst() {
            mainMenu.removeItem(duplicate)
        }
    }

    private static func populate(_ menu: NSMenu) {
        menu.addItem(submenuItem(title: unlockAchievementTitle, items: unlockAchievementItems()))
        menu.addItem(submenuItem(title: pulseAnimationTitle, items: pulseAnimationItems()))
        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Reset achievements", action: #selector(resetAchievements(_:))))
        menu.addItem(actionItem(title: "Reset stats", action: #selector(resetStats(_:))))
        menu.addItem(actionItem(title: "Reset all progress", action: #selector(resetAllProgress(_:))))
        menu.addItem(actionItem(title: "Seed done game", action: #selector(seedDoneGame(_:))))
        menu.addItem(
            actionItem(title: deleteAllSavesTitle, action: #selector(requestDeleteAllSaves(_:)))
        )
    }

    private static func submenuItem(title: String, items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        for item in items {
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    private static func actionItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = shared
        return item
    }

    private static func unlockAchievementItems() -> [NSMenuItem] {
        AchievementID.displayOrder.map { achievement in
            let item = NSMenuItem(
                title: achievement.title,
                action: #selector(unlockAchievement(_:)),
                keyEquivalent: ""
            )
            item.target = shared
            item.representedObject = achievement.rawValue
            return item
        }
    }

    private enum PulseMenuTag: Int {
        case puzzleComplete = 1
        case finishedRow
        case finishedColumn
        case finishedBox
        case finishedDigit
    }

    private static func pulseAnimationItems() -> [NSMenuItem] {
        [
            ("Puzzle complete", PulseMenuTag.puzzleComplete),
            ("Finished row", .finishedRow),
            ("Finished column", .finishedColumn),
            ("Finished 3×3 box", .finishedBox),
            ("Finished digit (all 5s)", .finishedDigit),
        ].map { title, tag in
            let item = NSMenuItem(
                title: title,
                action: #selector(triggerPulse(_:)),
                keyEquivalent: ""
            )
            item.target = shared
            item.tag = tag.rawValue
            return item
        }
    }

    @objc private func unlockAchievement(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let achievement = AchievementID(rawValue: raw),
              AchievementStore.debugUnlock(achievement) else { return }
        NotificationCenter.default.post(
            name: .debugAchievementUnlocked,
            object: achievement
        )
    }

    @objc private func triggerPulse(_ sender: NSMenuItem) {
        guard let tag = PulseMenuTag(rawValue: sender.tag) else { return }
        let kind: DebugPulseKind
        switch tag {
        case .puzzleComplete: kind = .puzzleComplete
        case .finishedRow: kind = .finishedRow
        case .finishedColumn: kind = .finishedColumn
        case .finishedBox: kind = .finishedBox
        case .finishedDigit: kind = .finishedDigit
        }
        NotificationCenter.default.post(name: .debugTriggerPulse, object: kind)
    }

    @objc private func resetAchievements(_ sender: Any?) {
        AchievementStore.resetUnlocks()
    }

    @objc private func resetStats(_ sender: Any?) {
        AchievementStore.resetStats()
    }

    @objc private func resetAllProgress(_ sender: Any?) {
        AchievementStore.resetAllProgress()
    }

    @objc private func seedDoneGame(_ sender: Any?) {
        Task { @MainActor in
            _ = SaveLoadWork.debugSeedCompletedGame()
        }
    }

    @objc private func requestDeleteAllSaves(_ sender: Any?) {
        NotificationCenter.default.post(name: .requestDeleteAllSavesConfirmation, object: nil)
    }
}
#endif
