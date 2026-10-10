public enum RunMode: Sendable, Equatable {
    case endless
    case daily
    case challenge(ChallengeCode)
    case tutorial

    /// Daily and challenge runs use fixed rules so scores are comparable.
    public var allowsUpgrades: Bool { self == .endless }
    public var allowsRevive: Bool { self == .endless }
    public var usesOverload: Bool { self != .tutorial }
}
