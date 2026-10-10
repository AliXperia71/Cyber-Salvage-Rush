import Testing
@testable import SalvageCore

struct RandomTests {
    @Test func sameSeedSameSequence() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        #expect((0..<100).map { _ in a.next() } == (0..<100).map { _ in b.next() })
    }

    @Test func differentSeedsDiverge() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        #expect(a.next() != b.next())
    }

    @Test func unitDoubleInRange() {
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<10_000 {
            let value = rng.unitDouble()
            #expect(value >= 0 && value < 1)
        }
    }

    @Test func fnv1aKnownVectors() {
        #expect(StableHash.fnv1a("") == 0xCBF2_9CE4_8422_2325)
        #expect(StableHash.fnv1a("a") == 0xAF63_DC4C_8601_EC8C)
    }
}
