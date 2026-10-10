public struct RunSummary: Sendable, Equatable, Codable {
    public var seed: UInt64
    public var configVersion: Int
    public var score: Int
    public var durationSeconds: Double
    public var bestCombo: Int
    public var standardSorted: Int
    public var valuableSorted: Int
    public var hazardousSorted: Int
    public var missorts: Int
    public var revivesUsed: Int

    public var totalSorted: Int { standardSorted + valuableSorted + hazardousSorted }
}
