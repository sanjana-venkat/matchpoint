import SwiftUI

struct LiveMatchView: View {
    let faceOff: FaceOff
    @EnvironmentObject private var app: AppState
    private var accent: Color { Theme.color(for: faceOff.sport) }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: Phase = .countdown
    @State private var countdown = 3
    @State private var startedAt = Date()
    @State private var scores = [GameScore(myScore: 0, opponentScore: 0)]
    @State private var summary: LiveMatchSummary?
    @State private var celebration = false

    private enum Phase { case countdown, playing, result }

    private var opponent: Player? { app.player(faceOff.opponentId) }
    private var canFinish: Bool {
        let myGames = scores.filter(\.iWon).count
        let opponentGames = scores.filter { $0.opponentScore > $0.myScore }.count
        return scores.allSatisfy { $0.myScore != $0.opponentScore } && myGames != opponentGames
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch phase {
            case .countdown:
                countdownView
            case .playing:
                gameView
            case .result:
                resultView
            }
        }
        .preferredColorScheme(.light)
        .task {
            guard phase == .countdown else { return }
            for value in stride(from: 3, through: 1, by: -1) {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.64)) {
                    countdown = value
                }
                try? await Task.sleep(for: .seconds(0.82))
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
                startedAt = .now
#if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-demo-match-result") {
                    let demoScores = [
                        GameScore(myScore: 11, opponentScore: 7),
                        GameScore(myScore: 8, opponentScore: 11),
                        GameScore(myScore: 11, opponentScore: 6)
                    ]
                    scores = demoScores
                    summary = app.completeLiveMatch(faceOffId: faceOff.id, scores: demoScores)
                    celebration = true
                    phase = .result
                } else {
                    phase = .playing
                }
#else
                phase = .playing
#endif
            }
        }
    }

    private var countdownView: some View {
        VStack(spacing: 18) {
            Text("MATCH READY")
                .font(Theme.ui(11, weight: .bold))
                .tracking(2.2)
                .foregroundStyle(accent)
            Text("\(countdown)")
                .font(Theme.display(190).monospacedDigit())
                .foregroundStyle(.white)
                .id(countdown)
                .transition(.scale.combined(with: .opacity))
            Text("\(app.me.name)  vs  \(faceOff.opponentName)")
                .font(Theme.heading(20))
                .foregroundStyle(.white)
        }
    }

    private var gameView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.10), in: Circle())
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("LIVE MATCH")
                        .font(Theme.ui(9, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(accent)
                    TimelineView(.periodic(from: startedAt, by: 1)) { context in
                        Text(elapsed(context.date))
                            .font(Theme.display(24).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
                Spacer()
                Color.clear.frame(width: 38, height: 38)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 20) {
                    competitors

                    VStack(spacing: 10) {
                        ForEach(Array(scores.indices), id: \.self) { index in
                            GameScoreRow(
                                gameNumber: index + 1,
                                myName: shortName(app.me.name, fallback: "You"),
                                opponentName: shortName(faceOff.opponentName, fallback: "Rival"),
                                accent: accent,
                                score: $scores[index]
                            )
                        }

                        Button {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75)) {
                                scores.append(GameScore(myScore: 0, opponentScore: 0))
                            }
                        } label: {
                            Label("Add another game", systemImage: "plus")
                                .font(Theme.ui(12, weight: .bold))
                                .foregroundStyle(accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(SorbetScaleButtonStyle())
                    }

                    HStack(spacing: 11) {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(Theme.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("THE WAGER")
                                .font(Theme.ui(9, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(Theme.muted)
                            Text(faceOff.wager)
                                .font(Theme.heading(15))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(15)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))

                    if faceOff.isRatingExempt {
                        Text("Unrated match — Elo unchanged")
                            .font(Theme.ui(11, weight: .bold))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        guard let result = app.completeLiveMatch(faceOffId: faceOff.id, scores: scores) else { return }
                        summary = result
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                            phase = .result
                            celebration = true
                        }
                    } label: {
                        HStack {
                            Text(canFinish ? "Finish match" : "Complete every game")
                            Spacer()
                            Image(systemName: "flag.checkered")
                        }
                        .font(Theme.ui(15, weight: .bold))
                        .foregroundStyle(canFinish ? Theme.bg : Theme.muted)
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .background(canFinish ? accent : Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(SorbetScaleButtonStyle())
                    .disabled(!canFinish)
                }
                .padding(18)
                .padding(.bottom, 24)
            }
        }
    }

    private var competitors: some View {
        HStack(spacing: 14) {
            VStack(spacing: 8) {
                AvatarView(avatar: app.me.avatar, size: 74)
                Text(shortName(app.me.name, fallback: "You"))
                    .font(Theme.heading(15))
                    .foregroundStyle(.white)
                Text("\(scores.filter(\.iWon).count) games")
                    .font(Theme.ui(10, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity)

            Text("VS")
                .font(Theme.display(24))
                .foregroundStyle(Theme.muted)

            VStack(spacing: 8) {
                AvatarView(avatar: opponent?.avatar ?? .fallback, size: 74)
                Text(shortName(faceOff.opponentName, fallback: "Rival"))
                    .font(Theme.heading(15))
                    .foregroundStyle(.white)
                Text("\(scores.filter { $0.opponentScore > $0.myScore }.count) games")
                    .font(Theme.ui(10, weight: .bold))
                    .foregroundStyle(Theme.pink)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var resultView: some View {
        if let summary {
            ZStack {
                if !reduceMotion {
                    ConfettiField(active: celebration, color: summary.didWin ? accent : Theme.blue)
                }

                VStack(spacing: 19) {
                    Text(summary.didWin ? "MATCH WON" : "MATCH COMPLETE")
                        .font(Theme.ui(11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(summary.didWin ? accent : Theme.blue)

                    AvatarView(
                        avatar: summary.didWin ? app.me.avatar : summary.opponentAvatar,
                        size: 132
                    )
                    .scaleEffect(celebration ? 1 : 0.72)
                    .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.58), value: celebration)

                    VStack(spacing: 5) {
                        Text(summary.didWin ? "You brought it home." : "\(summary.opponentName) takes this one.")
                            .font(Theme.heading(28))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("\(summary.myGames)–\(summary.opponentGames) games · \(summary.wager)")
                            .font(Theme.ui(13))
                            .foregroundStyle(Theme.muted)
                    }

                    HStack(spacing: 0) {
                        resultMetric("\(summary.ratingBefore)", "Before")
                        resultMetric(summary.ratingDelta >= 0 ? "+\(summary.ratingDelta)" : "\(summary.ratingDelta)", "Projected")
                        resultMetric("\(summary.ratingAfter)", "If verified")
                    }
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))

                    Text("Sent to \(summary.opponentName) for verification. Your statistics and Elo will update only after they confirm every result.")
                        .font(Theme.ui(12))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    Button("Back to home") { dismiss() }
                        .font(Theme.ui(15, weight: .bold))
                        .foregroundStyle(Theme.bg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(accent, in: RoundedRectangle(cornerRadius: 18))
                        .buttonStyle(SorbetScaleButtonStyle())
                }
                .padding(24)
            }
        }
    }

    private func resultMetric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Theme.display(28).monospacedDigit())
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(Theme.ui(8, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func shortName(_ name: String, fallback: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? fallback
    }

    private func elapsed(_ now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(startedAt)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct GameScoreRow: View {
    let gameNumber: Int
    let myName: String
    let opponentName: String
    let accent: Color
    @Binding var score: GameScore

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("GAME \(gameNumber)")
                    .font(Theme.ui(9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
                Spacer()
                if score.myScore != score.opponentScore {
                    Text(score.iWon ? "\(myName) leads" : "\(opponentName) leads")
                        .font(Theme.ui(9, weight: .bold))
                        .foregroundStyle(score.iWon ? accent : Theme.pink)
                }
            }

            scoreControl(name: myName, value: $score.myScore, color: accent)
            scoreControl(name: opponentName, value: $score.opponentScore, color: Theme.pink)
        }
        .padding(15)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(Color.white.opacity(0.09), lineWidth: 1))
    }

    private func scoreControl(name: String, value: Binding<Int>, color: Color) -> some View {
        HStack {
            Text(name)
                .font(Theme.ui(13, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                value.wrappedValue = max(0, value.wrappedValue - 1)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.09), in: Circle())
            }

            Text("\(value.wrappedValue)")
                .font(Theme.display(35).monospacedDigit())
                .foregroundStyle(color)
                .frame(width: 58)

            Button {
                value.wrappedValue += 1
            } label: {
                Image(systemName: "plus")
                    .foregroundStyle(Theme.bg)
                    .frame(width: 38, height: 38)
                    .background(color, in: Circle())
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ConfettiField: View {
    let active: Bool
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<26, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 3) ? Theme.pink : (index.isMultiple(of: 2) ? color : Theme.lime))
                    .frame(width: 7, height: 17)
                    .rotationEffect(.degrees(Double(index * 31)))
                    .position(
                        x: CGFloat((index * 47) % 360) / 360 * proxy.size.width,
                        y: active ? proxy.size.height + 30 : -40
                    )
                    .animation(
                        .easeIn(duration: 1.5 + Double(index % 5) * 0.12)
                            .delay(Double(index % 7) * 0.06),
                        value: active
                    )
            }
        }
        .allowsHitTesting(false)
    }
}
