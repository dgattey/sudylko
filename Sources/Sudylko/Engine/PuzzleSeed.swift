import Foundation

/// Puzzle identity: a 1–5 digit number plus difficulty (chosen separately in the UI).
struct PuzzleSeed: Codable, Equatable, Hashable, Sendable {
    let number: Int
    let difficulty: GameDifficulty

    init(number: Int, difficulty: GameDifficulty) {
        self.number = min(99_999, max(1, number))
        self.difficulty = difficulty
    }

    /// Display number, e.g. `#1384`.
    var gameNumberLabel: String {
        "#\(number)"
    }

    /// e.g. `Sudylko #1384`
    var windowTitle: String {
        "Sudylko \(gameNumberLabel)"
    }

    static func random(difficulty: GameDifficulty) -> PuzzleSeed {
        PuzzleSeed(number: Int.random(in: 1...99_999), difficulty: difficulty)
    }

    /// Deterministic 64-bit value for the puzzle generator.
    var seedValue: UInt64 {
        Self.hash(number: number, difficulty: difficulty)
    }

    /// Parses `#1384` or `1384`; difficulty comes from the picker, not the string.
    static func parse(_ input: String, difficulty: GameDifficulty) -> PuzzleSeed? {
        var trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            trimmed.removeFirst()
        }
        guard let number = Int(trimmed), (1...99_999).contains(number) else { return nil }
        return PuzzleSeed(number: number, difficulty: difficulty)
    }

    private static func hash(number: Int, difficulty: GameDifficulty) -> UInt64 {
        let key = "\(number)-\(difficulty.rawValue)"
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash == 0 ? 0xDEAD_BEEF_CAFE_BABE : hash
    }
}
