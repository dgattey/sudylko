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

    /// Plain puzzle number for the pasteboard (no `#` prefix).
    var clipboardText: String {
        "\(number)"
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

    /// Parses `#1384`, `1384`, or pasted text like `Game #89799`; difficulty comes from the picker.
    static func parse(_ input: String, difficulty: GameDifficulty) -> PuzzleSeed? {
        guard let number = normalizedNumber(from: input) else { return nil }
        return PuzzleSeed(number: number, difficulty: difficulty)
    }

    /// Leading digits from user or pasteboard input (strips `#`, whitespace, and `Game` prefixes).
    static func normalizedNumber(from input: String) -> Int? {
        guard let digits = normalizedDigitString(from: input),
              let number = Int(digits),
              (1...99_999).contains(number) else { return nil }
        return number
    }

    static func normalizedDigitString(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let hashIndex = trimmed.firstIndex(of: "#") {
            let afterHash = trimmed[trimmed.index(after: hashIndex)...]
            let digits = afterHash.prefix(while: \.isNumber)
            if !digits.isEmpty { return String(digits) }
        }

        var work = trimmed
        if work.lowercased().hasPrefix("game") {
            work = String(work.dropFirst(4))
            work = work.trimmingCharacters(in: .whitespacesAndNewlines)
            if work.hasPrefix("#") {
                work.removeFirst()
            }
            work = work.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let digits = work.prefix(while: \.isNumber)
        guard !digits.isEmpty else { return nil }
        return String(digits)
    }

    /// Display string for the custom-puzzle field from any partial input.
    static func displayText(forInput input: String) -> String {
        guard let digits = normalizedDigitString(from: input) else { return sanitizedInput(input) }
        return "#\(digits)"
    }

    /// Restricts typing/paste to an optional leading `#` and up to five digits.
    static func sanitizedInput(_ input: String) -> String {
        var digits = 0
        var result = ""
        for character in input {
            if character == "#", result.isEmpty {
                result.append(character)
            } else if character.isNumber {
                result.append(character)
                digits += 1
                if digits == 5 { break }
            }
        }
        return result
    }

    /// Normalizes bound field text after typing or paste (keeps a leading `#` when present).
    static func normalizedFieldInput(_ input: String) -> String {
        sanitizedInput(input)
    }

    /// Uses the pasteboard when it contains a valid puzzle number.
    static func prefillFromClipboard(defaultDifficulty: GameDifficulty) -> (text: String, difficulty: GameDifficulty)? {
        guard let raw = Clipboard.readString()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let number = normalizedNumber(from: raw) else { return nil }
        return ("#\(number)", defaultDifficulty)
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
