public struct RunState: Sendable, Equatable {
    public internal(set) var tick = 0
    /// In spawn order.
    public internal(set) var items: [Item] = []
    public internal(set) var score = 0
    public internal(set) var combo: ComboTracker
    /// 0...config.maxOverload. The run ends at the max.
    public internal(set) var overload: Double = 0
    public internal(set) var isOver = false
    public internal(set) var bufferCapacity: Int
    public internal(set) var shieldsRemaining: Int
    public internal(set) var revivesUsed = 0
    public internal(set) var missorts = 0
    public internal(set) var sorted: [ItemKind: Int] = [:]

    public var bufferOccupancy: Int {
        items.count { $0.bufferSlot != nil }
    }

    public func item(id: Int) -> Item? {
        items.first { $0.id == id }
    }
}
