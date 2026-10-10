/// Difficulty as a pure function of elapsed run time.
public struct DifficultyCurve: Sendable {
    public let config: GameConfig

    public init(config: GameConfig) {
        self.config = config
    }

    /// 0 at run start, 1 once `rampSeconds` have passed.
    public func ramp(at seconds: Double) -> Double {
        min(max(seconds / config.rampSeconds, 0), 1)
    }

    public func travelSeconds(at seconds: Double) -> Double {
        lerp(config.travelSecondsStart, config.travelSecondsEnd, ramp(at: seconds))
    }

    public func spawnInterval(at seconds: Double) -> Double {
        let base = lerp(config.spawnIntervalStart, config.spawnIntervalEnd, ramp(at: seconds))
        let overtime = max(seconds - config.rampSeconds, 0)
        let tighten = max(config.overtimeFloor, 1 - overtime * config.overtimeTightenPerSecond)
        return base * tighten
    }

    public func hazardChance(at seconds: Double) -> Double {
        lerp(config.hazardChanceStart, config.hazardChanceEnd, ramp(at: seconds))
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}
