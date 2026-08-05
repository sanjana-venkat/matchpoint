import SwiftUI

/// Adds another sport using the same per-sport rating rules as initial onboarding.
struct AddSportView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var chosen: Sport?
    @State private var profile = SportProfile(sport: .badminton)

    private var remaining: [Sport] { Sport.allCases.filter { !app.mySports.contains($0) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    StepHeader(
                        title: chosen == nil ? "Pick a sport to add" : "Set up \(chosen!.title)",
                        subtitle: chosen == nil ? "You can have up to four sport profiles." : setupSubtitle
                    )

                    if chosen == nil { sportPicker } else { setup }
                }
                .padding(18)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: chosen == nil ? "Choose a sport" : "Add \(chosen!.title)", enabled: chosen != nil) {
                    if chosen != nil { finish() }
                }
                .padding(18)
                .background(Theme.bg)
            }
            .navigationTitle("Add a sport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(chosen == nil ? "Cancel" : "Back") {
                        if chosen == nil { dismiss() } else { chosen = nil }
                    }
                }
            }
            .sorbetScreen()
        }
    }

    private var setupSubtitle: String {
        guard let chosen else { return "" }
        return chosen.category == .individual
            ? "Choose Elo or a social skill label for this sport only."
            : "Team sports use verified peer feedback instead of Elo."
    }

    private var sportPicker: some View {
        VStack(alignment: .leading, spacing: 18) {
            sportGroup("Individual or dual", sports: remaining.filter { $0.category == .individual })
            sportGroup("Group sports", sports: remaining.filter { $0.category == .group })
        }
    }

    private func sportGroup(_ title: String, sports: [Sport]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(Theme.ui(10, weight: .bold)).tracking(1.2).foregroundStyle(Theme.muted)
            ForEach(sports) { sport in
                Button {
                    chosen = sport
                    profile = SportProfile(sport: sport)
                    profile.peerSkillRatings = sport.skillCategories.map {
                        PeerSkillRating(category: $0, average: 0, count: 0)
                    }
                } label: {
                    HStack(spacing: 12) {
                        SportIcon(sport: sport, size: 30)
                        Text(sport.title).font(Theme.ui(15, weight: .bold))
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(16)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline))
                }
            }
        }
    }

    @ViewBuilder private var setup: some View {
        if let chosen, chosen.category == .individual {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Starting rating").font(Theme.heading(17))
                        Text("Rated games change it by about 1–5 points")
                            .font(Theme.ui(11)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text("80").font(Theme.display(38)).foregroundStyle(Theme.accent)
                }
                .padding(17)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            }
            .onAppear { profile.ratingOptOut = false; profile.socialSkillLabel = nil }
        } else if let chosen {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(chosen.skillCategories, id: \.self) { category in
                    HStack {
                        Image(systemName: "star.bubble.fill").foregroundStyle(Theme.accent)
                        Text(category).font(Theme.heading(16))
                        Spacer()
                        Text("Not rated yet").font(Theme.ui(11)).foregroundStyle(Theme.muted)
                    }
                    .padding(17)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                }
                Text("Players you complete verified matches with can rate these skills on a five-star scale.")
                    .font(Theme.ui(12)).foregroundStyle(Theme.muted)
            }
        }
    }

    private func finish() {
        guard let chosen else { return }
        profile.rating = EloRating.start
        if chosen.category == .individual { profile.ratingOptOut = false; profile.socialSkillLabel = nil }
        app.addSport(chosen, profile: profile)
        app.activeSport = chosen
        dismiss()
    }
}
