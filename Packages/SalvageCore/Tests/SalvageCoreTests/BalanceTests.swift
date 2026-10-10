import Testing
@testable import SalvageCore

/// The spec targets 60–90 s runs. A decent simulated player should land in that window.
struct BalanceTests {
    @Test func medianRunLengthIsInTargetWindow() {
        let durations = (0..<200).map { BalanceBot.play(seed: UInt64($0)).durationSeconds }.sorted()
        let median = durations[durations.count / 2]
        print("Balance: p10=\(durations[20]) median=\(median) p90=\(durations[180])")
        #expect((60...90).contains(median))
    }

    /// First cosmetic (150 credits) should take about 2–3 runs.
    @Test func typicalRunEarnsMeaningfulCredits() {
        let scores = (0..<50).map { BalanceBot.play(seed: UInt64(1_000 + $0)).score }.sorted()
        let medianCredits = Double(scores[25]) / Double(EconomyConfig.standard.scorePerCredit)
        print("Balance: median score=\(scores[25]) credits≈\(medianCredits)")
        #expect((50...100).contains(medianCredits))
    }
}
