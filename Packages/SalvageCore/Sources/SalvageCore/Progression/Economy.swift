public struct Cosmetic: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        case theme
        case drone
    }

    public let id: String
    public let name: String
    public let kind: Kind
    public let price: Int

    public var isFree: Bool { price == 0 }
}

public enum Upgrade: String, CaseIterable, Sendable, Codable {
    case bufferExpansion
    case fuseDampener
    case comboShield
}

public struct UpgradeLevels: Sendable, Equatable, Codable {
    public var bufferExpansion = 0
    public var fuseDampener = 0
    public var comboShield = 0

    public init(bufferExpansion: Int = 0, fuseDampener: Int = 0, comboShield: Int = 0) {
        self.bufferExpansion = bufferExpansion
        self.fuseDampener = fuseDampener
        self.comboShield = comboShield
    }

    public subscript(upgrade: Upgrade) -> Int {
        get {
            switch upgrade {
            case .bufferExpansion: bufferExpansion
            case .fuseDampener: fuseDampener
            case .comboShield: comboShield
            }
        }
        set {
            switch upgrade {
            case .bufferExpansion: bufferExpansion = newValue
            case .fuseDampener: fuseDampener = newValue
            case .comboShield: comboShield = newValue
            }
        }
    }
}

public enum Economy {
    public static func credits(for summary: RunSummary, mode: RunMode, firstRunToday: Bool, config: EconomyConfig = .standard) -> Int {
        guard mode != .tutorial else { return 0 }
        let earned = Int((Double(summary.score) / Double(config.scorePerCredit)).rounded())
        return earned + (firstRunToday ? config.firstRunOfDayBonus : 0)
    }

    public static func maxLevel(of upgrade: Upgrade, config: EconomyConfig = .standard) -> Int {
        config.upgradeCosts[upgrade]?.count ?? 0
    }

    /// Price of the next level, or nil when already maxed.
    public static func nextLevelCost(of upgrade: Upgrade, currentLevel: Int, config: EconomyConfig = .standard) -> Int? {
        guard let costs = config.upgradeCosts[upgrade], costs.indices.contains(currentLevel) else { return nil }
        return costs[currentLevel]
    }

    /// Upgrades only apply in Endless so daily and challenge scores stay comparable.
    public static func modifiers(for levels: UpgradeLevels, mode: RunMode, config: EconomyConfig = .standard) -> RunModifiers {
        guard mode.allowsUpgrades else { return .none }
        return RunModifiers(
            bufferBonus: config.bufferBonusByLevel[clamped: levels.bufferExpansion],
            fuseMultiplier: config.fuseMultiplierByLevel[clamped: levels.fuseDampener],
            comboShields: config.comboShieldsByLevel[clamped: levels.comboShield]
        )
    }
}

extension Array {
    fileprivate subscript(clamped index: Int) -> Element {
        self[Swift.min(Swift.max(index, 0), count - 1)]
    }
}
