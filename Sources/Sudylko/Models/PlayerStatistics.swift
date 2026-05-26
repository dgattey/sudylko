import Foundation

struct DifficultyPlayerStats: Codable, Equatable {
    var started: Int = 0
    var won: Int = 0
    var lost: Int = 0
    var totalWinSeconds: Double = 0
    var bestWinSeconds: Double?
    var mistakes: Int = 0

    /// Wins capped to started for display (handles legacy corrupt counters).
    var displayWon: Int { min(won, started) }

    var averageWinSeconds: Double? {
        guard won > 0 else { return nil }
        return totalWinSeconds / Double(won)
    }

    /// Win share in `[0, 100]` for charts and labels.
    var winRatePercent: Double {
        guard started > 0 else { return 0 }
        return min(100, Double(displayWon) / Double(started) * 100)
    }
}

/// Lifetime counters for achievements and the stats panel (persisted; not tied to save files).
struct PlayerLifetimeStats: Codable, Equatable {
    var easy = DifficultyPlayerStats()
    var medium = DifficultyPlayerStats()
    var hard = DifficultyPlayerStats()
    var customSeedStarted: Int = 0
    var customSeedWon: Int = 0

    var completionCount: Int = 0
    var gamesStartedCount: Int = 0
    var lifetimeMistakes: Int = 0
    var abandonedSaves: Int = 0
    var completedEasy: Bool = false
    var completedMedium: Bool = false
    var completedHard: Bool = false

    var totalStarted: Int { easy.started + medium.started + hard.started }
    var totalWon: Int { easy.won + medium.won + hard.won }
    var totalLost: Int { easy.lost + medium.lost + hard.lost }
    var totalWinSeconds: Double { easy.totalWinSeconds + medium.totalWinSeconds + hard.totalWinSeconds }

    var bestWinSeconds: Double? {
        [easy.bestWinSeconds, medium.bestWinSeconds, hard.bestWinSeconds]
            .compactMap { $0 }
            .min()
    }

    var averageWinSeconds: Double? {
        guard totalWon > 0 else { return nil }
        return totalWinSeconds / Double(totalWon)
    }

    subscript(difficulty: GameDifficulty) -> DifficultyPlayerStats {
        get { bucket(for: difficulty) }
        set { setBucket(newValue, for: difficulty) }
    }

    private func bucket(for difficulty: GameDifficulty) -> DifficultyPlayerStats {
        switch difficulty {
        case .easy: easy
        case .medium: medium
        case .hard: hard
        }
    }

    private mutating func setBucket(_ value: DifficultyPlayerStats, for difficulty: GameDifficulty) {
        switch difficulty {
        case .easy: easy = value
        case .medium: medium = value
        case .hard: hard = value
        }
    }

    mutating func recordStarted(difficulty: GameDifficulty, fromCustomSeed: Bool) {
        gamesStartedCount += 1
        var bucket = self[difficulty]
        bucket.started += 1
        self[difficulty] = bucket
        if fromCustomSeed { customSeedStarted += 1 }
    }

    mutating func recordWin(
        difficulty: GameDifficulty,
        elapsedSeconds: Double,
        mistakesInPuzzle: Int,
        fromCustomSeed: Bool
    ) {
        var bucket = self[difficulty]
        guard bucket.started > bucket.won else { return }

        completionCount += 1
        switch difficulty {
        case .easy: completedEasy = true
        case .medium: completedMedium = true
        case .hard: completedHard = true
        }

        bucket.won += 1
        bucket.totalWinSeconds += elapsedSeconds
        if let best = bucket.bestWinSeconds {
            bucket.bestWinSeconds = min(best, elapsedSeconds)
        } else {
            bucket.bestWinSeconds = elapsedSeconds
        }
        bucket.mistakes += mistakesInPuzzle
        self[difficulty] = bucket

        if fromCustomSeed, customSeedWon < customSeedStarted {
            customSeedWon += 1
        }
    }

    /// Clamps corrupt per-difficulty counters so won and lost never exceed started.
    mutating func repairInvariants() {
        var easyBucket = easy
        var mediumBucket = medium
        var hardBucket = hard
        repairBucket(&easyBucket)
        repairBucket(&mediumBucket)
        repairBucket(&hardBucket)
        easy = easyBucket
        medium = mediumBucket
        hard = hardBucket
        customSeedWon = min(customSeedWon, customSeedStarted)
        completionCount = totalWon
        if gamesStartedCount < totalStarted {
            gamesStartedCount = totalStarted
        }
    }

    private mutating func repairBucket(_ bucket: inout DifficultyPlayerStats) {
        if bucket.won > bucket.started {
            bucket.won = bucket.started
        }
        if bucket.lost > bucket.started {
            bucket.lost = bucket.started
        }
        let accounted = bucket.won + bucket.lost
        if accounted > bucket.started {
            bucket.lost = max(0, bucket.started - bucket.won)
        }
    }

    mutating func recordMistake(difficulty: GameDifficulty) {
        lifetimeMistakes += 1
        var bucket = self[difficulty]
        bucket.mistakes += 1
        self[difficulty] = bucket
    }

    mutating func recordLoss(difficulty: GameDifficulty) {
        abandonedSaves += 1
        var bucket = self[difficulty]
        bucket.lost += 1
        self[difficulty] = bucket
    }

    mutating func recordGameplayLoss(difficulty: GameDifficulty) {
        var bucket = self[difficulty]
        bucket.lost += 1
        self[difficulty] = bucket
    }

}

enum PlayerStatsStore {
    private static let statsKey = "achievementLifetimeStats"

    static func load() -> PlayerLifetimeStats {
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              var stats = try? JSONDecoder().decode(PlayerLifetimeStats.self, from: data) else {
            return PlayerLifetimeStats()
        }
        let repaired = stats
        stats.repairInvariants()
        if stats != repaired {
            save(stats)
        }
        return stats
    }

    static func save(_ stats: PlayerLifetimeStats) {
        var stats = stats
        stats.repairInvariants()
        guard let data = try? JSONEncoder().encode(stats) else { return }
        UserDefaults.standard.set(data, forKey: statsKey)
        NotificationCenter.default.post(name: .achievementsDidChange, object: nil)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: statsKey)
        NotificationCenter.default.post(name: .achievementsDidChange, object: nil)
    }
}
