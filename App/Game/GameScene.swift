import SalvageCore
import SpriteKit

/// Thin presentation layer: builds the board, forwards touches as `PlayerInput`s,
/// mirrors simulation state onto nodes, and turns `GameEvent`s into feedback.
@MainActor
final class GameScene: SKScene {
    let controller: GameController
    private let textures: ProceduralTextureFactory
    private let haptics: HapticsService

    private let world = SKNode()
    private let boardLayer = SKNode()
    private let itemLayer = SKNode()
    private let fxLayer = SKNode()
    private let dangerOverlay = SKSpriteNode()
    private lazy var effects = EffectsDirector(textures: textures, layer: fxLayer, shakeTarget: world)
    private let drag = DragController()

    private var layout: BoardLayout
    private var conveyors: [ConveyorNode] = []
    private var bins: [BinID: BinNode] = [:]
    private var tray: BufferTrayNode
    private var itemNodes: [Int: ItemNode] = [:]
    private var lastUpdate: TimeInterval?
    private var tutorialGuide: TutorialGuide?
    private let droneID: String?
    private var drone: DroneNode?

    var hapticsEnabled: Bool {
        get { haptics.isEnabled }
        set { haptics.isEnabled = newValue }
    }

    var insets: UIEdgeInsets = .zero {
        didSet { if insets != oldValue { relayout() } }
    }

    /// `droneID` nil means no companion (the tutorial keeps the board uncluttered).
    init(controller: GameController, theme: Theme, droneID: String?, haptics: HapticsService) {
        self.controller = controller
        self.haptics = haptics
        self.droneID = droneID
        textures = ProceduralTextureFactory(theme: theme)
        tray = BufferTrayNode(textures: textures)
        layout = BoardLayout(size: .zero, insets: .zero, laneCount: controller.config.laneCount,
                             bufferCapacity: controller.simulation.state.bufferCapacity)
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = theme.background
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        guard world.parent == nil else { return }
        addChild(world)
        [boardLayer, itemLayer, fxLayer].forEach(world.addChild)
        itemLayer.zPosition = 10
        fxLayer.zPosition = 20
        boardLayer.addChild(tray)
        dangerOverlay.color = textures.theme.danger
        dangerOverlay.anchorPoint = .zero
        dangerOverlay.zPosition = 100
        dangerOverlay.alpha = 0
        dangerOverlay.blendMode = .add
        addChild(dangerOverlay)
        haptics.prepare()
        relayout()
        if controller.mode == .tutorial {
            let size = layout.itemSize * 1.1
            tutorialGuide = TutorialGuide(texture: textures.hand(size: size), size: size, layer: fxLayer)
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        relayout()
    }

    // MARK: - Layout

    private func relayout() {
        guard world.parent != nil, size.width > 0 else { return }
        layout = BoardLayout(size: size, insets: insets, laneCount: controller.config.laneCount,
                             bufferCapacity: controller.simulation.state.bufferCapacity)
        dangerOverlay.size = size

        conveyors.forEach { $0.removeFromParent() }
        conveyors = (0..<layout.laneCount).map { lane in
            let conveyor = ConveyorNode(textures: textures, height: layout.itemSize * 0.9)
            conveyor.position = CGPoint(x: 0, y: layout.laneY(lane))
            conveyor.layout(width: layout.beltEndX + layout.itemSize * 0.5)
            boardLayer.addChild(conveyor)
            return conveyor
        }

        bins.values.forEach { $0.removeFromParent() }
        bins = Dictionary(uniqueKeysWithValues: BinID.allCases.map { bin in
            let rect = layout.binRect(bin)
            let node = BinNode(bin: bin, texture: textures.bin(bin, size: rect.size), size: rect.size)
            node.position = CGPoint(x: rect.midX, y: rect.midY)
            boardLayer.addChild(node)
            return (bin, node)
        })

        tray.layout(layout)
        layoutDrone()
    }

    private func layoutDrone() {
        guard let droneID else { return }
        let size = layout.itemSize * 0.8
        if drone?.size.width != size {
            drone?.removeFromParent()
            let node = DroneNode(texture: textures.drone(droneID, size: size), size: size)
            boardLayer.addChild(node)
            drone = node
        }
        guard let drone else { return }
        drone.removeAction(forKey: "hover")
        drone.position = CGPoint(x: self.size.width - BoardLayout.sideMargin - size * 0.6,
                                 y: layout.trayRect.maxY + size * 0.75)
        drone.startHovering()
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        let frameTime = lastUpdate.map { currentTime - $0 } ?? 0
        lastUpdate = currentTime
        let events = controller.advance(by: frameTime)
        handle(events)
        syncItems(frameTime: frameTime, time: currentTime)

        if controller.phase == .playing {
            let speed = layout.beltLength / controller.beltTravelSeconds
            conveyors.forEach { $0.scroll(by: speed * frameTime) }
        }
        let overload = controller.simulation.state.overload / controller.config.maxOverload
        dangerOverlay.alpha = CGFloat(max(0, overload - 0.5) * 0.35)
        tray.setFull(controller.hud.bufferFull)
        updateBinHighlights()
        updateTutorialGuide(frameTime: frameTime)
    }

    private func updateTutorialGuide(frameTime: TimeInterval) {
        guard let tutorialGuide else { return }
        let state = controller.simulation.state
        // Demo the oldest item once it has stopped at its waiting spot.
        let target = state.items.first.flatMap { item -> (id: Int, from: CGPoint, to: CGPoint)? in
            let previous = controller.previousState.item(id: item.id)?.location
            guard previous == item.location, let node = itemNodes[item.id], !node.awaitingDrop else { return nil }
            return (item.id, layout.position(of: item), binCenter(.matching(item.kind)))
        }
        tutorialGuide.update(frameTime: frameTime, target: target, isDragging: !drag.draggedNodes.isEmpty)
    }

    /// Call when returning from pause/background so the gap isn't treated as one long frame.
    func resetClock() {
        lastUpdate = nil
    }

    private func syncItems(frameTime: TimeInterval, time: TimeInterval) {
        let state = controller.simulation.state
        let previous = Dictionary(uniqueKeysWithValues: controller.previousState.items.map { ($0.id, $0) })
        let alpha = controller.interpolation
        let smoothing = 1 - exp(-frameTime * 18)

        for item in state.items {
            let node = itemNodes[item.id] ?? makeNode(for: item)
            // Fuses don't burn in training, so a frozen countdown would only confuse.
            if let fuse = item.fuseTicks, controller.mode.usesOverload {
                node.updateFuse(ticksRemaining: fuse, tickRate: controller.config.tickRate, time: time)
            }
            guard !node.isDragged, !node.awaitingDrop else { continue }

            var target = layout.position(of: item)
            if case .belt(let now) = item.location, case .belt(let before)? = previous[item.id]?.location {
                target = layout.beltPosition(lane: item.lane, progress: before + (now - before) * alpha)
            }
            // Snap while riding the belt; glide when entering the buffer or returning from a drag.
            if node.position.distance(to: target) < 6 {
                node.position = target
            } else {
                node.position = node.position + (target - node.position) * smoothing
            }
        }
    }

    private func makeNode(for item: Item) -> ItemNode {
        let node = ItemNode(itemID: item.id, kind: item.kind,
                            texture: textures.item(item.kind, size: layout.itemSize), size: layout.itemSize)
        node.position = layout.position(of: item)
        node.setScale(0.2)
        node.run(.scale(to: 1, duration: 0.15), withKey: "scale")
        itemLayer.addChild(node)
        itemNodes[item.id] = node
        return node
    }

    private func updateBinHighlights() {
        let hovered = Set(drag.draggedNodes.compactMap { layout.bin(at: $0.position) })
        for (bin, node) in bins {
            node.setHighlighted(hovered.contains(bin))
        }
    }

    // MARK: - Events

    private func handle(_ events: [GameEvent]) {
        for event in events {
            drone?.react(to: event)
            switch event {
            case .spawned, .enteredBuffer, .runEnded:
                break

            case .sorted(let id, let bin, let points, _, _):
                guard let node = takeNode(id) else { break }
                let center = binCenter(bin)
                vanish(node, into: center)
                bins[bin]?.flash(success: true)
                effects.burst(at: center, color: textures.theme.color(for: node.kind))
                effects.popup("+\(points)", at: center + CGPoint(x: 0, y: layout.binRow.height * 0.5), color: textures.theme.color(for: node.kind))
                haptics.sorted()
                tutorialGuide?.noteSorted()

            case .comboTierUp(let multiplier):
                effects.popup("×\(multiplier) COMBO", at: CGPoint(x: size.width / 2, y: layout.trayRect.maxY + layout.itemSize * 1.2),
                              color: textures.theme.valuable, size: 30)
                haptics.comboTierUp()
                if let drone {
                    effects.burst(at: drone.position, color: textures.theme.valuable, count: 16, speed: 120)
                }

            case .missorted(let id, let bin):
                guard let node = takeNode(id) else { break }
                vanish(node, into: binCenter(bin))
                bins[bin]?.flash(success: false)
                effects.popup("WRONG BIN", at: binCenter(bin) + CGPoint(x: 0, y: layout.binRow.height * 0.5), color: textures.theme.danger)
                effects.shake()
                haptics.mistake()

            case .rejected(let id, let bin):
                itemNodes[id]?.awaitingDrop = false
                bins[bin]?.flash(success: false)
                effects.popup("MATCH THE SHAPE", at: binCenter(bin) + CGPoint(x: 0, y: layout.binRow.height * 0.5),
                              color: textures.theme.danger, size: 16)
                haptics.mistake()

            case .shieldUsed(let id, let bin):
                guard let node = takeNode(id) else { break }
                vanish(node, into: binCenter(bin))
                effects.popup("SHIELD", at: binCenter(bin) + CGPoint(x: 0, y: layout.binRow.height * 0.5), color: textures.theme.standard)

            case .lost(let id):
                guard let node = takeNode(id) else { break }
                node.run(.sequence([.group([.moveBy(x: 30, y: -40, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
                effects.popup("LOST", at: node.position, color: textures.theme.danger)
                haptics.mistake()

            case .hazardExpired(let id):
                guard let node = takeNode(id) else { break }
                effects.burst(at: node.position, color: textures.theme.danger, count: 60, speed: 320)
                node.removeFromParent()
                effects.shake(intensity: 14)
                haptics.explosion()

            case .comboBroken(let previous):
                if previous >= 5 {
                    effects.popup("COMBO LOST", at: CGPoint(x: size.width / 2, y: layout.trayRect.maxY + layout.itemSize * 1.2),
                                  color: textures.theme.danger, size: 22)
                }

            case .revived:
                for id in Array(itemNodes.keys) {
                    takeNode(id)?.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
                }
            }
        }
    }

    private func takeNode(_ id: Int) -> ItemNode? {
        drag.forget(itemID: id)
        return itemNodes.removeValue(forKey: id)
    }

    private func binCenter(_ bin: BinID) -> CGPoint {
        let rect = layout.binRect(bin)
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private func vanish(_ node: ItemNode, into point: CGPoint) {
        node.removeAllActions()
        node.run(.sequence([
            .group([.move(to: point, duration: 0.12), .scale(to: 0.3, duration: 0.12), .fadeOut(withDuration: 0.12)]),
            .removeFromParent(),
        ]))
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard controller.phase == .playing else { return }
        for touch in touches {
            if let node = drag.begin(touch: touch, at: touch.location(in: self), candidates: itemNodes.values) {
                controller.enqueue(.grab(itemID: node.itemID))
                haptics.grab()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            drag.move(touch: touch, to: touch.location(in: self))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let node = drag.end(touch: touch) else { continue }
            node.settle()
            if let bin = layout.bin(at: node.position) ?? layout.bin(at: touch.location(in: self)) {
                node.awaitingDrop = true
                controller.enqueue(.drop(itemID: node.itemID, bin: bin))
            } else {
                controller.enqueue(.release(itemID: node.itemID))
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let node = drag.end(touch: touch) else { continue }
            node.settle()
            controller.enqueue(.release(itemID: node.itemID))
        }
    }

    /// Drops every held item back onto the board, e.g. when pausing.
    func releaseAllDrags() {
        for node in drag.cancelAll() {
            node.settle()
            controller.enqueue(.release(itemID: node.itemID))
        }
    }
}

private func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
private func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
private func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint { CGPoint(x: lhs.x * rhs, y: lhs.y * rhs) }
