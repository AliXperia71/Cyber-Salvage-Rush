/// A friend's score on a challenge, shared back as text, e.g. `K7Q2XM-0003F9-Z`.
///
/// 6 challenge symbols + 6 score symbols (30 bits) + 1 check symbol over all twelve.
/// Typo-proof, not cheat-proof: there is no backend to verify scores.
public struct ResultCode: Sendable, Hashable, CustomStringConvertible {
    static let scoreSymbols = 6
    public static let maxScore = (1 << (5 * scoreSymbols)) - 1

    public let challenge: ChallengeCode
    public let score: Int

    public init?(challenge: ChallengeCode, score: Int) {
        guard (0...Self.maxScore).contains(score) else { return nil }
        self.challenge = challenge
        self.score = score
    }

    public init?(_ string: String) {
        let total = ChallengeCode.length + Self.scoreSymbols + 1
        guard let digits = CrockfordBase32.digits(from: string), digits.count == total else { return nil }
        let body = Array(digits.dropLast())
        guard CrockfordBase32.checkDigit(for: body) == digits.last,
              let challenge = ChallengeCode(CrockfordBase32.string(from: body.prefix(ChallengeCode.length)))
        else { return nil }
        self.init(challenge: challenge, score: Int(CrockfordBase32.value(of: body.suffix(Self.scoreSymbols))))
    }

    public var description: String {
        let challengeDigits = CrockfordBase32.digits(from: challenge.description)!
        let scoreDigits = CrockfordBase32.digits(of: UInt64(score), count: Self.scoreSymbols)
        let check = CrockfordBase32.checkDigit(for: challengeDigits + scoreDigits)
        return "\(challenge)-\(CrockfordBase32.string(from: scoreDigits))-\(CrockfordBase32.alphabet[check])"
    }
}
