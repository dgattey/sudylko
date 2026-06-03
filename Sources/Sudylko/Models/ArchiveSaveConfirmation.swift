import Foundation

enum ArchiveSaveConfirmation {
    static func title(gameTitle: String) -> String {
        "Archive \(gameTitle)?"
    }

    static let inProgressMessage =
        "This game is still in progress. Archiving removes it from your active list; you can open it again later from Archived games."
}

extension PuzzleOutcome {
    /// Only in-progress saves ask before archiving.
    var requiresArchiveConfirmation: Bool { self == .playing }
}
