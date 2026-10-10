/// Everything the presentation layer (scene, HUD, audio, haptics, Game Center) reacts to.
public enum GameEvent: Sendable, Equatable {
    case spawned(Item)
    case enteredBuffer(itemID: Int, slot: Int)
    case sorted(itemID: Int, bin: BinID, points: Int, combo: Int, multiplier: Int)
    case comboTierUp(multiplier: Int)
    /// Wrong bin. The item is destroyed (outside the tutorial).
    case missorted(itemID: Int, bin: BinID)
    /// Tutorial only: wrong bin, the item bounces back.
    case rejected(itemID: Int, bin: BinID)
    /// A combo shield absorbed a missort.
    case shieldUsed(itemID: Int, bin: BinID)
    /// Reached the belt end with the buffer full.
    case lost(itemID: Int)
    case hazardExpired(itemID: Int)
    case comboBroken(previous: Int)
    case revived
    case runEnded(RunSummary)
}
