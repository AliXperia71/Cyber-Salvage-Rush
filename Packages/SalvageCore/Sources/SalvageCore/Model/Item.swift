public struct Item: Sendable, Equatable, Identifiable {
    public enum Location: Sendable, Equatable {
        /// 0 = belt entry, 1 = belt end.
        case belt(progress: Double)
        case buffer(slot: Int)
    }

    public let id: Int
    public let kind: ItemKind
    public let lane: Int
    public internal(set) var location: Location
    /// Held items stop moving on the belt; hazard fuses keep burning.
    public internal(set) var isHeld = false
    /// Remaining fuse in ticks. Only hazardous items have one.
    public internal(set) var fuseTicks: Int?

    public var bufferSlot: Int? {
        if case .buffer(let slot) = location { slot } else { nil }
    }
}
