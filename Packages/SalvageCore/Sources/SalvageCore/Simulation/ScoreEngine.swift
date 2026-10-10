public enum ScoreEngine {
    public static func points(for kind: ItemKind, multiplier: Int, config: GameConfig) -> Int {
        config.points(for: kind) * multiplier
    }
}
