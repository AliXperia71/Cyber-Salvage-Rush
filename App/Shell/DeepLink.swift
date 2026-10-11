import Foundation
import SalvageCore

/// `cybersalvage://challenge/K7Q2XM` and `cybersalvage://result/K7Q2XM-0003F9-Z`.
enum DeepLink: Equatable {
    case challenge(ChallengeCode)
    case result(ResultCode)

    static let scheme = "cybersalvage"

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let host = url.host()?.lowercased(),
              let code = url.pathComponents.dropFirst().first
        else { return nil }
        switch host {
        case "challenge":
            guard let challenge = ChallengeCode(code) else { return nil }
            self = .challenge(challenge)
        case "result":
            guard let result = ResultCode(code) else { return nil }
            self = .result(result)
        default:
            return nil
        }
    }

    /// Whatever a player pastes: a full link, a result code, or a challenge code.
    init?(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("://") {
            guard let url = URL(string: trimmed) else { return nil }
            self.init(url: url)
        } else if let result = ResultCode(trimmed) {
            self = .result(result)
        } else if let challenge = ChallengeCode(trimmed) {
            self = .challenge(challenge)
        } else {
            return nil
        }
    }

    var url: URL {
        switch self {
        case .challenge(let code): URL(string: "\(Self.scheme)://challenge/\(code)")!
        case .result(let result): URL(string: "\(Self.scheme)://result/\(result)")!
        }
    }
}

extension ChallengeCode {
    /// The code leads because many messaging apps don't make custom-scheme links tappable.
    var shareMessage: String {
        "Beat my score in Cyber Salvage Rush! Challenge code: \(self)\n\(DeepLink.challenge(self).url)"
    }

    /// False when the code came from a newer app version with a config this build lacks.
    var isPlayable: Bool { GameConfig.version(configVersion) != nil }
}

extension ResultCode {
    var shareMessage: String {
        "I scored \(score.formatted()) on Cyber Salvage Rush challenge \(challenge). Result code: \(self)\n\(DeepLink.result(self).url)"
    }
}
