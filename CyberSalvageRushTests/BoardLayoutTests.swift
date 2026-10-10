import SalvageCore
import Testing
import UIKit
@testable import CyberSalvageRush

struct BoardLayoutTests {
    /// iPhone SE (smallest supported) through Pro Max.
    static let screens: [(CGSize, UIEdgeInsets)] = [
        (CGSize(width: 375, height: 667), UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)),
        (CGSize(width: 393, height: 852), UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)),
        (CGSize(width: 440, height: 956), UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0)),
    ]

    @Test(arguments: 0..<screens.count)
    func regionsStackWithoutOverlap(index: Int) {
        let (size, insets) = Self.screens[index]
        let layout = BoardLayout(size: size, insets: insets, laneCount: 2, bufferCapacity: 6)
        #expect(layout.binRow.minY >= insets.bottom)
        #expect(layout.trayRect.minY > layout.binRow.maxY)
        let lowestLane = (0..<2).map(layout.laneY).min()!
        let highestLane = (0..<2).map(layout.laneY).max()!
        #expect(lowestLane - layout.itemSize / 2 > layout.trayRect.maxY)
        #expect(highestLane + layout.itemSize / 2 < size.height - insets.top - BoardLayout.hudHeight + layout.itemSize)
        for bin in BinID.allCases {
            #expect(layout.binRect(bin).width >= 88, "bins must be comfortable thumb targets")
            #expect(layout.bin(at: CGPoint(x: layout.binRect(bin).midX, y: layout.binRect(bin).midY)) == bin)
        }
    }

    @Test func bufferSlotsAreDistinctAndInsideTray() {
        let layout = BoardLayout(size: CGSize(width: 393, height: 852), insets: .zero, laneCount: 2, bufferCapacity: 4)
        let xs = (0..<4).map { layout.bufferSlotPosition($0).x }
        #expect(Set(xs).count == 4)
        #expect(xs.allSatisfy { layout.trayRect.minX < $0 && $0 < layout.trayRect.maxX })
    }
}
