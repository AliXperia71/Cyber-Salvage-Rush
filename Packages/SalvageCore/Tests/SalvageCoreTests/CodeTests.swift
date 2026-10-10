import Testing
@testable import SalvageCore

struct CodeTests {
    @Test func challengeRoundTrip() {
        var rng = SeededGenerator(seed: 1)
        for _ in 0..<1_000 {
            let code = ChallengeCode.random(using: &rng)
            #expect(code.description.count == ChallengeCode.length)
            #expect(ChallengeCode(code.description) == code)
        }
    }

    @Test func extremesRoundTrip() {
        for code in [ChallengeCode(configVersion: 1, seed: 0)!, ChallengeCode(configVersion: 7, seed: ChallengeCode.maxSeed)!] {
            #expect(ChallengeCode(code.description) == code)
        }
    }

    @Test func everySingleSymbolTypoIsRejected() {
        let alphabet = CrockfordBase32.alphabet
        var rng = SeededGenerator(seed: 2)
        for _ in 0..<20 {
            let original = Array(ChallengeCode.random(using: &rng).description)
            for position in original.indices {
                for symbol in alphabet where symbol != original[position] {
                    var typo = original
                    typo[position] = symbol
                    #expect(ChallengeCode(String(typo)) == nil, "\(String(typo))")
                }
            }
        }
    }

    @Test func normalizesInput() {
        let code = ChallengeCode(configVersion: 1, seed: 0)!
        let lowered = code.description.lowercased()
        #expect(ChallengeCode(lowered) == code)
        #expect(ChallengeCode(" " + code.description.prefix(3) + "-" + code.description.suffix(3) + " ") == code)
        let withLookalikes = code.description.replacingOccurrences(of: "0", with: "O")
        #expect(ChallengeCode(withLookalikes) == code)
    }

    @Test func rejectsMalformed() {
        #expect(ChallengeCode("") == nil)
        #expect(ChallengeCode("ABCDE") == nil)
        #expect(ChallengeCode("ABCDEFG") == nil)
        #expect(ChallengeCode("ABCDE!") == nil)
        #expect(ChallengeCode("UUUUUU") == nil)
    }

    @Test func distinctSeedsGiveDistinctSimulationSeeds() {
        let seeds = Set((0..<1_000).map { ChallengeCode(configVersion: 1, seed: UInt32($0))!.simulationSeed })
        #expect(seeds.count == 1_000)
    }

    @Test func resultRoundTripAndTypos() {
        let challenge = ChallengeCode(configVersion: 1, seed: 987_654)!
        for score in [0, 1, 12_345, ResultCode.maxScore] {
            let result = ResultCode(challenge: challenge, score: score)!
            #expect(ResultCode(result.description) == result)
        }
        let text = Array(ResultCode(challenge: challenge, score: 4_242)!.description)
        for position in text.indices where text[position] != "-" {
            var typo = text
            typo[position] = typo[position] == "Z" ? "Y" : "Z"
            #expect(ResultCode(String(typo)) == nil, "\(String(typo))")
        }
        #expect(ResultCode(challenge: challenge, score: -1) == nil)
        #expect(ResultCode(challenge: challenge, score: ResultCode.maxScore + 1) == nil)
    }
}
