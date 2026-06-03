import Foundation

enum SavesChangeReason {
    case deleteAll
}

extension Notification.Name {
    static let openSettings = Notification.Name("SudylkoOpenSettings")
    static let sudylkoSystemThemeDidChange = Notification.Name("SudylkoSystemThemeDidChange")
    static let toggleSidebar = Notification.Name("SudylkoToggleSidebar")
    static let showKeyboardShortcuts = Notification.Name("SudylkoShowKeyboardShortcuts")
    static let undo = Notification.Name("SudylkoUndo")
    static let redo = Notification.Name("SudylkoRedo")
    static let deleteCell = Notification.Name("SudylkoDeleteCell")
    static let achievementsDidChange = Notification.Name("SudylkoAchievementsDidChange")
    static let savesDidChange = Notification.Name("SudylkoSavesDidChange")
    #if DEBUG
    static let debugAchievementUnlocked = Notification.Name("SudylkoDebugAchievementUnlocked")
    static let debugTriggerPulse = Notification.Name("SudylkoDebugTriggerPulse")
    static let requestDeleteAllSavesConfirmation = Notification.Name("SudylkoRequestDeleteAllSavesConfirmation")
    #endif
}

#if DEBUG
enum DebugPulseKind {
    case puzzleComplete
    case finishedRow
    case finishedColumn
    case finishedBox
    case finishedDigit
}
#endif
