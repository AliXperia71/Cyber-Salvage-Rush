import SpriteKit

/// Tracks one dragged item per finger, so skilled players can sort with two thumbs.
@MainActor
final class DragController {
    /// Lifts the item above the finger so it isn't hidden by the thumb.
    static let liftOffset = CGPoint(x: 0, y: 34)
    /// Generous pick-up radius beyond the item's own bounds.
    static let pickRadius: CGFloat = 44

    private var sessions: [ObjectIdentifier: ItemNode] = [:]

    var draggedNodes: some Collection<ItemNode> { sessions.values }

    func begin(touch: UITouch, at point: CGPoint, candidates: some Sequence<ItemNode>) -> ItemNode? {
        let available = candidates.filter { !$0.isDragged && !$0.awaitingDrop }
        guard let nearest = available.min(by: { $0.position.distance(to: point) < $1.position.distance(to: point) }),
              nearest.position.distance(to: point) <= Self.pickRadius + nearest.size.width * 0.25
        else { return nil }
        sessions[ObjectIdentifier(touch)] = nearest
        nearest.lift()
        move(touch: touch, to: point)
        return nearest
    }

    func move(touch: UITouch, to point: CGPoint) {
        guard let node = sessions[ObjectIdentifier(touch)] else { return }
        node.position = CGPoint(x: point.x + Self.liftOffset.x, y: point.y + Self.liftOffset.y)
    }

    func end(touch: UITouch) -> ItemNode? {
        sessions.removeValue(forKey: ObjectIdentifier(touch))
    }

    /// The item left the board while held (e.g. its fuse expired).
    func forget(itemID: Int) {
        sessions = sessions.filter { $0.value.itemID != itemID }
    }

    func cancelAll() -> [ItemNode] {
        defer { sessions.removeAll() }
        return Array(sessions.values)
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
