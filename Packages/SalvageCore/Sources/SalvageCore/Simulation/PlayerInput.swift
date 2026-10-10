public enum PlayerInput: Sendable, Equatable {
    /// Finger picked the item up; it stops moving on the belt.
    case grab(itemID: Int)
    /// Item dropped somewhere that isn't a bin; it resumes where it was.
    case release(itemID: Int)
    /// Item dropped into a bin. Does not require a prior grab.
    case drop(itemID: Int, bin: BinID)
}
