import SwiftUI

// MARK: - Challenge composer (with free-form wager + hints)

struct ChallengeComposerView: View {
    let player: Player
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var note = ""
    @State private var proposedDates = [Date().addingTimeInterval(86_400)]
    @State private var venue = ""

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RallyPalette.cream.ignoresSafeArea()

            ScrollView {
                    VStack(alignment: .leading, spacing: RallyLayout.section) {
                    Text("Send a challenge")
                        .font(RallyType.cardTitle)
                        .rallyDisplayLeading()
                        .padding(.trailing, 52)

                    HStack(spacing: 16) {
                        RallyPlayerAvatar(player: player, size: 72)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(player.name)
                                .font(RallyType.cardTitle)
                                .foregroundStyle(Theme.ink)
                            Text(playerStatus)
                                .font(RallyType.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        RallyRatingPlate(
                            sport: app.activeSport,
                            profile: player.profile(app.activeSport),
                            diameter: 64
                        )
                    }
                    .padding(18)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Decide the wager together")
                            .font(RallyType.action)
                        Text("After the challenge is accepted, either of you can propose, accept, or skip a wager in chat.")
                            .font(RallyType.caption)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: RallyLayout.insetRadius, style: .continuous))

                    challengeField(title: "Match details") {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose one time. Add more options if you want to give \(player.firstName) flexibility.")
                                .font(RallyType.caption)
                                .foregroundStyle(Theme.muted)

                            ForEach(proposedDates.indices, id: \.self) { index in
                                HStack(spacing: 8) {
                                    RallyDateTimeSelector(
                                        label: proposedDates.count == 1 ? "When" : "Option \(index + 1)",
                                        selection: $proposedDates[index]
                                    )
                                    if proposedDates.count > 1 {
                                        Button {
                                            proposedDates.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(Theme.ink)
                                                .frame(width: 44, height: 44)
                                                .background(Theme.surface2, in: Circle())
                                        }
                                        .buttonStyle(RallyPressStyle())
                                        .accessibilityLabel("Remove time option \(index + 1)")
                                    }
                                }
                            }

                            if proposedDates.count < 3 {
                                Button {
                                    let next = (proposedDates.last ?? .now).addingTimeInterval(86_400)
                                    withAnimation(.easeInOut(duration: 0.18)) { proposedDates.append(next) }
                                } label: {
                                    Label("Add another time", systemImage: "plus")
                                        .font(RallyType.action)
                                        .foregroundStyle(Theme.ink)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .overlay(Capsule().stroke(Theme.ink.opacity(0.3), lineWidth: 1.5))
                                }
                                .buttonStyle(RallyPressStyle())
                            }

                            TextField("Venue or court", text: $venue)
                                .font(RallyType.body())
                                .padding(.horizontal, 18)
                                .frame(height: 54)
                                .background(Theme.surface2, in: Capsule())

                        }
                    }

                    challengeField(title: "Message / optional") {
                        TextField("Add a note, e.g. best of 3", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                            .font(RallyType.body())
                            .foregroundStyle(Theme.ink)
                            .padding(18)
                            .frame(minHeight: 108, alignment: .topLeading)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }

                    RallyPillButton(title: "Send challenge", icon: "arrow.right", style: .ink, fill: true) {
                        sendChallenge(isRatingExempt: isRatingMismatch)
                    }
                    }
                    .padding(.horizontal, RallyLayout.gutter)
                    .padding(.top, 28)
                    .padding(.bottom, 48)
                }

            CloseIconButton { dismiss() }
                .padding(.top, 24)
                .padding(.trailing, RallyLayout.gutter)
        }
        .preferredColorScheme(.light)
    }

    private func challengeField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(Theme.ui(10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)
            content()
        }
    }

    private var playerStatus: String {
        let chosen = app.activeSport
        guard let profile = player.profile(chosen) else { return chosen.title }
        if profile.usesElo { return "Elo \(profile.rating) · \(EloRating.tier(for: profile.rating))" }
        if chosen.category == .group { return "Peer-rated \(chosen.title) profile" }
        return profile.socialSkillLabel?.rawValue ?? "Unrated"
    }

    private var isRatingMismatch: Bool {
        app.isRatingExempt(opponentIds: [player.id], sport: app.activeSport)
    }

    private func sendChallenge(isRatingExempt: Bool = false) {
        app.createChallenge(
            with: player,
            sport: app.activeSport,
            date: proposedDates[0],
            proposedDates: proposedDates,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Venue TBD" : venue,
            note: note,
            isRatingExempt: isRatingExempt
        )
        dismiss()
    }
}

struct UnratedInviteConfirmationSheet: View {
    let name: String
    let sport: Sport
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Metrics.verticalRhythm) {
            Text("Heads up").font(Theme.heading(29))
            Text("\(name) isn't rated in \(sport.title) yet, so this match won't count toward your Elo or stats.")
                .font(Theme.ui(14)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            PrimaryButton(title: "Send invite anyway") { onConfirm(); dismiss() }
            Button("Don't send") { dismiss() }
                .font(Theme.ui(13, weight: .bold)).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity).frame(height: 44)
        }
        .padding(DesignSystem.Metrics.screenPadding)
        .background(Theme.bg)
        .preferredColorScheme(.light)
    }
}

// MARK: - Multiple challenge management

struct EditChallengesSheet: View {
    let player: Player
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Active challenges")
                        .font(Theme.heading(28))
                    Text("Change a time or location, then send the revision for confirmation.")
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.muted)

                    ForEach(app.activeChallenges(with: player.id)) { faceOff in
                        ChallengeEditCard(faceOff: faceOff)
                    }
                }
                .padding(20)
            }
            .background(Theme.bg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.light)
    }
}

private struct ChallengeEditCard: View {
    let faceOff: FaceOff
    @EnvironmentObject private var app: AppState
    @State private var date: Date
    @State private var venue: String

    init(faceOff: FaceOff) {
        self.faceOff = faceOff
        _date = State(initialValue: faceOff.date)
        _venue = State(initialValue: faceOff.venue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 7) {
                    SportIcon(sport: faceOff.sport, size: 24)
                    Text(faceOff.sport.title).font(Theme.ui(13, weight: .bold))
                }
                Spacer()
                Text("REV \(faceOff.revision)")
                    .font(Theme.ui(9, weight: .bold))
                    .foregroundStyle(Theme.color(for: faceOff.sport))
            }
            RallyDateTimeSelector(label: "Time", selection: $date)
            TextField("Venue", text: $venue)
                .padding(12)
                .background(Theme.faint, in: RoundedRectangle(cornerRadius: 13))
            HStack(spacing: 10) {
                Button(role: .destructive) { app.cancelChallenge(faceOff.id) } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    app.updateChallenge(
                        faceOff.id,
                        date: date,
                        venue: venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Venue TBD" : venue
                    )
                } label: {
                    Label("Send update", systemImage: "arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.color(for: faceOff.sport))
                .foregroundStyle(Theme.bg)
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.hairline, lineWidth: 1))
    }
}

// MARK: - Post-match score update

struct ScoreUpdateSheet: View {
    let faceOff: FaceOff
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var scores = [GameScore(myScore: 11, opponentScore: 9)]

    private var hasWinner: Bool {
        let myWins = scores.filter(\.iWon).count
        return scores.allSatisfy { $0.myScore != $0.opponentScore } && myWins != scores.count - myWins
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Spacer()
                        CloseIconButton { dismiss() }
                            .font(Theme.ui(13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10))
                            .buttonStyle(.plain)
                    }
                    Text("Record the result")
                        .font(Theme.heading(29))

                    matchSummary

                    Text("Enter each final score. Deuce scores are supported.")
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.muted)

                    GameScoreEditor(
                        scores: $scores,
                        myLabel: faceOff.sideALabel ?? (app.me.name.isEmpty ? "You" : app.me.name),
                        opponentLabel: faceOff.sideBLabel ?? faceOff.opponentName
                    )

                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.signal)
                            .frame(width: 34, height: 34)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Opponent confirmation")
                                .font(Theme.ui(12, weight: .bold))
                            Text("\(faceOff.opponentName) will verify the final scores before stats update.")
                                .font(Theme.ui(11))
                                .foregroundStyle(Theme.muted)
                            if faceOff.isRatingExempt {
                                Text("Casual game · rating unchanged")
                                    .font(Theme.ui(10, weight: .semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius))
                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius).stroke(Theme.hairline))
                }
                .padding(20)
            }
            .background(Theme.bg)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Submit for verification", enabled: hasWinner) {
                    app.submitScoreUpdate(faceOffId: faceOff.id, scores: scores)
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.bg)
            }
        }
        .preferredColorScheme(.light)
    }

    private var matchSummary: some View {
        HStack(spacing: 12) {
            if let opponent = app.player(faceOff.opponentId) {
                AvatarView(avatar: opponent.avatar, size: 48)
            } else {
                SportIcon(sport: faceOff.sport, size: 28)
                    .frame(width: 48, height: 48)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 13))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Vs. \(faceOff.opponentName)")
                    .font(Theme.ui(15, weight: .bold))
                Text("\(faceOff.sport.title) · \(faceOff.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(Theme.ui(11))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if faceOff.isRatingExempt {
                Text("CASUAL")
                    .font(Theme.ui(9, weight: .bold)).tracking(0.8)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(13)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius))
        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius).stroke(Theme.hairline))
    }
}

/// Balanced score entry shared by scheduled and just-played matches.
private struct GameScoreEditor: View {
    @Binding var scores: [GameScore]
    let myLabel: String
    let opponentLabel: String

    var body: some View {
        VStack(spacing: 12) {
            ForEach(scores.indices, id: \.self) { index in
                VStack(spacing: 14) {
                    HStack {
                        Text("Game \(index + 1)")
                            .font(Theme.ui(12, weight: .bold))
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        if scores.count > 1 {
                            Button { scores.remove(at: index) } label: {
                                Image(systemName: "trash").font(.system(size: 12, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.muted)
                            .accessibilityLabel("Remove game \(index + 1)")
                        }
                    }

                    HStack(alignment: .center, spacing: 10) {
                        scoreSide(label: myLabel, score: scoreBinding(index, mine: true))
                        Text("–")
                            .font(Theme.display(24))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 18)
                        scoreSide(label: opponentLabel, score: scoreBinding(index, mine: false))
                    }

                    if scores[index].myScore == scores[index].opponentScore {
                        Text("Scores cannot end in a tie")
                            .font(Theme.ui(10, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                    } else {
                        Text("\(scores[index].iWon ? myLabel : opponentLabel) won this game")
                            .font(Theme.ui(10, weight: .semibold))
                            .foregroundStyle(Theme.signal)
                    }
                }
                .padding(15)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius).stroke(Theme.hairline))
            }

            Button {
                guard scores.count < 7 else { return }
                scores.append(GameScore(myScore: 11, opponentScore: 9))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add another game")
                }
                .font(Theme.ui(13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius).stroke(Theme.hairline))
            }
            .buttonStyle(.plain)
            .disabled(scores.count >= 7)
        }
    }

    private func scoreSide(label: String, score: Binding<Int>) -> some View {
        VStack(spacing: 9) {
            Text(label)
                .font(Theme.ui(11, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            HStack(spacing: 8) {
                scoreButton("minus", enabled: score.wrappedValue > 0) { score.wrappedValue -= 1 }
                Text("\(score.wrappedValue)")
                    .font(Theme.display(29).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 38)
                scoreButton("plus", enabled: score.wrappedValue < 99) { score.wrappedValue += 1 }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(enabled ? Theme.ink : Theme.muted)
                .frame(width: 32, height: 32)
                .background(enabled ? Theme.surface2 : Theme.faint, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func scoreBinding(_ index: Int, mine: Bool) -> Binding<Int> {
        Binding(
            get: { mine ? scores[index].myScore : scores[index].opponentScore },
            set: { value in
                if mine { scores[index].myScore = value } else { scores[index].opponentScore = value }
            }
        )
    }
}

// MARK: - Face-off composer (make it official)

struct FaceOffComposerView: View {
    let player: Player
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date().addingTimeInterval(86400)
    @State private var venue = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Once you both agree, this goes on your calendar.",
                          systemImage: "calendar.badge.checkmark")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("When") {
                    RallyDateTimeSelector(label: "Date and time", selection: $date)
                }
                Section("Where") {
                    TextField("Venue / court", text: $venue)
                    if let court = player.profile(app.activeSport)?.homeCourt, !court.isEmpty {
                        Button("Use \(player.name)'s home court: \(court)") { venue = court }
                            .font(.caption)
                    }
                }
                Section("Agreed wager") {
                    Label(
                        app.agreedWager(with: [player.id]),
                        systemImage: app.agreedWager(with: [player.id]) == "No wager"
                            ? "hand.raised.slash"
                            : "checkmark.seal.fill"
                    )
                    Text("Wagers can only be proposed and accepted in chat.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .foregroundStyle(Theme.ink)
            .tint(Theme.grape)
            .navigationTitle("Make it Official")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CloseIconButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        app.scheduleFaceOff(with: player, date: date,
                                            venue: venue.isEmpty ? "TBD" : venue,
                                            wager: app.agreedWager(with: [player.id]))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(venue.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Report result (with live Elo preview)

struct ReportResultView: View {
    let faceOff: FaceOff
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var outcome: MatchOutcome = .iWon

    private var myRating: Int { app.currentRating }
    private var oppRating: Int { app.player(faceOff.opponentId)?.rating(app.activeSport) ?? 50 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Who won?") {
                    MinimalChoiceBar(
                        options: MatchOutcome.allCases.map(\.rawValue),
                        selection: Binding(
                            get: { outcome.rawValue },
                            set: { outcome = MatchOutcome(rawValue: $0) ?? .iWon }
                        )
                    )
                }

                Section("Rating preview") {
                    HStack {
                        Text("Your rating")
                        Spacer()
                        Text("\(myRating)").bold()
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        Text("\(EloRating.newRating(player: myRating, opponent: oppRating, didWin: outcome == .iWon))")
                            .bold().foregroundStyle(app.themeColor)
                        Text(EloRating.deltaString(player: myRating, opponent: oppRating, didWin: outcome == .iWon))
                            .font(.caption.bold())
                            .foregroundStyle(outcome == .iWon ? .green : .red)
                    }
                    Text(explanation).font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    Label("\(faceOff.opponentName) must confirm before ratings change.",
                          systemImage: "checkmark.seal")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .foregroundStyle(Theme.ink)
            .tint(Theme.grape)
            .navigationTitle("Report Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CloseIconButton { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        app.reportResult(faceOffId: faceOff.id, outcome: outcome)
                        dismiss()
                    }.fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var explanation: String {
        let diff = oppRating - myRating
        if outcome == .iWon {
            return diff > 8 ? "Big upset — beating a higher-rated player earns extra points."
                 : diff < -8 ? "Expected win — beating a lower-rated player earns only a little."
                 : "Even match — a solid, standard gain."
        } else {
            return diff < -8 ? "Costly loss — losing to a lower-rated player hurts more."
                 : "Losing to a stronger player costs fewer points."
        }
    }
}

// MARK: - Unscheduled game logging

private enum MatchFormat: String, CaseIterable, Identifiable {
    case singles = "Singles"
    case doubles = "Doubles"
    var id: String { rawValue }
}

private enum MatchMode: String, CaseIterable, Identifiable {
    case casual = "Casual"
    case rated = "Rated"
    var id: String { rawValue }
}

struct LogGameSheet: View {
    let onComplete: () -> Void
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var sport: Sport?
    @State private var format: MatchFormat = .singles
    @State private var mode: MatchMode = .casual
    @State private var query = ""
    @State private var selectedIds: [UUID] = []
    @State private var showUnratedWarning = false
    @State private var draftIsRatingExempt = true
    @State private var scores = [GameScore(myScore: 11, opponentScore: 9)]

    private var selectedSport: Sport { sport ?? app.activeSport }
    private var requiredPlayerCount: Int {
        selectedSport.category == .group ? 1 : (format == .doubles ? 3 : 1)
    }
    private var opponentIds: [UUID] {
        selectedSport.category == .individual && format == .doubles
            ? Array(selectedIds.dropFirst()) : selectedIds
    }
    private var candidates: [Player] {
        app.players.filter { player in
            !selectedIds.contains(player.id) &&
            (query.isEmpty || player.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Metrics.verticalRhythm) {
                    HStack {
                        if step > 0 {
                            Button { step -= 1 } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 38, height: 38)
                                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        CloseIconButton { dismiss() }
                            .font(Theme.ui(13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10))
                            .buttonStyle(.plain)
                    }

                    Text(title).font(Theme.heading(29))
                    if let subtitle { Text(subtitle).font(Theme.ui(13)).foregroundStyle(Theme.muted) }

                    switch step {
                    case 0: detailsStep
                    case 1: playersStep
                    default: scoreStep
                    }
                }
                .padding(DesignSystem.Metrics.screenPadding)
            }
            .background(Theme.bg)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: ctaTitle, enabled: canContinue) { advance() }
                    .padding(DesignSystem.Metrics.screenPadding)
                    .background(Theme.bg)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            sport = app.mySports.contains(app.activeSport) ? app.activeSport : app.mySports.first
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demo-log-players") { step = 1 }
            if ProcessInfo.processInfo.arguments.contains("-demo-log-scores"),
               let opponent = app.players.first(where: { $0.profile(selectedSport) != nil }) {
                selectedIds = [opponent.id]
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    createMatch(isRatingExempt: true)
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-demo-unrated-warning"),
               let unrated = app.players.first(where: { $0.profile(.badminton) == nil }) {
                sport = .badminton
                selectedIds = [unrated.id]
                step = 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showUnratedWarning = true }
            }
#endif
        }
        .sheet(isPresented: $showUnratedWarning) {
            UnratedInviteConfirmationSheet(name: opponentNames, sport: selectedSport) {
                createMatch(isRatingExempt: true)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.bg)
        }
    }

    private var title: String {
        ["game details", "add players", "enter scores"][min(step, 2)]
    }
    private var subtitle: String? {
        if step == 1 {
            if selectedSport.category == .group { return "Add an opponent from the game." }
            return format == .doubles ? "Partner first, then two opponents." : "Who did you play?"
        }
        if step == 2 { return "Add every final score, including deuce games." }
        return nil
    }
    private var ctaTitle: String {
        if step == 0 { return "Choose players" }
        if step == 1 { return "Enter scores" }
        return "Submit for verification"
    }
    private var canContinue: Bool {
        if step == 0 { return sport != nil }
        if step == 1 { return selectedIds.count == requiredPlayerCount }
        let myWins = scores.filter(\.iWon).count
        return scores.allSatisfy { $0.myScore != $0.opponentScore } && myWins != scores.count - myWins
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Sport").font(Theme.ui(12, weight: .bold)).foregroundStyle(Theme.muted)
                sportStep
            }

            if selectedSport.category == .individual {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Format").font(Theme.ui(12, weight: .bold)).foregroundStyle(Theme.muted)
                    MinimalChoiceBar(
                        options: MatchFormat.allCases.map(\.rawValue),
                        selection: Binding(get: { format.rawValue }, set: { format = MatchFormat(rawValue: $0) ?? .singles })
                    )
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Result").font(Theme.ui(12, weight: .bold)).foregroundStyle(Theme.muted)
                    MinimalChoiceBar(
                        options: MatchMode.allCases.map(\.rawValue),
                        selection: Binding(get: { mode.rawValue }, set: { mode = MatchMode(rawValue: $0) ?? .casual })
                    )
                    Text(mode == .rated ? "Counts toward both players' ratings." : "Saved to history without changing ratings.")
                        .font(Theme.ui(11))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private var sportStep: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(app.mySports) { item in
                SelectableCard(title: item.title, sport: item, isSelected: sport == item) {
                    sport = item
                    selectedIds.removeAll()
                }
            }
        }
    }

    private var playersStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !selectedIds.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedIds.enumerated()), id: \.element) { index, id in
                            if let player = app.player(id) {
                                Button {
                                    selectedIds.removeAll { $0 == id }
                                } label: {
                                    HStack(spacing: 6) {
                                        AvatarView(avatar: player.avatar, size: 28)
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(player.name).font(Theme.ui(10, weight: .bold))
                                            if format == .doubles {
                                                Text(index == 0 ? "Partner" : "Opponent")
                                                    .font(Theme.ui(8)).foregroundStyle(Theme.muted)
                                            }
                                        }
                                        Image(systemName: "xmark").font(.caption.bold())
                                    }
                                    .foregroundStyle(Theme.ink).padding(8)
                                    .background(Theme.surface, in: Capsule())
                                    .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
            }

            TextField("Search by username", text: $query)
                .font(Theme.ui(14)).padding(.horizontal, 14).frame(height: 48)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius).stroke(Theme.hairline))

            ForEach(candidates.prefix(8)) { player in
                HStack(spacing: 10) {
                    AvatarView(avatar: player.avatar, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name).font(Theme.ui(13, weight: .bold))
                        Text(player.profile(selectedSport)?.usesElo == true
                             ? "Elo \(player.rating(selectedSport))" : "Unrated in \(selectedSport.title)")
                            .font(Theme.ui(10)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if app.friendshipState(with: player.id) != .friends {
                        Button("Add friend") { app.sendFriendRequest(to: player.id) }
                            .font(Theme.ui(9, weight: .bold)).foregroundStyle(Theme.muted)
                    }
                    Button("Add") {
                        guard selectedIds.count < requiredPlayerCount else { return }
                        selectedIds.append(player.id)
                    }
                    .font(Theme.ui(10, weight: .bold)).foregroundStyle(Theme.bg)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(Theme.accent, in: Capsule())
                }
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius))
            }
        }
    }

    private var scoreStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ForEach(opponentIds, id: \.self) { id in
                    if let player = app.player(id) {
                        AvatarView(avatar: player.avatar, size: 38)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vs. \(opponentNames)").font(Theme.ui(14, weight: .bold))
                    Text("\(selectedSport.title) · \(mode.rawValue)")
                        .font(Theme.ui(10, weight: .semibold)).foregroundStyle(Theme.muted)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius))

            GameScoreEditor(
                scores: $scores,
                myLabel: app.me.name.isEmpty ? "You" : app.me.name,
                opponentLabel: opponentNames
            )

            Label("Your opponent verifies these scores before ratings update.", systemImage: "checkmark.shield")
                .font(Theme.ui(11, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
    }

    private var opponentNames: String {
        let names = opponentIds.compactMap { app.player($0)?.name }
        if names.count == 1 { return names[0] }
        return names.dropLast().joined(separator: ", ") + " and " + (names.last ?? "your opponents")
    }

    private func advance() {
        if step == 0 {
            step = 1
        } else if step == 1 && mode == .rated && app.isRatingExempt(opponentIds: opponentIds, sport: selectedSport) {
            showUnratedWarning = true
        } else if step == 1 {
            createMatch(isRatingExempt: mode == .casual)
        } else if let faceOff = app.createUnscheduledMatch(
            sport: selectedSport,
            participantIds: selectedIds,
            opponentIds: opponentIds,
            isRatingExempt: draftIsRatingExempt
        ) {
            app.submitScoreUpdate(faceOffId: faceOff.id, scores: scores)
            onComplete()
            dismiss()
        }
    }

    private func createMatch(isRatingExempt: Bool) {
        draftIsRatingExempt = isRatingExempt
        withAnimation(.easeInOut(duration: 0.18)) { step = 2 }
    }
}
