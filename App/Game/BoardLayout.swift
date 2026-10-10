import SalvageCore
import UIKit

/// Pure geometry for the board in scene coordinates (origin bottom-left).
///
/// Top to bottom: HUD inset → conveyor lanes (flow left → right) → buffer tray → bins.
struct BoardLayout {
    let size: CGSize
    let insets: UIEdgeInsets
    let laneCount: Int
    let bufferCapacity: Int

    static let hudHeight: CGFloat = 96
    static let sideMargin: CGFloat = 16

    var itemSize: CGFloat { min(size.width * 0.15, 64) }

    // MARK: Bins

    var binRow: CGRect {
        let height = min(size.height * 0.17, 150)
        return CGRect(x: Self.sideMargin, y: insets.bottom + 12, width: size.width - Self.sideMargin * 2, height: height)
    }

    func binRect(_ bin: BinID) -> CGRect {
        let gap: CGFloat = 10
        let count = CGFloat(BinID.allCases.count)
        let width = (binRow.width - gap * (count - 1)) / count
        return CGRect(x: binRow.minX + CGFloat(bin.rawValue) * (width + gap), y: binRow.minY, width: width, height: binRow.height)
    }

    // MARK: Buffer

    var trayRect: CGRect {
        let height = itemSize * 1.5
        return CGRect(x: Self.sideMargin, y: binRow.maxY + 22, width: size.width - Self.sideMargin * 2, height: height)
    }

    func bufferSlotPosition(_ slot: Int) -> CGPoint {
        let spacing = trayRect.width / CGFloat(bufferCapacity)
        return CGPoint(x: trayRect.minX + spacing * (CGFloat(slot) + 0.5), y: trayRect.midY)
    }

    // MARK: Conveyor

    private var conveyorRegion: ClosedRange<CGFloat> {
        (trayRect.maxY + itemSize)...(size.height - insets.top - Self.hudHeight - itemSize * 0.5)
    }

    func laneY(_ lane: Int) -> CGFloat {
        let region = conveyorRegion
        guard laneCount > 1 else { return (region.lowerBound + region.upperBound) / 2 }
        let fraction = 0.2 + 0.6 * CGFloat(lane) / CGFloat(laneCount - 1)
        return region.upperBound - (region.upperBound - region.lowerBound) * fraction
    }

    var beltStartX: CGFloat { -itemSize * 0.5 }
    var beltEndX: CGFloat { size.width - Self.sideMargin - itemSize * 0.5 }
    var beltLength: CGFloat { beltEndX - beltStartX }

    func beltPosition(lane: Int, progress: Double) -> CGPoint {
        CGPoint(x: beltStartX + beltLength * CGFloat(progress), y: laneY(lane))
    }

    func position(of item: Item) -> CGPoint {
        switch item.location {
        case .belt(let progress): beltPosition(lane: item.lane, progress: progress)
        case .buffer(let slot): bufferSlotPosition(slot)
        }
    }

    /// The bin a drop at `point` lands in, with a forgiving margin.
    func bin(at point: CGPoint) -> BinID? {
        BinID.allCases.first { binRect($0).insetBy(dx: -8, dy: -24).contains(point) }
    }
}
