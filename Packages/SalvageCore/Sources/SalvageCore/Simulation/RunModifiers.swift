/// Effects of permanent upgrades. Only applied in Endless; see `Economy.modifiers(for:mode:)`.
public struct RunModifiers: Sendable, Equatable {
    public var bufferBonus: Int
    public var fuseMultiplier: Double
    public var comboShields: Int

    public init(bufferBonus: Int = 0, fuseMultiplier: Double = 1, comboShields: Int = 0) {
        self.bufferBonus = bufferBonus
        self.fuseMultiplier = fuseMultiplier
        self.comboShields = comboShields
    }

    public static let none = RunModifiers()
}
