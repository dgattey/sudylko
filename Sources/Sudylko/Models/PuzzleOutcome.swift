import Foundation

/// Single source of truth for whether the player can still edit the board.
enum PuzzleOutcome: String, Codable, Equatable, Sendable {
    case playing
    case won
    case lost

    var isEnded: Bool { self != .playing }

    init(legacyComplete: Bool, legacyLost: Bool) {
        if legacyLost {
            self = .lost
        } else if legacyComplete {
            self = .won
        } else {
            self = .playing
        }
    }
}
