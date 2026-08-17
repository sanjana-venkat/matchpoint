import SwiftUI
import Charts

/// The user's own profile: identity, per-sport rating & answers, sport mode
/// switching, and adding another sport.
struct ProfileView: View {
    @EnvironmentObject var app: AppState
    @State private var showAddSport = false
    @State private var showAvatarPicker = false
    @State private var showAvailability = false

    private var me: Player { app.me }
    private var profile: SportProfile? { app.myProfile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileSportTabs
                    identityCard
                    availabilityCard
                    ratingCard
                    if profile?.usesElo == true { performanceCard }
                    recentMatchesCard
                    answersCard
                    addSportButton
                }
                .padding()
            }
            .background(Theme.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SportModeToggle() }
                ToolbarItem(placement: .principal) { Text("Profile").font(Theme.heading(17)) }
            }
            .sorbetScreen()
            .sheet(isPresented: $showAddSport) { AddSportView() }
            .sheet(isPresented: $showAvatarPicker) {
                CharacterPickerSheet(selection: $app.me.avatar)
                    .presentationDetents([.height(250)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
            }
            .sheet(isPresented: $showAvailability) {
                ProfileAvailabilitySheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
            }
        }
    }

    private var profileSportTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(app.mySports) { sport in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { app.activeSport = sport }
                    } label: {
                        HStack(spacing: 6) {
                            SportIcon(
                                sport: sport,
                                size: 22,
                                isSelected: app.activeSport == sport,
                                color: app.activeSport == sport ? Theme.bg : Theme.ink
                            )
                            Text(sport.title).font(Theme.ui(12, weight: .bold))
                        }
                            .foregroundStyle(app.activeSport == sport ? Theme.bg : Theme.ink)
                            .padding(.horizontal, 13)
                            .frame(height: 42)
                            .background(
                                app.activeSport == sport ? Theme.color(for: sport) : Theme.surface,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(app.activeSport == sport ? Theme.color(for: sport) : Theme.hairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(SorbetScaleButtonStyle())
                }
            }
        }
    }

    private var availabilityCard: some View {
        Button {
            showAvailability = true
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 48, height: 48)
                    .background(app.themeColor, in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your availability")
                        .font(Theme.heading(16))
                    if let next = me.availability.filter({ $0.endDate > .now }).sorted(by: { $0.startDate < $1.startDate }).first {
                        Text("Next: \(next.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · \(next.period.hours)")
                            .font(Theme.ui(11))
                            .foregroundStyle(Theme.muted)
                    } else {
                        Text("Add times to unlock schedule matching")
                            .font(Theme.ui(11))
                            .foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                Text("\(me.availability.count)")
                    .font(Theme.display(24))
                    .foregroundStyle(app.themeColor)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .card(padding: 14)
        }
        .buttonStyle(SorbetScaleButtonStyle())
    }

    private var identityCard: some View {
        VStack(spacing: 10) {
            Button { showAvatarPicker = true } label: {
                AvatarView(avatar: me.avatar, size: 96)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.bg)
                            .frame(width: 28, height: 28)
                            .background(app.themeColor, in: Circle())
                            .overlay(Circle().stroke(Theme.surface, lineWidth: 3))
                    }
            }
            .buttonStyle(SorbetScaleButtonStyle())
            .accessibilityLabel("Change character")
            Text(me.name.isEmpty ? "You" : me.name)
                .font(Theme.heading(25))
                .foregroundStyle(Theme.ink)
            if !me.username.isEmpty {
                Text("@\(me.username)").font(Theme.ui(12, weight: .bold)).foregroundStyle(Theme.signal)
            }
            Text("\(me.age) · \(me.gender.rawValue) · \(me.city)")
                .font(Theme.ui(15)).foregroundStyle(Theme.muted)
            Text("\(app.displayedFriendCount) friends")
                .font(Theme.ui(12, weight: .bold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var sportSwitcher: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App mode")
                .font(Theme.heading(17))
            SportModeToggle()
            Text("Switch between your sports. Each has its own rating and matches.")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @ViewBuilder private var ratingCard: some View {
        if let profile, app.activeSport.category == .group {
            VStack(alignment: .leading, spacing: 13) {
                Text("Peer-rated skills")
                    .font(Theme.heading(18))
                ForEach(profile.peerSkillRatings) { skill in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(skill.category).font(Theme.ui(14, weight: .bold))
                            Text("\(skill.count) rating\(skill.count == 1 ? "" : "s")")
                                .font(Theme.ui(10))
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Image(systemName: "star.fill").foregroundStyle(app.themeColor)
                        Text(skill.count == 0 ? "— / 5.0" : String(format: "%.1f / 5.0", skill.average))
                            .font(Theme.ui(14, weight: .bold).monospacedDigit())
                    }
                    .padding(13)
                    .background(Theme.faint, in: RoundedRectangle(cornerRadius: 15))
                }
                Text("Only players with a verified game can submit a skill rating.")
                    .font(Theme.ui(11))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        } else if let profile, profile.ratingOptOut {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(app.activeSport.title) play style").font(Theme.ui(12)).foregroundStyle(Theme.muted)
                Text(profile.socialSkillLabel?.rawValue ?? "Social play")
                    .font(Theme.heading(27))
                    .foregroundStyle(app.themeColor)
                Label("Rating system opted out", systemImage: "eye.slash.fill")
                    .font(Theme.ui(11, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        } else {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(app.activeSport.title) rating").font(.subheadline).foregroundStyle(Theme.muted)
                Text("\(app.currentRating)")
                    .font(Theme.display(52))
                    .foregroundStyle(app.themeColor)
                Text(EloRating.tier(for: app.currentRating))
                    .font(.caption.bold()).foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                statLine("\(app.wins) wins", icon: "trophy.fill", color: Theme.grape)
                statLine("\(app.losses) losses", icon: "xmark", color: Theme.pink)
                statLine("\(Int(app.winPct))% win rate", icon: "percent", color: Theme.ink)
            }
            .font(.caption.weight(.semibold))
        }
        .card()
        }
    }

    private func statLine(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .frame(width: 14)
            Text(text)
                .lineLimit(1)
        }
        .font(Theme.ui(12, weight: .bold))
        .foregroundStyle(color)
    }

    private var answersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your \(app.activeSport.title) profile")
                .font(Theme.heading(17))
            if let profile {
                row("Partner status", profile.partnerStatus.rawValue, profile.partnerStatus.systemImage)
                row("Home court", profile.homeCourt.isEmpty ? "Not set" : profile.homeCourt, "mappin.circle")
                row("Equipment", profile.ownsEquipment ? "Has own gear" : "Needs gear", "bag")
                row("Tournaments", profile.playedTournaments ? "Yes" : "No", "trophy")
                row("Self-assessment", profile.selfAssessment.rawValue, "figure.mind.and.body")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var performanceCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rating journey")
                        .font(Theme.heading(18))
                    Text("\(app.wins) wins · \(app.losses) losses · \(Int(app.winPct))% win rate")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Tag(text: "STATS", systemImage: "chart.xyaxis.line", color: Theme.blue)
            }

            if app.ratingHistory.count >= 2 {
                Chart(app.ratingHistory) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Rating", point.rating)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.grape.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Rating", point.rating)
                    )
                    .foregroundStyle(Theme.grape)
                    .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .frame(height: 155)
            } else {
                Text("Play a few matches and your rating story will show up here.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var recentMatchesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent matches")
                    .font(Theme.heading(18))
                Spacer()
                Text("\(app.myMatches.count) total")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.muted)
            }

            if app.myMatches.isEmpty {
                Text("No results yet—go challenge somebody.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(app.myMatches.prefix(4)) { record in
                    ProfileMatchRow(record: record)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func row(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    @ViewBuilder private var addSportButton: some View {
        let remaining = Sport.allCases.filter { !app.mySports.contains($0) }
        if !remaining.isEmpty && app.mySports.count < 4 {
            PrimaryButton(title: "Add another sport", systemImage: "plus") {
                showAddSport = true
            }
        }
    }
}

private struct CharacterPickerSheet: View {
    @Binding var selection: Avatar
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose your character")
                        .font(Theme.heading(21))
                    Text("No photo needed. Change it anytime.")
                        .font(Theme.ui(12))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .font(Theme.ui(13, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            AvatarChoiceStrip(selection: $selection, size: 72)
        }
        .padding(20)
        .foregroundStyle(Theme.ink)
    }
}

private struct ProfileMatchRow: View {
    let record: MatchRecord

    var body: some View {
        HStack(spacing: 11) {
            AvatarView(avatar: record.opponentAvatar, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.opponentName)
                    .font(Theme.ui(14, weight: .bold))
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(record.didWin ? "W" : "L")
                .font(Theme.display(13))
                .foregroundStyle(Theme.ink)
                .frame(width: 28, height: 28)
                .background(record.didWin ? Theme.faint : Theme.accent.opacity(0.16), in: Circle())
                .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
            Text(record.ratingDelta >= 0 ? "+\(record.ratingDelta)" : "\(record.ratingDelta)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(record.ratingDelta >= 0 ? Theme.grape : Theme.pink)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }
}
