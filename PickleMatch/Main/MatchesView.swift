import SwiftUI

/// A complete match ledger combining scheduled fixtures and user-uploaded scores.
struct MatchesView: View {
    @EnvironmentObject private var app: AppState
    @Binding var selectedMainTab: Int
    @State private var selectedSegment = "Past"
    @State private var selectedRecord: MatchRecord?
    @State private var selectedUpcoming: FaceOff?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    MinimalChoiceBar(options: ["Past", "Upcoming"], selection: $selectedSegment)

                    if selectedSegment == "Past" {
                        pastMatches
                    } else {
                        upcomingMatches
                    }
                }
                .padding(18)
                .padding(.bottom, 90)
            }
            .background(Theme.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SportModeToggle() }
            }
            .sorbetScreen()
            .sheet(item: $selectedRecord) { record in
                MatchRecordQuickView(record: record) {
                    selectedRecord = nil
                    selectedMainTab = 4
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
            }
            .sheet(item: $selectedUpcoming) { match in
                UpcomingMatchQuickView(match: match)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your matchbook").font(Theme.heading(27))
                Text("Scheduled in Matchpoint and uploaded after play.")
                    .font(Theme.ui(12)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Text("\(app.myMatches.count)")
                .font(Theme.display(34))
                .foregroundStyle(app.themeColor)
        }
    }

    @ViewBuilder private var pastMatches: some View {
        if app.myMatches.isEmpty {
            emptyState(
                icon: "square.and.arrow.up",
                title: "No past matches yet.",
                detail: "Use the white action button to upload singles or doubles scores after your next session."
            )
        } else {
            LazyVStack(spacing: 11) {
                ForEach(app.myMatches) { record in
                    Button { selectedRecord = record } label: {
                        HStack(spacing: 13) {
                            AvatarView(avatar: record.opponentAvatar, size: 50)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(record.opponentName).font(Theme.heading(16))
                                    Text(record.didWin ? "WIN" : "LOSS")
                                        .font(Theme.ui(8, weight: .bold)).tracking(1)
                                        .foregroundStyle(record.didWin ? Theme.signal : Theme.muted)
                                }
                                Text("\(record.date.formatted(date: .abbreviated, time: .omitted)) · \(record.venue)")
                                    .font(Theme.ui(10)).foregroundStyle(Theme.muted).lineLimit(1)
                                Label(record.source == .unscheduled ? "Uploaded score" : "Scheduled match",
                                      systemImage: record.source == .unscheduled ? "square.and.arrow.up" : "calendar")
                                    .font(Theme.ui(9, weight: .bold)).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(scoreline(record)).font(Theme.display(19))
                                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.muted)
                            }
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(SorbetScaleButtonStyle())
                }
            }
        }
    }

    @ViewBuilder private var upcomingMatches: some View {
        let matches = app.upcomingFaceOffs
        if matches.isEmpty {
            emptyState(icon: "calendar.badge.plus", title: "Nothing scheduled yet.",
                       detail: "Create a challenge and agree on a time to see it here.")
        } else {
            LazyVStack(spacing: 11) {
                ForEach(matches) { match in
                    Button { selectedUpcoming = match } label: {
                        HStack(spacing: 14) {
                            VStack(spacing: 0) {
                                Text(match.date.formatted(.dateTime.day())).font(Theme.display(28))
                                Text(match.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                                    .font(Theme.ui(9, weight: .bold)).foregroundStyle(Theme.muted)
                            }
                            .frame(width: 52, height: 58).background(Theme.faint, in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(match.opponentName).font(Theme.heading(16))
                                Text("\(match.date.formatted(date: .omitted, time: .shortened)) · \(match.venue)")
                                    .font(Theme.ui(10)).foregroundStyle(Theme.muted).lineLimit(1)
                                Text(match.wager).font(Theme.ui(10, weight: .bold)).foregroundStyle(Theme.signal)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                        }
                        .foregroundStyle(Theme.ink).padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(SorbetScaleButtonStyle())
                }
            }
        }
    }

    private func scoreline(_ record: MatchRecord) -> String {
        guard !record.gameScores.isEmpty else { return record.didWin ? "W" : "L" }
        let mine = record.gameScores.filter(\.iWon).count
        return "\(mine)–\(record.gameScores.count - mine)"
    }

    private func emptyState(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.signal)
            Text(title).font(Theme.heading(18))
            Text(detail).font(Theme.ui(12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 42).padding(.horizontal, 20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct MatchRecordQuickView: View {
    let record: MatchRecord
    let showStatistics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule().fill(Theme.hairline).frame(width: 42, height: 5).frame(maxWidth: .infinity)
            MatchPointLogo()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.didWin ? "Victory" : "Match complete").font(Theme.heading(28))
                    Text("Against \(record.opponentName)").font(Theme.ui(13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Text(record.didWin ? "W" : "L").font(Theme.display(42)).foregroundStyle(record.didWin ? Theme.signal : Theme.muted)
            }
            detail("Date", record.date.formatted(date: .long, time: .shortened))
            detail("Venue", record.venue)
            detail("Source", record.source == .unscheduled ? "Uploaded after play" : "Scheduled through Matchpoint")
            if !record.gameScores.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game results").font(Theme.ui(11, weight: .bold)).foregroundStyle(Theme.muted)
                    ForEach(Array(record.gameScores.enumerated()), id: \.element.id) { index, game in
                        Text("Game \(index + 1): \(game.myScore)–\(game.opponentScore) · \(game.iWon ? "Your team won" : "Opponent team won")")
                            .font(Theme.ui(13, weight: .bold))
                    }
                }
            }
            Button(action: showStatistics) {
                Label("View your full statistics breakdown", systemImage: "chart.xyaxis.line")
                    .font(Theme.ui(13, weight: .bold)).foregroundStyle(Theme.signal)
            }
            Spacer()
        }
        .padding(20).background(Theme.bg)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(Theme.muted); Spacer(); Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing) }
            .font(Theme.ui(12))
    }
}

private struct UpcomingMatchQuickView: View {
    let match: FaceOff
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            MatchPointLogo()
            Text("Upcoming match").font(Theme.heading(28))
            Label(match.opponentName, systemImage: "person.2.fill").font(Theme.heading(17))
            Label(match.date.formatted(date: .long, time: .shortened), systemImage: "calendar")
            Label(match.venue, systemImage: "mappin.and.ellipse")
            Label(match.wager, systemImage: "gift")
            Spacer()
        }
        .font(Theme.ui(13)).padding(20).background(Theme.bg)
    }
}
