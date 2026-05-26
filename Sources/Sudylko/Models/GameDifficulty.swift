import Foundation

enum GameDifficulty: String, CaseIterable, Identifiable, Codable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        }
    }

    /// Number of cells to remove from a complete grid (more = harder).
    var cellsToRemove: Int {
        switch self {
        case .easy: 36
        case .medium: 46
        case .hard: 54
        }
    }
}
