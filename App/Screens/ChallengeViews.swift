import SalvageCore
import SwiftUI

struct ChallengeRoute: Hashable {
    let code: ChallengeCode
    /// A friend's result to pre-fill, e.g. from an opened result link.
    var draftResult: String?
}

/// Create, join, and track friend challenges. Everything is local; codes carry the whole run.
struct ChallengesView: View {
    @Environment(ChallengeRepository.self) private var challenges
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var path: [ChallengeRoute] = []
    @State private var draft = ""
    @State private var draftInvalid = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        var generator = SystemRandomNumberGenerator()
                        open(.challenge(ChallengeCode.random(using: &generator)))
                    } label: {
                        Label("New Challenge", systemImage: "plus.circle.fill")
                            .font(.system(.headline, design: .monospaced).weight(.heavy))
                            .foregroundStyle(Palette.cyan)
                    }
                } footer: {
                    Text("Everyone with the code gets the exact same belt. Highest score wins.")
                }

                Section {
                    HStack {
                        TextField("Challenge or result code", text: $draft)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .onSubmit(openDraft)
                            .onChange(of: draft) { draftInvalid = false }
                        Button("Open", action: openDraft)
                            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Got a code?")
                } footer: {
                    if draftInvalid {
                        Text("That code doesn't check out. Look for a typo.")
                            .foregroundStyle(Palette.danger)
                    }
                }

                if !challenges.challenges.isEmpty {
                    Section("Your challenges") {
                        ForEach(challenges.challenges) { summary in
                            NavigationLink(value: ChallengeRoute(code: summary.code)) {
                                ChallengeRow(summary: summary)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { challenges.challenges[$0].code }.forEach(challenges.delete)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ChallengeRoute.self) { ChallengeDetailView(route: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            challenges.refresh()
            consumePendingLink()
        }
        .onChange(of: router.pendingLink) { consumePendingLink() }
    }

    private func openDraft() {
        guard let link = DeepLink(text: draft) else {
            draftInvalid = true
            return
        }
        draft = ""
        open(link)
    }

    private func consumePendingLink() {
        guard let link = router.pendingLink else { return }
        router.pendingLink = nil
        open(link)
    }

    private func open(_ link: DeepLink) {
        switch link {
        case .challenge(let code):
            challenges.track(code)
            path = [ChallengeRoute(code: code)]
        case .result(let result):
            challenges.track(result.challenge)
            path = [ChallengeRoute(code: result.challenge, draftResult: result.description)]
        }
    }
}

private struct ChallengeRow: View {
    let summary: ChallengeSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.code.description)
                    .font(.system(.headline, design: .monospaced).weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(Palette.text)
                Text(detail)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Palette.stroke)
            }
            Spacer()
            if isLeading {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Palette.gold)
                    .accessibilityLabel("You're leading")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let mine = summary.myBest.map { "You \($0.formatted())" } ?? "Not played"
        let count = summary.friends.count
        return count == 0 ? mine : "\(mine) · \(count) friend\(count == 1 ? "" : "s")"
    }

    private var isLeading: Bool {
        guard let mine = summary.myBest, let top = summary.friends.first else { return false }
        return mine >= top.score
    }
}

struct ChallengeDetailView: View {
    let route: ChallengeRoute
    @Environment(ChallengeRepository.self) private var challenges
    @Environment(AppRouter.self) private var router
    @State private var resultDraft: String
    @State private var friendName = ""
    @State private var addError: String?

    init(route: ChallengeRoute) {
        self.route = route
        _resultDraft = State(initialValue: route.draftResult ?? "")
    }

    private var code: ChallengeCode { route.code }
    private var summary: ChallengeSummary? { challenges.summary(for: code) }

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    Text(code.description)
                        .font(.system(size: 44, weight: .black, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(Palette.cyan)
                        .minimumScaleFactor(0.5)
                        .textSelection(.enabled)
                        .accessibilityLabel("Code \(code.description.map(String.init).joined(separator: " "))")

                    if code.isPlayable {
                        Button {
                            challenges.track(code)
                            router.screen = .run(.challenge(code))
                        } label: {
                            Label("PLAY", systemImage: "play.fill")
                        }
                        .buttonStyle(NeonButtonStyle())
                    } else {
                        Text("This challenge needs a newer version of the app.")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(Palette.danger)
                            .multilineTextAlignment(.center)
                    }

                    ShareLink(item: code.shareMessage) {
                        Label("SHARE CODE", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(NeonButtonStyle(color: Palette.gold, prominent: false))
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section("Leaderboard") {
                if leaderboard.isEmpty {
                    Text("No scores yet. Play it, share the code, and paste friends' results below.")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Palette.stroke)
                } else {
                    ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, row in
                        LeaderboardRow(rank: index + 1, row: row)
                    }
                }
            }

            Section {
                TextField("Result code", text: $resultDraft)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: resultDraft) { addError = nil }
                TextField("Friend's name (optional)", text: $friendName)
                    .textInputAutocapitalization(.words)
                Button("Add Result", action: addResult)
                    .disabled(resultDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Add a friend's result")
            } footer: {
                if let addError {
                    Text(addError).foregroundStyle(Palette.danger)
                } else {
                    Text("Friends get a result code after playing. Paste it here.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Challenge")
        .navigationBarTitleDisplayMode(.inline)
    }

    fileprivate struct Row: Identifiable {
        let id: String
        let name: String
        let score: Int
        let isPlayer: Bool
    }

    /// The player's best plus friends', highest first; the player wins ties.
    private var leaderboard: [Row] {
        var rows = (summary?.friends ?? []).map { Row(id: $0.id, name: $0.name ?? "Friend", score: $0.score, isPlayer: false) }
        if let mine = summary?.myBest {
            rows.append(Row(id: "you", name: "You", score: mine, isPlayer: true))
        }
        return rows.sorted { ($0.score, $0.isPlayer ? 1 : 0) > ($1.score, $1.isPlayer ? 1 : 0) }
    }

    private func addResult() {
        guard let result = ResultCode(resultDraft) else {
            addError = "That result code doesn't check out. Look for a typo."
            return
        }
        guard result.challenge == code else {
            addError = "That result is for challenge \(result.challenge), not this one."
            return
        }
        do {
            try challenges.addResult(result, name: friendName)
            resultDraft = ""
            friendName = ""
        } catch {
            addError = "That result is already on the board."
        }
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let row: ChallengeDetailView.Row

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                .foregroundStyle(rank == 1 ? Palette.gold : Palette.stroke)
                .frame(minWidth: 24)
            Text(row.name)
                .font(.system(.body, design: .monospaced).weight(row.isPlayer ? .heavy : .regular))
                .foregroundStyle(row.isPlayer ? Palette.cyan : Palette.text)
            Spacer()
            Text(row.score.formatted())
                .font(.system(.body, design: .monospaced).weight(.bold))
                .foregroundStyle(Palette.text)
        }
        .accessibilityElement(children: .combine)
    }
}
