import SwiftUI

/// Personalized discovery feed made from horizontally scrolling player shelves.
struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @State private var selectedPlayer: Player?
    @State private var activeFaceOff: FaceOff?
    @State private var chatConversationId: UUID?
    @State private var scoreFaceOff: FaceOff?

    private var availablePlayers: [Player] {
        app.players.filter { $0.profile(app.activeSport) != nil }
    }

    private var forYou: [Player] {
        availablePlayers.sorted {
            let ratingWeight = app.activeSport.category == .individual ? 2 : 0
            let lhs = abs($0.rating(app.activeSport) - app.currentRating) * ratingWeight + Int($0.distanceMiles)
            let rhs = abs($1.rating(app.activeSport) - app.currentRating) * ratingWeight + Int($1.distanceMiles)
            return lhs < rhs
        }
    }

    private var topScorers: [Player] {
        availablePlayers.sorted { $0.rating(app.activeSport) > $1.rating(app.activeSport) }
    }

    private var mostPlayed: [Player] {
        availablePlayers.sorted {
            mockGameCount(for: $0) > mockGameCount(for: $1)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 28) {
                    hero
                    if let faceOff = app.scoreUpdatesNeeded.first {
                        scoreUpdateCard(faceOff)
                    }
                    if !app.upcomingFaceOffs.isEmpty {
                        upcomingMatches
                    }
                    playerShelf(
                        title: "For you",
                        players: forYou,
                        color: Theme.pink,
                        style: .featured
                    )

                    topScorersLeaderboard

                    playerShelf(
                        title: "Most frequently played",
                        players: mostPlayed,
                        color: Theme.grape,
                        style: .compact,
                        showsGameCount: true
                    )
                }
                .padding(.vertical, 16)
                .padding(.bottom, 14)
            }
            .background(Theme.canvas)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SportModeToggle() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sorbetScreen()
            .sheet(item: $selectedPlayer) { player in
                PlayerQuickSheet(player: player) {
                    app.like(player)
                    selectedPlayer = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        chatConversationId = app.conversation(with: player.id)?.id
                    }
                }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { chatConversationId != nil },
                    set: { if !$0 { chatConversationId = nil } }
                )
            ) {
                if let chatConversationId {
                    ChatView(conversationId: chatConversationId)
                }
            }
            .fullScreenCover(item: $activeFaceOff) { faceOff in
                LiveMatchView(faceOff: faceOff)
                    .presentationBackground(.black)
            }
            .sheet(item: $scoreFaceOff) { faceOff in
                ScoreUpdateSheet(faceOff: faceOff)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
            }
            .onAppear {
#if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-demo-live-match"),
                   activeFaceOff == nil {
                    activeFaceOff = app.upcomingFaceOffs.first
                }
                if ProcessInfo.processInfo.arguments.contains("-demo-player-sheet"),
                   selectedPlayer == nil {
                    selectedPlayer = forYou.first
                }
                if ProcessInfo.processInfo.arguments.contains("-demo-score-update"),
                   scoreFaceOff == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        scoreFaceOff = app.scoreUpdatesNeeded.first
                    }
                }
#endif
            }
        }
    }

    private func scoreUpdateCard(_ faceOff: FaceOff) -> some View {
        Button { scoreFaceOff = faceOff } label: {
            HStack(spacing: 13) {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 48, height: 48)
                    .background(app.themeColor, in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Update score with \(faceOff.opponentName)")
                        .font(Theme.heading(16))
                    Text("\(faceOff.date.formatted(date: .abbreviated, time: .shortened)) · \(faceOff.venue)")
                        .font(Theme.ui(10))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(Theme.ink)
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.signal, lineWidth: 1))
        }
        .buttonStyle(SorbetScaleButtonStyle())
        .padding(.horizontal, 18)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ready, \(firstName).")
                .font(Theme.heading(27))
                .tracking(-0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
    }

    private var firstName: String {
        app.me.name.split(separator: " ").first.map(String.init) ?? "player"
    }

    private var quickMatchHub: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )

                TrackMapTexture()
                    .opacity(0.14)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Text("QUICK MATCH")
                            .font(Theme.ui(10, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Theme.bg)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(app.themeColor, in: Capsule())

                        Spacer()

                        ratingSummary
                    }

                    Spacer()

                    Text("Find your next\nrival nearby.")
                        .font(Theme.heading(30))
                        .tracking(-0.8)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(-1)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(app.activeSport.category == .individual
                         ? "Matched by sport, distance, and rating."
                         : "Matched by sport, distance, and availability.")
                        .font(Theme.ui(12))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 5)

                    Button {
                        selectedPlayer = forYou.first
                    } label: {
                        HStack {
                            Text("Explore nearby")
                                .font(Theme.ui(14, weight: .bold))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(Theme.bg)
                        .padding(.horizontal, 18)
                        .frame(height: 50)
                        .background(app.themeColor, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(SorbetScaleButtonStyle())
                    .padding(.top, 18)
                }
                .padding(20)
            }
            .frame(height: 286)

            HStack(spacing: 0) {
                metric("flame.fill", "\(max(1, app.wins % 7))-day streak")
                Divider().frame(height: 26)
                metric("trophy.fill", "\(app.wins) wins")
                Divider().frame(height: 26)
                metric("bolt.fill", "\(Int(app.winPct))% win rate")
            }
            .padding(.vertical, 13)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder private var ratingSummary: some View {
        if let profile = app.me.profile(app.activeSport), profile.usesElo {
            VStack(alignment: .trailing, spacing: -2) {
                Text("\(profile.rating)")
                    .font(Theme.display(42).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                Text("ELO RATING")
                    .font(Theme.ui(8, weight: .bold)).tracking(1).foregroundStyle(Theme.muted)
            }
        } else if app.activeSport.category == .group {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                    Text("PEER RATED")
                }
                .font(Theme.ui(10, weight: .bold)).foregroundStyle(app.themeColor)
                Text("3 verified skills").font(Theme.ui(9)).foregroundStyle(Theme.muted)
            }
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                Text(app.me.profile(app.activeSport)?.socialSkillLabel?.rawValue ?? "Social play")
                    .font(Theme.ui(12, weight: .bold)).foregroundStyle(app.themeColor)
                Text("NO ELO").font(Theme.ui(8, weight: .bold)).tracking(1).foregroundStyle(Theme.muted)
            }
        }
    }

    private var upcomingMatches: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(Theme.heading(21))

            ForEach(app.upcomingFaceOffs.prefix(2)) { match in
                HStack(spacing: 13) {
                    VStack(spacing: 2) {
                        Text(match.date.formatted(.dateTime.day()))
                            .font(Theme.display(30).monospacedDigit())
                        Text(match.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                            .font(Theme.ui(9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(width: 54, height: 64)
                    .background(Theme.faint, in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(match.opponentName)
                            .font(Theme.heading(16))
                        Text("\(match.date.formatted(date: .omitted, time: .shortened)) · \(match.venue)")
                            .font(Theme.ui(10))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                        Text(match.wager)
                            .font(Theme.ui(10, weight: .bold))
                            .foregroundStyle(Theme.pink)
                    }

                    Spacer(minLength: 4)

                    if canStart(match) {
                        Button {
                            activeFaceOff = match
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "play.fill")
                                Text("Start")
                                    .font(Theme.ui(9, weight: .bold))
                            }
                            .foregroundStyle(Theme.bg)
                            .frame(width: 58, height: 58)
                            .background(app.themeColor, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(SorbetScaleButtonStyle())
                        .accessibilityLabel("Start game with \(match.opponentName)")
                    } else {
                        VStack(spacing: 3) {
                            Image(systemName: "clock")
                            Text(relativeStart(match.date))
                                .font(Theme.ui(8, weight: .bold))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(Theme.ink.opacity(0.78))
                        .frame(width: 64, height: 58)
                        .background(Theme.faint, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Match starts \(match.date.formatted(date: .complete, time: .shortened))")
                    }
                }
                .padding(13)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.hairline, lineWidth: 1))
            }
        }
        .padding(.horizontal, 18)
    }

    private func canStart(_ match: FaceOff) -> Bool {
        let interval = match.date.timeIntervalSinceNow
        return interval <= 60 * 60 && interval >= -6 * 60 * 60
    }

    private func relativeStart(_ date: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        if days == 0 { return date.formatted(date: .omitted, time: .shortened) }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }

    private func metric(_ icon: String, _ title: String) -> some View {
        Label(title, systemImage: icon)
            .font(Theme.ui(10, weight: .bold))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
    }

    private func playerShelf(
        title: String,
        players: [Player],
        color: Color,
        style: HomePlayerCard.Style,
        showsGameCount: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(Theme.heading(19))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 15) {
                    ForEach(Array(players.prefix(8).enumerated()), id: \.element.id) { index, player in
                        Button { selectedPlayer = player } label: {
                            HomePlayerCard(
                                player: player,
                                sport: app.activeSport,
                                accent: color,
                                style: style,
                                badge: showsGameCount ? "\(mockGameCount(for: player)) games" : nil,
                                contextLine: showsGameCount ? playFrequency(for: player) : player.bio
                            )
                        }
                        .buttonStyle(SorbetScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
            }
        }
    }

    private var topScorersLeaderboard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Top scorers this week")
                .font(Theme.heading(19))
                .foregroundStyle(Theme.ink)

            VStack(spacing: 0) {
                ForEach(Array(topScorers.prefix(5).enumerated()), id: \.element.id) { index, player in
                    Button { selectedPlayer = player } label: {
                        HStack(spacing: 13) {
                            Text("\(index + 1)")
                                .font(Theme.display(index < 3 ? 18 : 15).monospacedDigit())
                                .foregroundStyle(index < 3 ? Theme.ink : Theme.muted)
                                .frame(width: 22)

                            AvatarView(avatar: player.avatar, size: 42)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(player.name)
                                    .font(Theme.ui(14, weight: .bold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Text("\(player.distanceMiles, specifier: "%.1f") mi · \(player.city)")
                                    .font(Theme.ui(10))
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 6)

                            RatingTrendIcon()
                                .stroke(Theme.signal, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                                .frame(width: 28, height: 20)

                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(player.rating(app.activeSport))")
                                    .font(Theme.display(17).monospacedDigit())
                                    .foregroundStyle(Theme.ink)
                                Text("+\(weeklyGain(for: player))")
                                    .font(Theme.ui(9, weight: .bold))
                                    .foregroundStyle(Theme.signal)
                            }
                            .frame(width: 34, alignment: .trailing)
                        }
                        .padding(.vertical, 15)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < min(topScorers.count, 5) - 1 {
                        Divider().overlay(Theme.hairline).padding(.leading, 80)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner).stroke(Theme.hairline, lineWidth: 1))
        }
        .padding(.horizontal, 18)
    }

    private func weeklyGain(for player: Player) -> Int {
        2 + player.name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 5
    }

    private func mockGameCount(for player: Player) -> Int {
        let seed = player.name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return 4 + (seed % 18)
    }

    private func playFrequency(for player: Player) -> String {
        let seed = player.name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let cadence = ["Plays weekly", "Plays 2–3× a week", "Plays most weekends"][seed % 3]
        return "\(cadence) · Last played \(1 + seed % 6)d ago"
    }
}

struct HomePlayerCard: View {
    enum Style { case featured, compact }

    let player: Player
    let sport: Sport
    let accent: Color
    let style: Style
    var badge: String?
    var contextLine: String?

    private var width: CGFloat { style == .featured ? 244 : 190 }
    private var imageSize: CGFloat { style == .featured ? 78 : 62 }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                AvatarView(avatar: player.avatar, size: imageSize)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(Theme.ui(10, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 9)
                        .frame(height: 30)
                        .background(Theme.faint, in: RoundedRectangle(cornerRadius: 10))
                } else if player.profile(sport) != nil, sport.category == .group {
                    Label("Peer rated", systemImage: "star.fill")
                        .font(Theme.ui(9, weight: .bold))
                        .foregroundStyle(Theme.color(for: sport))
                        .padding(8)
                        .background(Theme.color(for: sport).opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                } else if player.profile(sport)?.usesElo == false {
                    Text(player.profile(sport)?.socialSkillLabel?.rawValue ?? "Social play")
                        .font(Theme.ui(9, weight: .bold))
                        .foregroundStyle(Theme.color(for: sport))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(Theme.heading(style == .featured ? 19 : 16))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(player.distanceMiles, specifier: "%.1f") mi · \(player.city)")
                    .font(Theme.ui(11, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)

                if let profile = player.profile(sport), profile.usesElo {
                    Text("\(player.rating(sport)) rating · \(EloRating.tier(for: player.rating(sport)))")
                        .font(Theme.ui(10, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
            }

            if let contextLine {
                Text(contextLine)
                    .font(Theme.ui(11))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(style == .featured ? 2 : 1)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(width: width, height: style == .featured ? 216 : 176, alignment: .topLeading)
        .card(padding: 14)
    }
}

private struct RatingTrendIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 1, y: rect.maxY - 2))
        path.addLine(to: CGPoint(x: rect.width * 0.34, y: rect.maxY - 2))
        path.addLine(to: CGPoint(x: rect.width * 0.34, y: rect.height * 0.58))
        path.addLine(to: CGPoint(x: rect.width * 0.66, y: rect.height * 0.58))
        path.addLine(to: CGPoint(x: rect.width * 0.66, y: rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.height * 0.24))
        path.move(to: CGPoint(x: rect.maxX - 7, y: rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.maxX - 7, y: rect.height * 0.42))
        return path
    }
}

private struct TrackMapTexture: View {
    var body: some View {
        Canvas { context, size in
            let paths: [[CGPoint]] = [
                [CGPoint(x: -20, y: 42), CGPoint(x: size.width * 0.48, y: 18), CGPoint(x: size.width + 20, y: 54)],
                [CGPoint(x: -20, y: 118), CGPoint(x: size.width * 0.36, y: 94), CGPoint(x: size.width + 20, y: 135)],
                [CGPoint(x: size.width * 0.20, y: -10), CGPoint(x: size.width * 0.25, y: size.height + 10)],
                [CGPoint(x: size.width * 0.67, y: -10), CGPoint(x: size.width * 0.61, y: size.height + 10)]
            ]
            for points in paths {
                var path = Path()
                path.move(to: points[0])
                for point in points.dropFirst() { path.addLine(to: point) }
                context.stroke(path, with: .color(Theme.hairline), lineWidth: 7)
            }
        }
        .opacity(0.65)
    }
}

/// Shared half-sheet profile used by Home and Map.
struct PlayerQuickSheet: View {
    let player: Player
    let onMessage: () -> Void
    @EnvironmentObject private var app: AppState
    @State private var showChallenge = false
    @State private var showPeerRating = false

    private var profile: SportProfile? { player.profile(app.activeSport) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 17) {
                    HStack(alignment: .top, spacing: 14) {
                        AvatarView(avatar: player.avatar, size: 78)

                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(player.name)
                                    .font(Theme.heading(23))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)

                                Text("\(player.age)")
                                    .font(Theme.ui(13, weight: .bold))
                                    .foregroundStyle(Theme.muted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.faint, in: Capsule())
                            }

                            Label(
                                "\(player.distanceMiles, specifier: "%.1f") mi away · \(player.city)",
                                systemImage: "location.fill"
                            )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)

                            if profile?.usesElo == true {
                                RatingBadge(
                                    rating: player.rating(app.activeSport),
                                    sport: app.activeSport,
                                    showTier: true
                                )
                            } else if app.activeSport.category == .group {
                                Label("Peer-rated profile", systemImage: "star.fill")
                                    .font(Theme.ui(11, weight: .bold))
                                    .foregroundStyle(app.themeColor)
                            } else {
                                Text(profile?.socialSkillLabel?.rawValue ?? "Social play")
                                    .font(Theme.ui(11, weight: .bold))
                                    .foregroundStyle(app.themeColor)
                            }
                        }
                    }

                    if let profile {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                Tag(
                                    text: profile.partnerStatus.short,
                                    systemImage: profile.partnerStatus.systemImage,
                                    color: Theme.blue
                                )
                                Tag(
                                    text: profile.selfAssessment.rawValue,
                                    systemImage: "bolt.fill",
                                    color: Theme.pink
                                )
                                if profile.ownsEquipment {
                                    Tag(text: "Has gear", systemImage: "bag.fill", color: Theme.lime)
                                }
                            }
                        }
                    }

                    Text(player.bio)
                        .font(Theme.ui(14))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    friendshipControl

                    if app.activeSport.category == .group {
                        actionButton("Rate verified skills", icon: "star.bubble.fill", primary: false) {
                            showPeerRating = true
                        }
                    }

                    VStack(spacing: 10) {
                        actionButton("Challenge", icon: "flag.checkered", primary: true) {
                            app.like(player)
                            showChallenge = true
                        }
                        actionButton("Message", icon: "bubble.left", primary: false) {
                            onMessage()
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.bg)
            .sheet(isPresented: $showChallenge) {
                ChallengeComposerView(player: player)
            }
            .sheet(isPresented: $showPeerRating) {
                PeerRatingSheet(player: player, sport: app.activeSport)
            }
        }
    }

    @ViewBuilder private var friendshipControl: some View {
        switch app.friendshipState(with: player.id) {
        case .none:
            actionButton("Send friend request", icon: "person.badge.plus", primary: false) {
                app.sendFriendRequest(to: player.id)
            }
        case .outgoing:
            Label("Friend request sent", systemImage: "clock.fill")
                .font(Theme.ui(13, weight: .bold))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        case .incoming:
            HStack(spacing: 10) {
                actionButton("Accept", icon: "checkmark", primary: true) { app.acceptFriendRequest(from: player.id) }
                actionButton("Decline", icon: "xmark", primary: false) { app.declineFriendRequest(from: player.id) }
            }
        case .friends:
            Label("Friends", systemImage: "person.2.fill")
                .font(Theme.ui(13, weight: .bold))
                .foregroundStyle(app.themeColor)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(app.themeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func actionButton(
        _ title: String,
        icon: String,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Theme.ui(14, weight: .bold))
                .foregroundStyle(primary ? Theme.bg : Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(primary ? app.themeColor : Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(primary ? app.themeColor : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(SorbetScaleButtonStyle())
    }
}

struct PeerRatingSheet: View {
    let player: Player
    let sport: Sport
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: Int] = [:]
    @State private var writtenReview = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    Text("Peer feedback is attached to verified \(sport.title.lowercased()) games and shown as a Google-style average plus reviewer count.")
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.muted)

                    ForEach(sport.skillCategories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category).font(Theme.heading(16))
                            HStack(spacing: 7) {
                                ForEach(1...5, id: \.self) { value in
                                    Button {
                                        values[category] = value
                                    } label: {
                                        Image(systemName: value <= (values[category] ?? 0) ? "star.fill" : "star")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundStyle(app.themeColor)
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Written review (optional)").font(Theme.heading(16))
                            Spacer()
                            Text("\(writtenReview.count)/500")
                                .font(Theme.ui(11))
                                .foregroundStyle(Theme.muted)
                        }
                        TextEditor(text: $writtenReview)
                            .font(Theme.ui(14))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 112)
                            .padding(10)
                            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.hairline, lineWidth: 1.2)
                            )
                            .onChange(of: writtenReview) { _, value in
                                if value.count > 500 { writtenReview = String(value.prefix(500)) }
                            }
                        Text("Share useful, respectful context about what they were like to play with.")
                            .font(Theme.ui(11))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(16)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))

                    Button {
                        app.submitPeerRatings(
                            playerId: player.id,
                            sport: sport,
                            values: values,
                            writtenReview: writtenReview
                        )
                        dismiss()
                    } label: {
                        Text("Submit peer ratings")
                            .font(Theme.ui(15, weight: .bold))
                            .foregroundStyle(values.count == sport.skillCategories.count ? Theme.bg : Theme.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(values.count == sport.skillCategories.count ? app.themeColor : Theme.faint, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(values.count != sport.skillCategories.count)
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Rate \(player.name.split(separator: " ").first.map(String.init) ?? player.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
        }
        .preferredColorScheme(.light)
    }
}
