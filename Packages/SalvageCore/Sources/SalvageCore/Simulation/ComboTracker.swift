public struct ComboTracker: Sendable, Equatable {
    public private(set) var count = 0
    public private(set) var best = 0
    private let tiers: [GameConfig.ComboTier]

    public init(tiers: [GameConfig.ComboTier]) {
        self.tiers = tiers
    }

    public var multiplier: Int {
        tiers.last { count >= $0.threshold }?.multiplier ?? 1
    }

    /// Counts a correct sort. The sort that reaches a threshold already earns the new multiplier.
    public mutating func registerSuccess() -> (multiplier: Int, tierUp: Bool) {
        let before = multiplier
        count += 1
        best = max(best, count)
        return (multiplier, multiplier > before)
    }

    /// Resets the combo and returns the count that was lost.
    @discardableResult
    public mutating func reset() -> Int {
        defer { count = 0 }
        return count
    }
}
