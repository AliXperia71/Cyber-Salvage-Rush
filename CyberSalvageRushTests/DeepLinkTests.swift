import Foundation
@testable import SalvageCore
import Testing
@testable import CyberSalvageRush

struct DeepLinkTests {
    private let challenge = ChallengeCode(configVersion: 1, seed: 987_654)!
    private var result: ResultCode { ResultCode(challenge: challenge, score: 4_242)! }

    @Test func roundTripsThroughURL() {
        #expect(DeepLink(url: DeepLink.challenge(challenge).url) == .challenge(challenge))
        #expect(DeepLink(url: DeepLink.result(result).url) == .result(result))
    }

    @Test func toleratesCaseAndTrailingSlash() {
        let lower = URL(string: "CyberSalvage://Challenge/\(challenge.description.lowercased())/")!
        #expect(DeepLink(url: lower) == .challenge(challenge))
    }

    @Test func rejectsForeignOrBrokenLinks() {
        #expect(DeepLink(url: URL(string: "https://challenge/\(challenge)")!) == nil)
        #expect(DeepLink(url: URL(string: "cybersalvage://shop/\(challenge)")!) == nil)
        #expect(DeepLink(url: URL(string: "cybersalvage://challenge/")!) == nil)
        #expect(DeepLink(url: URL(string: "cybersalvage://challenge/ZZZZZZ")!) == nil)
        #expect(DeepLink(url: URL(string: "cybersalvage://result/\(challenge)")!) == nil)
    }

    @Test func parsesPastedText() {
        #expect(DeepLink(text: "  \(challenge.description.lowercased()) ") == .challenge(challenge))
        #expect(DeepLink(text: result.description) == .result(result))
        #expect(DeepLink(text: result.shareMessage.components(separatedBy: "\n").last!) == .result(result))
        #expect(DeepLink(text: "hello") == nil)
        #expect(DeepLink(text: "") == nil)
    }

    @Test func shareMessagesLeadWithTheCode() {
        #expect(challenge.shareMessage.contains(challenge.description))
        #expect(challenge.shareMessage.contains("cybersalvage://challenge/\(challenge)"))
        #expect(result.shareMessage.contains(result.description))
    }

    @Test func unknownConfigVersionIsNotPlayable() {
        #expect(challenge.isPlayable)
        #expect(!ChallengeCode(configVersion: 7, seed: 1)!.isPlayable)
    }
}
