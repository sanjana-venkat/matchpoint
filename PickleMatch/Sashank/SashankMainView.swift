import SwiftUI
import MapKit
import Charts

/// A native, screen-for-screen translation of Sashank's 8/17 React prototype.
/// This view intentionally owns its shell instead of inheriting the older app UI.
struct SashankMainView: View {
    @EnvironmentObject private var app: AppState
    @State private var tab: Tab = .home
    @State private var fabOpen = false
    @State private var showNotifications = false
    @State private var showScore = false
    @State private var showChallenge = false
    @State private var showSports = false
    @State private var showPeerReview = false
    @State private var showFixture = false
    @State private var pendingSport: Sport?
    @State private var showExitWarning = false

    enum Tab: String {
        case map = "Map"
        case matches = "Matches"
        case home = "Home"
        case chats = "Chats"
        case profile = "Profile"
    }

    private var title: String {
        if tab == .matches, app.activeSport.category == .group { return "Calendar" }
        return tab.rawValue
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MP.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if tab == .map {
                    tabContent
                        .overlay(alignment: .top) { appBar }
                } else {
                    appBar
                    tabContent
                }
            }

            nativeNav
            fab

            if showSports {
                Color.black.opacity(0.12).ignoresSafeArea().onTapGesture { showSports = false }
                sportDropdown
            }
        }
        .foregroundStyle(MP.ink)
        .preferredColorScheme(.light)
        .onAppear {
#if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-demo-calendar") {
                app.activeSport = .cricket
                tab = .matches
            }
            if args.contains("-demo-profile") { tab = .profile }
            if args.contains("-demo-map") { tab = .map }
            if args.contains("-demo-matches") { tab = .matches }
            if args.contains("-demo-chats") { tab = .chats }
            if args.contains("-demo-home") { tab = .home }
#endif
        }
        .sheet(isPresented: $showNotifications) { NativeNotificationsSheet() }
        .sheet(isPresented: $showScore) {
            LogGameSheet { showScore = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showChallenge) {
            QuickChallengeSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPeerReview) { PeerReviewLauncher() }
        .sheet(isPresented: $showFixture) { GroupFixtureSheet() }
        .alert("Discard unsaved changes?", isPresented: $showExitWarning) {
            Button("Keep editing", role: .cancel) { pendingSport = nil }
            Button("Discard and switch", role: .destructive) {
                app.hasUnsavedDraft = false
                if let pendingSport { app.activeSport = pendingSport }
                pendingSport = nil
            }
        } message: {
            Text("Your unfinished challenge, score upload, or form changes will be lost if you switch sports.")
        }
    }

    @ViewBuilder private var tabContent: some View {
        Group {
            switch tab {
            case .map: NativeMapScreen()
            case .matches:
                if app.activeSport.category == .group { NativeCalendarScreen() }
                else { NativeMatchesScreen(openProfile: { tab = .profile }) }
            case .home: NativeHomeScreen(openTab: { tab = $0 }, switchSport: requestSportChange)
            case .chats: NativeChatsScreen()
            case .profile: NativeProfileScreen()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appBar: some View {
        HStack(spacing: 10) {
            if tab == .home {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill").font(.system(size: 12, weight: .bold))
                    Text(app.me.city.isEmpty ? "Austin" : app.me.city).font(RallyType.caption)
                }
                .padding(.horizontal, 13)
                .frame(minHeight: 48)
                .overlay(Capsule().stroke(MP.line, lineWidth: 1.5))
            } else {
                Button { withAnimation(.easeOut(duration: 0.16)) { showSports.toggle() } } label: {
                    HStack(spacing: 6) {
                        MPAssetSportIcon(sport: app.activeSport, size: 30)
                        Text(app.activeSport.title)
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(MP.ink3)
                    }
                    .padding(.horizontal, 13)
                    .frame(minHeight: 48)
                    .background(RallyPalette.cream.opacity(0.96), in: Capsule())
                    .overlay(Capsule().stroke(MP.line, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Switch sport. Current sport: \(app.activeSport.title)")
                .accessibilityHint("Shows your available sports")
            }

            Spacer()

            Button { showNotifications = true } label: {
                if tab == .map {
                    Image(systemName: "bell")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(MP.ink)
                        .frame(width: 48, height: 48)
                        .background(RallyPalette.cream, in: Circle())
                        .overlay(Circle().stroke(MP.line, lineWidth: 1.5))
                        .overlay(alignment: .topTrailing) {
                            Text("4")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(MP.ink)
                                .frame(width: 22, height: 22)
                                .background(MP.orange, in: Circle())
                                .offset(x: 4, y: -4)
                        }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "bell")
                            .font(.system(size: 19, weight: .semibold))
                        Text("4")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(MP.black)
                            .frame(width: 21, height: 21)
                            .background(MP.accent(app.activeSport), in: Circle())
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .overlay(Capsule().stroke(MP.line, lineWidth: 1.5))
                }
            }
            .buttonStyle(RallyPressStyle())
            .accessibilityLabel("Notifications, 4 unread")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var sportDropdown: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("YOUR SPORTS").font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(MP.ink3).padding(.horizontal, 11).padding(.vertical, 7)
            ForEach(app.mySports) { sport in
                Button {
                    requestSportChange(sport)
                    showSports = false
                } label: {
                    HStack(spacing: 11) {
                        MPAssetSportIcon(sport: sport, size: 30)
                        Text(sport.title).font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(sport.category == .individual ? "\(app.me.profile(sport)?.rating ?? 80)" : "Peer").font(.system(size: 11, weight: .bold)).foregroundStyle(MP.ink3)
                    }
                    .foregroundStyle(app.activeSport == sport ? MP.accent(sport) : MP.ink)
                    .padding(.horizontal, 11).frame(height: 46)
                    .background(app.activeSport == sport ? MP.soft(sport) : .clear, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6).frame(width: 230)
        .background(MP.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(MP.line))
        .shadow(color: Color.black.opacity(0.16), radius: 22, y: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 20).padding(.top, 58)
    }

    private var nativeNav: some View {
        HStack(spacing: 4) {
            navItem(.map, "map")
            navItem(.matches, app.activeSport.category == .group ? "calendar" : "checkmark.rectangle")
            navItem(.home, "house")
            navItem(.chats, "person.2")
            navItem(.profile, "person")
        }
        .padding(6)
        .background(MP.ink, in: Capsule())
        .shadow(color: MP.shadow, radius: 22, y: 10)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private func navItem(_ item: Tab, _ icon: String) -> some View {
        Button { tab = item; fabOpen = false } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                if tab == item {
                    Text(item == .matches && app.activeSport.category == .group ? "Calendar" : item.rawValue)
                        .font(RallyType.body(14, weight: .semibold))
                        .fixedSize()
                }
            }
            .foregroundStyle(tab == item ? MP.ink : MP.background.opacity(0.72))
            .padding(.horizontal, tab == item ? 16 : 13)
            .frame(minHeight: 46)
            .background(tab == item ? MP.orange : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item == .matches && app.activeSport.category == .group ? "Calendar" : item.rawValue)
        .accessibilityAddTraits(tab == item ? .isSelected : [])
    }

    private var fab: some View {
        VStack(alignment: .trailing, spacing: 9) {
            if fabOpen {
                if app.activeSport.category == .group {
                    fabOption("Submit a review", "star") { fabOpen = false; showPeerReview = true }
                    fabOption("Add to calendar", "calendar.badge.plus") { fabOpen = false; showFixture = true }
                } else {
                    fabOption("Add a challenge", "trophy") { fabOpen = false; showChallenge = true }
                    fabOption("Upload scores", "chart.bar") { fabOpen = false; showScore = true }
                }
            }
            Button { withAnimation(.spring(response: 0.25)) { fabOpen.toggle() } } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MP.background)
                    .rotationEffect(.degrees(fabOpen ? 45 : 0))
                    .animation(.spring(response: 0.34, dampingFraction: 0.78), value: fabOpen)
                    .frame(width: 54, height: 54)
                    .background(MP.black, in: Circle())
                    .shadow(color: Color.black.opacity(0.22), radius: 14, y: 7)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 90)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .accessibilityLabel(fabOpen ? "Close quick actions" : "Open quick actions")
    }

    private func fabOption(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(MP.black, in: Capsule())
        }
    }

    private func requestSportChange(_ sport: Sport) {
        guard sport != app.activeSport else { return }
        if app.hasUnsavedDraft {
            pendingSport = sport
            showExitWarning = true
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                app.activeSport = sport
                app.resetDeck()
            }
        }
    }
}

private enum MP {
    static let background = RallyPalette.cream
    static let surface = RallyPalette.cream
    static let surface2 = RallyPalette.creamDeep
    static let surface3 = RallyPalette.creamDeep
    static let line = RallyPalette.rule
    static let strongLine = RallyPalette.ink.opacity(0.18)
    static let ink = RallyPalette.ink
    static let ink2 = RallyPalette.ink.opacity(0.78)
    static let ink3 = RallyPalette.inkMuted
    static let ink4 = RallyPalette.ink.opacity(0.38)
    static let black = RallyPalette.ink
    static let danger = RallyPalette.danger
    static let orange = RallyPalette.sun
    static let lime = RallyPalette.sun
    static let shadow = RallyPalette.ink.opacity(0.10)

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.expanded)
    }

    static func accent(_ sport: Sport) -> Color {
        sport.category == .group ? RallyPalette.court : RallyPalette.sun
    }

    static func soft(_ sport: Sport) -> Color { RallyPalette.creamDeep }

    static func accentText(_ sport: Sport) -> Color {
        RallyPalette.court
    }
}

private struct MPAssetSportIcon: View {
    let sport: Sport
    var size: CGFloat

    var body: some View {
        if let asset = sport.illustrationIconAsset {
            Image(asset).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Image(systemName: sport.sfSymbol)
                .font(.system(size: size * 0.8, weight: .medium))
                .foregroundStyle(MP.accent(sport))
                .frame(width: size, height: size)
        }
    }
}

private struct MPCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .padding(16)
            .background(MP.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(MP.strongLine, lineWidth: 1))
            .shadow(color: MP.shadow, radius: 20, y: 10)
    }
}

private struct MPSectionHeader: View {
    let title: String
    var action: String?
    var body: some View {
        HStack {
            Text(title).font(RallyType.eyebrow).tracking(1.6).textCase(.uppercase).foregroundStyle(MP.ink3)
            Spacer()
            if let action { Text(action).font(.system(size: 12, weight: .bold)).foregroundStyle(MP.ink3) }
        }
    }
}

private struct NativeHomeScreen: View {
    @EnvironmentObject private var app: AppState
    let openTab: (SashankMainView.Tab) -> Void
    let switchSport: (Sport) -> Void
    @State private var selectedPlayer: Player?

    private var players: [Player] { app.players.filter { $0.profile(app.activeSport) != nil } }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    hero
                    homeSection("Verifications", action: "3 waiting", items: Array(players.prefix(3))) { player, index in
                        PersonPoster(player: player, sport: app.activeSport, line1: index.isMultiple(of: 2) ? "Singles · 2–1 games" : "Doubles · 1–2 games", line2: "Aug \(10 - index), 2026", badge: "Verify", badgeColor: MP.orange)
                    }
                    homeSection("Connection requests", action: "See all", items: Array(players.dropFirst(3).prefix(4))) { player, _ in
                        PersonPoster(player: player, sport: app.activeSport, line1: "\(String(format: "%.1f", player.distanceMiles)) miles away", line2: "Recently active", badge: "Wants to connect", badgeColor: MP.accent(app.activeSport))
                    }
                    challengeSection
                    homeSection(app.activeSport.category == .group ? "Players in your area" : "Recommended opponents", action: "Open map", items: Array(players.dropFirst(1).prefix(8))) { player, _ in
                        PersonPoster(player: player, sport: app.activeSport, line1: "\(String(format: "%.1f", player.distanceMiles)) miles away", line2: app.activeSport.category == .individual ? "MP Rating \(player.rating(app.activeSport))" : "Peer rated", badge: nil, badgeColor: MP.accent(app.activeSport))
                    }
                    communitySection.id("community")
                    Color.clear.frame(height: 150)
                }
            }
            .sheet(item: $selectedPlayer) { ProfileDetailView(player: $0) }
            .onAppear {
#if DEBUG
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("-demo-player-sheet") {
                    selectedPlayer = players.first
                }
                if arguments.contains("-demo-community") {
                    DispatchQueue.main.async {
                        proxy.scrollTo("community", anchor: .top)
                    }
                }
#endif
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("READY, \(firstName.uppercased()).")
                .rallyEyebrow(MP.ink3)
            VStack(alignment: .leading, spacing: 0) {
                Text("What are we")
                HStack(spacing: 10) {
                    Text("playing")
                        .background(alignment: .bottom) {
                            Capsule().fill(MP.orange).frame(height: 18).offset(y: -5).padding(.horizontal, -5)
                        }
                    Text("today?")
                }
            }
            .font(RallyType.hero)
            .rallyDisplayLeading()
            RallySportSelector(sports: app.mySports, selection: app.activeSport, select: switchSport)
                .padding(.horizontal, -RallyLayout.gutter)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RallyLayout.gutter)
        .padding(.top, 18)
    }

    private var firstName: String {
        app.me.name.split(separator: " ").first.map(String.init) ?? "player"
    }

    private var activeHeroAsset: String? {
        guard app.activeSport == .badminton else {
            return app.activeSport.heroIllustrationAsset
        }
        switch app.me.gender {
        case .male: return "hero-badminton-boy"
        case .female: return "hero-badminton-girl"
        case .nonBinary: return "hero-badminton"
        }
    }

    private func homeSection(
        _ title: String,
        action: String?,
        items: [Player],
        @ViewBuilder card: @escaping (Player, Int) -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            MPSectionHeader(title: title, action: action)
                .padding(.horizontal, RallyLayout.gutter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, player in
                        Button { selectedPlayer = player } label: { card(player, index) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, RallyLayout.gutter)
                .padding(.top, 26)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 24)
    }

    private var challengeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MPSectionHeader(title: app.activeSport.category == .group ? "Upcoming fixtures" : "Challenges", action: app.activeSport.category == .group ? "Calendar" : "See all")
                .padding(.horizontal, RallyLayout.gutter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(app.upcomingFaceOffs.prefix(4)) { match in
                        PersonPoster(player: app.player(match.opponentId) ?? players[0], sport: match.sport, line1: match.date.formatted(date: .abbreviated, time: .shortened), line2: match.venue, badge: match.state == .proposed ? "Needs a reply" : "Confirmed", badgeColor: MP.accent(match.sport))
                    }
                }
                .padding(.horizontal, RallyLayout.gutter)
                .padding(.top, 26)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 24)
    }

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MPSectionHeader(title: "\(app.activeSport.title) near you")
                .padding(.horizontal, RallyLayout.gutter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(NativeCommunity.forSport(app.activeSport)) { club in
                        CommunityPoster(community: club, sport: app.activeSport)
                    }
                }
                .padding(.horizontal, RallyLayout.gutter)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 24)
    }
}

private struct PersonPoster: View {
    let player: Player
    let sport: Sport
    let line1: String
    let line2: String
    let badge: String?
    let badgeColor: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RallyPhoto(name: player.rallyPhotoName)
                .frame(width: 282, height: 396)
                .clipped()
                .overlay(RallyPalette.photoScrim)
            VStack(alignment: .leading, spacing: 8) {
                RallySportTag(sport: sport)
                Text(player.name).font(RallyType.title).foregroundStyle(MP.background).lineLimit(1)
                Text(line1).font(RallyType.caption).foregroundStyle(RallyPalette.creamMuted).lineLimit(1)
                Text(line2).font(RallyType.caption).foregroundStyle(RallyPalette.creamMuted).lineLimit(1)
                if let badge {
                    Text(badge).font(RallyType.action).foregroundStyle(MP.ink)
                        .padding(.horizontal, 18).frame(height: 48)
                        .background(badgeColor, in: Capsule()).padding(.top, 4)
                }
            }
            .padding(22)
            RallyRatingPlate(sport: sport, profile: player.profile(sport), diameter: 78)
                .rallyLifted(0.8)
                .offset(x: 220, y: -320)
        }
        .frame(width: 282, height: 396, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: RallyLayout.photoRadius, style: .continuous))
    }
}

private struct NativeCommunity: Identifiable {
    let id = UUID()
    let name: String
    let kind: String
    let meta: String

    var imageName: String {
        switch kind {
        case "Club", "Ladder": "Rally-motif-together"
        case "Facility": "Rally-scene-paddles"
        default: "Rally-scene-court"
        }
    }

    static func forSport(_ sport: Sport) -> [NativeCommunity] {
        switch sport {
        case .pickleball:
            [NativeCommunity(name: "Riverside Pickleball Club", kind: "Club", meta: "64 members · 1.2 miles away"), NativeCommunity(name: "Meadow Park Open League", kind: "League", meta: "128 members · 2.6 miles away"), NativeCommunity(name: "Northgate Courts", kind: "Facility", meta: "8 courts · 0.9 miles away"), NativeCommunity(name: "Sunrise Doubles Ladder", kind: "Ladder", meta: "46 members · 3.4 miles away")]
        case .badminton:
            [NativeCommunity(name: "Thursday Badminton Social", kind: "Club", meta: "38 members · 2.4 miles away"), NativeCommunity(name: "City Shuttle League", kind: "League", meta: "92 members · 4.1 miles away"), NativeCommunity(name: "Cedar Street Sports Hall", kind: "Facility", meta: "6 courts · 1.6 miles away")]
        case .cricket:
            [NativeCommunity(name: "Sunday Cricket League", kind: "League", meta: "96 members · 3.1 miles away"), NativeCommunity(name: "Riverside XI", kind: "Club", meta: "22 members · 1.1 miles away"), NativeCommunity(name: "Fairmont Cricket Ground", kind: "Facility", meta: "2 pitches · 4.4 miles away"), NativeCommunity(name: "Midweek T20 Cup", kind: "Cup", meta: "64 members · 5.2 miles away")]
        default:
            [NativeCommunity(name: "Community Sports Club", kind: "Club", meta: "52 members · 2.8 miles away"), NativeCommunity(name: "City Open League", kind: "League", meta: "71 members · 1.9 miles away"), NativeCommunity(name: "Meadow Park Center", kind: "Facility", meta: "5 courts · 3.3 miles away")]
        }
    }
}

private struct CommunityPoster: View {
    let community: NativeCommunity
    let sport: Sport
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RallyPhoto(name: community.imageName)
                    .frame(width: 272, height: 164)
                    .clipped()
                Text(community.kind)
                    .rallyEyebrow(MP.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(MP.orange, in: Capsule())
                    .padding(14)
            }
            .frame(width: 272, height: 164)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(community.name)
                    .font(RallyType.cardTitle)
                    .foregroundStyle(MP.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(community.meta)
                    .font(RallyType.caption)
                    .foregroundStyle(MP.ink3)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(community.kind == "Facility" ? "View facility" : (community.kind == "Club" ? "Join community" : "Join league"))
                    .font(RallyType.action).foregroundStyle(MP.background)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(MP.ink, in: Capsule())
            }
            .padding(16)
        }
        .frame(width: 272, height: 350)
        .background(MP.surface)
        .clipShape(RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous)
                .stroke(MP.strongLine, lineWidth: 1)
        }
    }
}

private struct NativeMapScreen: View {
    @EnvironmentObject private var app: AppState
    @State private var camera: MapCameraPosition = .region(.init(center: .init(latitude: 30.2672, longitude: -97.7431), span: .init(latitudeDelta: 0.16, longitudeDelta: 0.16)))
    @State private var gender: Gender?
    @State private var rating = "Any rating"
    @State private var audience = "Everyone"
    @State private var selected: Player?

    private var players: [Player] {
        app.players.filter { player in
            guard player.profile(app.activeSport) != nil else { return false }
            guard audience != "Friends" || app.friendIds.contains(player.id) else { return false }
            guard gender == nil || player.gender == gender else { return false }
            switch rating {
            case "Under 80": return player.rating(app.activeSport) < 80
            case "80 to 110": return (80...110).contains(player.rating(app.activeSport))
            case "Above 110": return player.rating(app.activeSport) > 110
            default: return true
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $camera, interactionModes: [.pan, .zoom]) {
                Annotation("You", coordinate: .init(latitude: 30.2672, longitude: -97.7431)) {
                    Circle().fill(MP.accent(app.activeSport)).frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(color: MP.accent(app.activeSport).opacity(0.3), radius: 8)
                }
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    Annotation(player.name, coordinate: coordinate(index)) {
                        Button { selected = player } label: {
                            ZStack(alignment: .bottom) {
                                RallyPlayerAvatar(
                                    player: player,
                                    size: 48,
                                    ring: app.friendIds.contains(player.id) ? RallyPalette.sun : RallyPalette.cream,
                                    ringWidth: app.friendIds.contains(player.id) ? 4 : 2.5
                                )
                                    .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
                                Text("\(player.rating(app.activeSport))")
                                    .font(.system(size: 9, weight: .bold)).foregroundStyle(MP.accentText(app.activeSport))
                                    .padding(.horizontal, 5).frame(height: 15).background(RallyPalette.cream, in: Capsule()).offset(y: 5)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .environment(\.colorScheme, .light)
            .ignoresSafeArea(edges: .bottom)

            RallyPalette.sun.opacity(0.055)
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .bottom)

            HStack(spacing: 6) {
                Menu {
                    Button("Everyone") { audience = "Everyone" }
                    Button("Friends") { audience = "Friends" }
                } label: { filterChip(audience, icon: "person.2", width: 106) }
                Menu {
                    Button("Any gender") { gender = nil }
                    ForEach(Gender.allCases) { value in Button(value.rawValue) { gender = value } }
                } label: { filterChip(gender?.rawValue ?? "Gender", icon: "person", width: 88) }
                Menu {
                    ForEach(["Any rating", "Under 80", "80 to 110", "Above 110"], id: \.self) { value in Button(value) { rating = value } }
                } label: { filterChip(rating == "Any rating" ? "Rating" : rating, icon: "bolt", width: 88) }
                Button("Clear") { audience = "Everyone"; gender = nil; rating = "Any rating" }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(audience == "Everyone" && gender == nil && rating == "Any rating" ? MP.ink3 : MP.ink)
                    .lineLimit(1)
                    .frame(width: 56, height: 44).background(MP.background, in: Capsule())
                    .overlay(Capsule().stroke(MP.line, lineWidth: 1))
                    .disabled(audience == "Everyone" && gender == nil && rating == "Any rating")
            }
            .padding(.horizontal, 10)
            .padding(.top, 76)
        }
        .sheet(item: $selected) { player in
            ProfileDetailView(player: player).presentationDetents([.medium, .large])
        }
    }

    private func coordinate(_ index: Int) -> CLLocationCoordinate2D {
        let offsets: [(Double, Double)] = [(-0.026,-0.034),(-0.018,0.027),(0.031,-0.021),(0.024,0.034),(-0.044,0.008),(0.008,-0.047),(0.047,0.004),(-0.005,0.052),(0.052,-0.038),(-0.052,-0.025)]
        let pair = offsets[index % offsets.count]
        return .init(latitude: 30.2672 + pair.0, longitude: -97.7431 + pair.1)
    }

    private func filterChip(_ text: String, icon: String, width: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(MP.ink3)
        }
        .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(MP.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .padding(.horizontal, 8).frame(width: width).frame(height: 44).background(MP.background, in: Capsule())
        .overlay(Capsule().stroke(MP.line, lineWidth: 1)).shadow(color: MP.shadow, radius: 4, y: 1)
    }
}

private struct NativeMatchesScreen: View {
    @EnvironmentObject private var app: AppState
    let openProfile: () -> Void
    @State private var segment = "Upcoming"
    @State private var selected: MatchRecord?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Matches")
                    .font(RallyType.hero)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .rallyDisplayLeading()
                MPSegmented(options: ["Past", "Upcoming"], selection: $segment)
                if segment == "Past" {
                    Text("This log combines scheduled matches and manually uploaded scores.")
                        .font(.system(size: 12)).foregroundStyle(MP.ink3).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(app.myMatches) { match in
                        Button { selected = match } label: { PastMatchCard(match: match) }.buttonStyle(.plain)
                    }
                } else {
                    WeeklyCalendar(sport: app.activeSport)
                    CalendarLegend()
                }
                Color.clear.frame(height: 150)
            }
            .padding(.horizontal, 20)
        }
        .sheet(item: $selected) { record in
            NativeMatchDetail(record: record) {
                selected = nil
                openProfile()
            }
            .presentationDetents([.medium, .large])
        }
    }
}

private struct NativeCalendarScreen: View {
    @EnvironmentObject private var app: AppState
    @State private var segment = "Week"
    @State private var showFixture = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Calendar")
                    .font(RallyType.hero)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .rallyDisplayLeading()
                MPSegmented(options: ["Week", "Past matches"], selection: $segment)
                if segment == "Week" {
                    WeeklyCalendar(sport: app.activeSport)
                    CalendarLegend()
                    MPPrimaryButton(title: "Add to calendar", icon: "plus") { showFixture = true }
                    Text("You and your squad both add fixtures here. There are no challenges or score uploads in \(app.activeSport.title).")
                        .font(.system(size: 12)).foregroundStyle(MP.ink3).multilineTextAlignment(.center)
                } else {
                    ForEach(app.myMatches) { match in PastMatchCard(match: match) }
                }
                Color.clear.frame(height: 150)
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showFixture) { GroupFixtureSheet() }
    }
}

private struct MPSegmented: View {
    let options: [String]
    @Binding var selection: String
    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                Button(option) { selection = option }
                    .font(RallyType.action)
                    .foregroundStyle(selection == option ? RallyPalette.cream : MP.ink3)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(selection == option ? MP.ink : .clear, in: Capsule())
                    .buttonStyle(RallyPressStyle())
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(4).background(MP.surface3, in: Capsule())
    }
}

private struct WeeklyCalendar: View {
    let sport: Sport
    @State private var weekOffset = 0
    private let hours = Array(7...22)

    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let mondayDistance = weekday == 1 ? -6 : 2 - weekday
        let monday = calendar.date(byAdding: .day, value: mondayDistance + weekOffset * 7, to: today) ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private var monthTitle: String {
        days.first?.formatted(.dateTime.month(.wide).year()) ?? "Calendar"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(monthTitle).font(.system(size: 15.5, weight: .bold))
                Spacer()
                Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left") }.calendarNav()
                Button("Today") { weekOffset = 0 }.font(.system(size: 12, weight: .bold)).calendarNav(width: 58)
                Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") }.calendarNav()
            }
            .padding(.bottom, 12)

            HStack(spacing: 0) {
                Color.clear.frame(width: 38)
                ForEach(days, id: \.self) { day in
                    let today = Calendar.current.isDateInToday(day)
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow))).font(.system(size: 12, weight: .bold)).foregroundStyle(today ? MP.accent(sport) : MP.ink3)
                        Text(day.formatted(.dateTime.day()))
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(today ? MP.black : MP.ink)
                            .frame(width: 28, height: 28).background(today ? MP.accent(sport) : .clear, in: Circle())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 7)

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(hours, id: \.self) { hour in
                            Text(hourLabel(hour)).font(.system(size: 11, weight: .medium)).foregroundStyle(MP.ink3)
                                .frame(width: 38, height: 40, alignment: .topLeading)
                        }
                    }
                    ForEach(0..<7, id: \.self) { _ in
                        VStack(spacing: 0) { ForEach(hours, id: \.self) { _ in Rectangle().fill(MP.line).frame(height: 1).frame(maxHeight: .infinity) } }
                            .frame(maxWidth: .infinity).overlay(Rectangle().fill(MP.line).frame(width: 1), alignment: .leading)
                    }
                }
                calendarEvent(day: 1, start: 9, duration: 1.5, title: "Practice", tentative: false)
                calendarEvent(day: 3, start: 19, duration: 1.5, title: sport.category == .group ? "Riverside XI" : "Challenge", tentative: true)
                calendarEvent(day: 5, start: 15, duration: 2, title: sport.category == .group ? "Sunday League" : "Doubles", tentative: false)
            }
            .frame(height: CGFloat(hours.count) * 40)
            .clipped()
        }
        .padding(14)
        .background(MP.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(MP.strongLine, lineWidth: 1))
    }

    private func calendarEvent(day: Int, start: Double, duration: Double, title: String, tentative: Bool) -> some View {
        GeometryReader { geo in
            let column = (geo.size.width - 38) / 7
            Text(title).font(.system(size: 9, weight: .bold)).lineLimit(2).minimumScaleFactor(0.72)
                .foregroundStyle(MP.ink)
                .padding(3).frame(width: column - 2, height: duration * 40, alignment: .topLeading)
                .background(tentative ? RallyPalette.cream : RallyPalette.sun, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(tentative ? RallyPalette.ink : .clear, style: StrokeStyle(lineWidth: 1.3, dash: tentative ? [4, 3] : []))
                }
                .offset(x: 38 + CGFloat(day) * column + 1, y: CGFloat(start - 7) * 40)
        }
    }

    private func hourLabel(_ hour: Int) -> String { "\(hour > 12 ? hour - 12 : hour) \(hour >= 12 ? "PM" : "AM")" }
}

private extension View {
    func calendarNav(width: CGFloat = 34) -> some View {
        self.foregroundStyle(MP.ink2).frame(width: max(width, 44), height: 44)
            .background(MP.surface2, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(MP.line, lineWidth: 1))
    }
}

private struct CalendarLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            legend(RallyPalette.sun, "Confirmed booking")
            legend(RallyPalette.cream, "Awaiting reply", border: RallyPalette.ink, dashed: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func legend(_ color: Color, _ title: String, border: Color = .clear, dashed: Bool = false) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(border, style: StrokeStyle(lineWidth: 1.3, dash: dashed ? [4, 3] : []))
                }
            Text(title).font(RallyType.caption).foregroundStyle(MP.ink3)
        }
    }
}

private struct PastMatchCard: View {
    let match: MatchRecord
    var body: some View {
        MPCard {
            VStack(spacing: 13) {
                HStack(spacing: 12) {
                    AvatarView(avatar: match.opponentAvatar, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(match.didWin ? "Win against" : "Loss to") \(match.opponentName)").font(.system(size: 15.5, weight: .bold))
                        Text("Singles · \(match.didWin ? "11–8, 11–6" : "8–11, 9–11")").font(.system(size: 12)).foregroundStyle(MP.ink3)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(match.ratingDelta > 0 ? "+\(match.ratingDelta)" : "\(match.ratingDelta)").font(.system(size: 17, weight: .heavy)).foregroundStyle(match.didWin ? Color(hex: "477A19") : Color(hex: "B83218"))
                        Text(match.date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 10)).foregroundStyle(MP.ink3)
                    }
                }
                Divider().overlay(MP.line)
                HStack { Label(match.venue, systemImage: "mappin").font(.system(size: 11)).foregroundStyle(MP.ink3); Spacer(); Text(match.source == .unscheduled ? "Uploaded score" : "Scheduled match").font(.system(size: 10, weight: .bold)).foregroundStyle(MP.ink2).padding(.horizontal, 8).frame(height: 24).background(MP.surface3, in: Capsule()) }
            }
        }
    }
}

private struct MPPrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(RallyType.action)
                .foregroundStyle(MP.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(MP.orange, in: Capsule())
        }
        .buttonStyle(RallyPressStyle())
    }
}

private struct NativeMatchDetail: View {
    let record: MatchRecord
    let showStatistics: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(MP.line).frame(width: 42, height: 5)
            AvatarView(avatar: record.opponentAvatar, size: 72)
            Text(record.didWin ? "Win against \(record.opponentName)" : "Loss to \(record.opponentName)").font(.system(size: 21, weight: .bold))
            Text(record.didWin ? "11–8, 11–6" : "8–11, 9–11").font(.system(size: 26, weight: .heavy)).foregroundStyle(record.didWin ? Color(hex: "477A19") : Color(hex: "B83218"))
            Text("\(record.date.formatted(date: .long, time: .omitted)) · \(record.venue)").font(.system(size: 13)).foregroundStyle(MP.ink3)
            if !record.gameScores.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(record.gameScores.enumerated()), id: \.element.id) { index, game in
                        Text("Game \(index + 1) · \(game.myScore)–\(game.opponentScore)")
                            .font(RallyType.meta)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            RallyPillButton(title: "View statistics", icon: "chart.xyaxis.line", style: .ink, fill: true, action: showStatistics)
            Spacer()
        }
        .padding(20).presentationBackground(MP.background)
    }
}

private struct NativeChatsScreen: View {
    @EnvironmentObject private var app: AppState
    @State private var segment = "Chats"
    @State private var search = ""
    @State private var selectedProfile: Player?
    @State private var selectedConversation: Conversation?
    @State private var showGroupComposer = false

    private var conversations: [Conversation] {
        app.conversations.filter { conversation in
            conversation.sport == app.activeSport &&
            (segment == "Requests" ? conversation.isMessageRequest : !conversation.isMessageRequest)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(alignment: .center) {
                    Text("Chats").font(RallyType.hero).rallyDisplayLeading()
                    Spacer()
                    Button { showGroupComposer = true } label: {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(RallyPalette.cream)
                            .frame(width: 48, height: 48)
                            .background(RallyPalette.ink, in: Circle())
                    }
                    .buttonStyle(RallyPressStyle())
                    .accessibilityLabel("Create group chat")
                }
                MPSegmented(options: ["Chats", "Requests"], selection: $segment)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(MP.ink4)
                    TextField("Search by name or username", text: $search)
                        .font(RallyType.body())
                        .foregroundStyle(MP.ink)
                }
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(MP.surface2, in: Capsule())

                ForEach(conversations.filter { conversation in
                    guard !search.isEmpty, let player = app.player(conversation.partnerId) else { return search.isEmpty }
                    return player.name.localizedCaseInsensitiveContains(search) || player.username.localizedCaseInsensitiveContains(search)
                }) { conversation in
                    if let player = app.player(conversation.partnerId) {
                        Button { selectedConversation = conversation } label: {
                            HStack(spacing: 12) {
                                RallyPhoto(name: player.rallyPhotoName)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .contentShape(Circle()).onTapGesture { selectedProfile = player }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(player.name).font(.system(size: 15.5, weight: .bold)).foregroundStyle(MP.ink)
                                    Text(preview(conversation)).font(.system(size: 13)).foregroundStyle(MP.ink3).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(MP.ink4)
                            }
                            .padding(.vertical, 9)
                        }.buttonStyle(.plain)
                    }
                }
                Color.clear.frame(height: 150)
            }
            .padding(.horizontal, 20)
        }
        .sheet(item: $selectedProfile) { ProfileDetailView(player: $0).presentationDetents([.large]) }
        .sheet(isPresented: $showGroupComposer) {
            GroupChatComposer()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(item: $selectedConversation) { conversation in
            NativeChatScreen(conversation: conversation)
        }
        .onAppear {
#if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-demo-group-chat") {
                showGroupComposer = true
            }
            if arguments.contains("-demo-thread") {
                selectedConversation = conversations.first
            }
#endif
        }
    }

    private func preview(_ conversation: Conversation) -> String {
        guard let message = conversation.lastMessage else { return "" }
        switch message.kind {
        case .text(let value): return (message.fromMe ? "You: " : "") + value
        case .challenge: return "Challenge invitation"
        case .faceOff: return "Match scheduled"
        case .image: return "Photo"
        case .location(let value): return value
        case .system(let value): return value
        }
    }
}

struct NativeChatScreen: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let conversation: Conversation
    @State private var draft = ""
    @State private var showChallenge = false

    private var player: Player? { app.player(conversation.partnerId) }
    private var currentConversation: Conversation {
        app.conversations.first(where: { $0.id == conversation.id }) ?? conversation
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(MP.ink.opacity(0.22), lineWidth: 1.5))
                }
                .buttonStyle(RallyPressStyle())
                if let player { RallyPlayerAvatar(player: player, size: 40, ring: MP.background) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(player?.name ?? "Conversation").font(.system(size: 15.5, weight: .bold))
                    Text(player?.username ?? "").font(.system(size: 11)).foregroundStyle(MP.ink3)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(MP.background)
            .overlay(alignment: .bottom) { Rectangle().fill(MP.line).frame(height: 1) }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if currentConversation.isMessageRequest {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "link")
                            Text("Start a conversation and wait for their response before sending your first challenge.")
                        }
                        .font(.system(size: 12)).foregroundStyle(MP.ink2).padding(12).background(MP.surface2, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Text("Today").font(.system(size: 10, weight: .bold)).foregroundStyle(MP.ink4).padding(.vertical, 8)
                    ForEach(currentConversation.messages) { message in
                        HStack {
                            if message.fromMe { Spacer(minLength: 70) }
                            Text(messageText(message))
                                .font(.system(size: 14)).foregroundStyle(message.fromMe ? MP.black : MP.ink)
                                .padding(.horizontal, 13).padding(.vertical, 10)
                                .background(message.fromMe ? MP.accent(app.activeSport) : MP.surface2, in: RoundedRectangle(cornerRadius: 17))
                                .overlay(RoundedRectangle(cornerRadius: 17).stroke(message.fromMe ? .clear : MP.line))
                            if !message.fromMe { Spacer(minLength: 70) }
                        }
                    }
                }
                .padding(20)
            }
            .background(MP.background)

            HStack(spacing: 9) {
                if app.activeSport.category == .individual {
                    Button { showChallenge = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(MP.ink)
                            .frame(width: 50, height: 50)
                            .overlay(Circle().stroke(MP.ink.opacity(0.32), lineWidth: 1.5))
                    }
                    .buttonStyle(RallyPressStyle())
                    .accessibilityLabel("Create a challenge")
                }
                TextField("Write a message", text: $draft)
                    .font(RallyType.body())
                    .padding(.horizontal, 18)
                    .frame(height: 50)
                    .background(MP.surface2, in: Capsule())
                Button {
                    let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    app.send(.text(text), to: conversation.partnerId)
                    draft = ""
                } label: { Image(systemName: "arrow.up").foregroundStyle(MP.background).frame(width: 50, height: 50).background(MP.ink, in: Circle()) }
                    .buttonStyle(RallyPressStyle())
            }
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 26).background(MP.background)
        }
        .background(MP.background.ignoresSafeArea())
        .foregroundStyle(MP.ink).preferredColorScheme(.light)
        .sheet(isPresented: $showChallenge) {
            if let player { ChallengeComposerView(player: player) }
        }
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demo-challenge") {
                showChallenge = true
            }
#endif
        }
    }

    private func messageText(_ message: ChatMessage) -> String {
        switch message.kind {
        case .text(let value): value
        case .challenge(let value): "Challenge · \(value.wager)\n\(value.note)"
        case .faceOff(let value): "Match at \(value.venue)"
        case .image: "Photo"
        case .location(let value): value
        case .system(let value): value
        }
    }
}

private struct NativeProfileScreen: View {
    @EnvironmentObject private var app: AppState

    private var profile: SportProfile? { app.me.profile(app.activeSport) }
    private var profileHeroImage: String { "Rally-player-maya" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: RallyLayout.photoRadius, style: .continuous)
                        .fill(MP.orange)
                        .frame(height: 330)

                    RallyPhoto(name: profileHeroImage)
                        .frame(width: 176, height: 326)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .rallyLifted(0.6)
                        .offset(x: 160, y: -48)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(app.me.city).rallyEyebrow(MP.ink.opacity(0.56))
                        Text(app.me.name.isEmpty ? "Your name" : app.me.name)
                            .font(RallyType.title).rallyDisplayLeading()
                        Text("@\(app.me.username) · \(app.me.age) · \(app.me.gender.rawValue)")
                            .font(RallyType.caption).foregroundStyle(MP.ink.opacity(0.62))
                        Text("\(app.displayedFriendCount) friends")
                            .font(RallyType.caption).foregroundStyle(MP.ink.opacity(0.62))
                    }
                    .frame(width: 154, alignment: .leading)
                    .padding(24)
                }
                .frame(height: 330)
                .padding(.top, 62)

                RallySportSelector(sports: app.mySports, selection: app.activeSport) { app.activeSport = $0 }
                    .padding(.horizontal, -20)

                ratingCard
                MPSectionHeader(title: "\(app.activeSport.title) statistics")
                statisticsBlock
                if profile?.usesElo == true { ratingTrend }
                if app.activeSport.category == .group { testimonials }
                settings
                Color.clear.frame(height: 150)
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder private var ratingCard: some View {
        if app.activeSport.category == .group {
            VStack(alignment: .leading, spacing: 16) {
                Text("Peer skill evaluation").rallyEyebrow()
                ForEach(profile?.peerSkillRatings ?? []) { skill in
                    HStack(alignment: .firstTextBaseline) {
                        Text(skill.category).font(RallyType.meta)
                        Spacer()
                        Text(String(format: "%.1f", skill.average))
                            .font(RallyType.numeral(28))
                        Text("of 5").font(RallyType.caption).foregroundStyle(MP.ink3)
                    }
                }
            }
            .padding(22)
            .background(MP.surface2, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(app.activeSport.title).rallyEyebrow(MP.orange)
                Text(profile?.usesElo == true ? "\(profile?.rating ?? 80)" : "Unrated")
                    .font(RallyType.numeral(profile?.usesElo == true ? 72 : 42))
                    .foregroundStyle(MP.background)
                Text(profile?.usesElo == true ? "Your current MP rating" : "This sport does not affect your rating")
                    .font(RallyType.caption)
                    .foregroundStyle(RallyPalette.creamMuted)
                Rectangle().fill(MP.background.opacity(0.16)).frame(height: 1).padding(.vertical, 5)
                HStack {
                    Text("How the MP rating works").font(RallyType.action)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(MP.background)
            }
            .padding(22)
            .background(MP.ink, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
        }
    }

    private var statisticsBlock: some View {
        HStack(spacing: 0) {
            statistic("\(app.myMatches.count)", app.activeSport.category == .group ? "Fixtures" : "Matches")
            Rectangle().fill(MP.line).frame(width: 1, height: 54)
            statistic("\(app.wins)", "Wins")
            Rectangle().fill(MP.line).frame(width: 1, height: 54)
            statistic("\(Int(app.winPct))%", "Win rate")
        }
        .padding(.vertical, 16)
        .background(MP.surface2, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
    }

    private func statistic(_ value: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            Text(value).font(RallyType.numeral(28)).foregroundStyle(MP.ink)
            Text(label).font(RallyType.caption).foregroundStyle(MP.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    private var ratingTrend: some View {
        VStack(alignment: .leading, spacing: 12) {
            MPSectionHeader(title: "Rating trend")
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Last 30 days").font(RallyType.caption).foregroundStyle(MP.ink3)
                    Spacer()
                    Text("+\((app.ratingHistory.last?.rating ?? 0) - (app.ratingHistory.first?.rating ?? 0))")
                        .font(RallyType.numeral(24))
                        .foregroundStyle(MP.ink)
                }
                Chart(app.ratingHistory) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Rating", point.rating))
                        .foregroundStyle(MP.ink)
                        .lineStyle(.init(lineWidth: 2.4, lineCap: .round))
                    PointMark(x: .value("Date", point.date), y: .value("Rating", point.rating))
                        .foregroundStyle(MP.orange)
                        .symbolSize(18)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 104)
            }
            .padding(20)
            .background(MP.surface2, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
        }
    }

    private var testimonials: some View {
        VStack(alignment: .leading, spacing: 10) {
            MPSectionHeader(title: "Peer testimonials")
            ForEach(app.players.prefix(3)) { player in
                MPCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { AvatarView(avatar: player.avatar, size: 32); Text(player.name).font(.system(size: 13, weight: .bold)); Spacer(); stars(5) }
                        Text("A tough competitor who keeps the mood light. Highly recommended for any weekend side.").font(.system(size: 13)).foregroundStyle(MP.ink2)
                    }
                }
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            MPSectionHeader(title: "Account configuration")
            VStack(spacing: 0) {
                ForEach(["Edit profile details", "Manage your sports", "Privacy and visibility", "Notification preferences"], id: \.self) { title in
                    HStack {
                        Text(title).font(RallyType.body(16, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MP.ink3)
                    }
                    .frame(minHeight: 58)
                    Rectangle().fill(MP.line).frame(height: 1)
                }
                HStack {
                    Text("Reset this account").font(RallyType.body(16, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .frame(minHeight: 58)
            }
        }
    }

    private func stars(_ value: Double) -> some View {
        HStack(spacing: 2) { ForEach(1...5, id: \.self) { index in Image(systemName: Double(index) <= value.rounded() ? "star.fill" : "star").font(.system(size: 10)).foregroundStyle(MP.accentText(app.activeSport)) } }
    }
}

private struct NativeNotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Notifications").font(MP.display(30, weight: .bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold))
                        .frame(width: 38, height: 38).background(MP.surface2, in: Circle())
                        .overlay(Circle().stroke(MP.line))
                }
            }
            ForEach([
                ("Elena sent a connection request.", "person.badge.plus"),
                ("Your score is ready to verify.", "checkmark.seal"),
                ("A challenge time was proposed.", "calendar"),
                ("Your rating moved up three points.", "chart.line.uptrend.xyaxis")
            ], id: \.0) { item in
                HStack(spacing: 13) {
                    Image(systemName: item.1).frame(width: 42, height: 42)
                        .background(MP.orange, in: Circle()).foregroundStyle(MP.black)
                    Text(item.0).font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .padding(14).background(MP.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(MP.line))
            }
            Spacer()
        }
        .padding(20).background(MP.background).foregroundStyle(MP.ink).preferredColorScheme(.light)
    }
}

private struct NativeChallengeSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var opponent: UUID?
    @State private var venue = "Riverside Courts"
    @State private var selectedDay = "Thursday"
    @State private var selectedTime = "7:00 PM"
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(MP.line).frame(width: 42, height: 5).padding(.top, 10)
            HStack {
                VStack(alignment: .leading, spacing: 3) { Text("Add a Challenge").font(.system(size: 21, weight: .bold)); Text("Offer several times so your opponent can choose.").font(.system(size: 12)).foregroundStyle(MP.ink3) }
                Spacer(); Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 36, height: 36).background(MP.surface2, in: Circle()).overlay(Circle().stroke(MP.line)) }
            }
            .padding(20)
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    fieldLabel("Opponent")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            ForEach(app.players.filter { $0.profile(app.activeSport) != nil }.prefix(8)) { player in
                                Button { opponent = player.id } label: {
                                    VStack(spacing: 5) { AvatarView(avatar: player.avatar, size: 48); Text(player.name.split(separator: " ").first.map(String.init) ?? player.name).font(.system(size: 11, weight: .bold)) }
                                        .foregroundStyle(MP.ink).padding(8).background(opponent == player.id ? MP.soft(app.activeSport) : MP.surface, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(opponent == player.id ? MP.accent(app.activeSport) : MP.line))
                                }
                            }
                        }
                    }
                    fieldLabel("Proposed time")
                    HStack(spacing: 8) {
                        ForEach(["Thursday", "Saturday", "Sunday"], id: \.self) { day in choice(day, selected: selectedDay == day) { selectedDay = day } }
                    }
                    HStack(spacing: 8) {
                        ForEach(["7:00 PM", "9:00 AM", "11:00 AM"], id: \.self) { time in choice(time, selected: selectedTime == time) { selectedTime = time } }
                    }
                    fieldLabel("Venue")
                    TextField("Venue", text: $venue).padding(.horizontal, 14).frame(height: 48).background(MP.surface, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(MP.line))
                    MPPrimaryButton(title: "Send the Challenge", icon: "paperplane") { dismiss() }.opacity(opponent == nil ? 0.45 : 1).disabled(opponent == nil)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(MP.background).foregroundStyle(MP.ink).preferredColorScheme(.light)
    }

    private func fieldLabel(_ value: String) -> some View { Text(value.uppercased()).font(.system(size: 11, weight: .heavy)).tracking(0.8).foregroundStyle(MP.ink3) }
    private func choice(_ value: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(value).font(.system(size: 12, weight: .bold)).foregroundStyle(selected ? MP.accentText(app.activeSport) : MP.ink2).padding(.horizontal, 12).frame(height: 44).background(selected ? MP.soft(app.activeSport) : MP.surface, in: Capsule()).overlay(Capsule().stroke(selected ? MP.accent(app.activeSport) : MP.line)) }
    }
}

private struct NativeScoreSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var format = "Singles"
    @State private var matches = 3
    @State private var winners: [Int] = [0, 1, 0]

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(MP.line).frame(width: 42, height: 5).padding(.top, 10)
            HStack {
                VStack(alignment: .leading, spacing: 3) { Text("Upload scores").font(.system(size: 21, weight: .bold)); Text("Log a session played in or outside Match Point.").font(.system(size: 12)).foregroundStyle(MP.ink3) }
                Spacer(); Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 36, height: 36).background(MP.surface2, in: Circle()).overlay(Circle().stroke(MP.line)) }
            }
            .padding(20)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("FORMAT").font(.system(size: 11, weight: .heavy)).tracking(0.8).foregroundStyle(MP.ink3)
                    MPSegmented(options: ["Singles", "Doubles"], selection: $format)
                    if format == "Doubles" {
                        MPCard { HStack { Image(systemName: "person.2"); Text("Choose your partner and two opponents").font(.system(size: 13, weight: .semibold)); Spacer(); Image(systemName: "chevron.right") } }
                    }
                    HStack { Text("MATCHES PLAYED").font(.system(size: 11, weight: .heavy)).tracking(0.8).foregroundStyle(MP.ink3); Spacer(); Stepper("\(matches)", value: $matches, in: 1...5).labelsHidden(); Text("\(matches)").font(.system(size: 15, weight: .bold)) }
                    ForEach(0..<matches, id: \.self) { index in
                        MPCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Game \(index + 1)").font(.system(size: 14, weight: .bold))
                                HStack(spacing: 8) {
                                    winnerButton("Your team", selected: winner(index) == 0) { setWinner(0, index) }
                                    winnerButton("Opponents", selected: winner(index) == 1) { setWinner(1, index) }
                                }
                            }
                        }
                    }
                    MPPrimaryButton(title: "Save the scores", icon: "checkmark") { dismiss() }
                }
                .padding(.horizontal, 20).padding(.bottom, 28)
            }
        }
        .background(MP.background).foregroundStyle(MP.ink).preferredColorScheme(.light)
    }

    private func winner(_ index: Int) -> Int { winners.indices.contains(index) ? winners[index] : 0 }
    private func setWinner(_ value: Int, _ index: Int) { while winners.count <= index { winners.append(0) }; winners[index] = value }
    private func winnerButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(selected ? MP.black : MP.ink2).frame(maxWidth: .infinity).frame(height: 44).background(selected ? MP.accent(app.activeSport) : MP.surface2, in: RoundedRectangle(cornerRadius: 12)) }
    }
}

private struct PeerReviewLauncher: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Player?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Who did you play?")
                        .font(RallyType.title)
                        .rallyDisplayLeading()
                    Text("Peer ratings are available after a verified \(app.activeSport.title) fixture.")
                        .font(RallyType.body())
                        .foregroundStyle(RallyPalette.inkMuted)
                    ForEach(app.players.filter { $0.profile(app.activeSport) != nil }) { player in
                        Button { selected = player } label: {
                            HStack(spacing: 14) {
                                RallyPlayerAvatar(player: player, size: 54)
                                Text(player.name).font(RallyType.body(17, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .foregroundStyle(RallyPalette.ink)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(RallyPressStyle())
                        Divider().overlay(RallyPalette.rule)
                    }
                }
                .padding(RallyLayout.gutter)
            }
            .background(RallyPalette.cream)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { CloseIconButton { dismiss() } } }
            .sheet(item: $selected) { player in
                PeerRatingSheet(player: player, sport: app.activeSport)
            }
        }
    }
}

private struct GroupFixtureSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var playerId: UUID?
    @State private var date = Date().addingTimeInterval(86_400)
    @State private var venue = "Riverside Sports Ground"

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add a fixture")
                    .font(RallyType.title)
                    .rallyDisplayLeading()
                Text("Add a \(app.activeSport.title) fixture to your shared calendar.")
                    .font(RallyType.body())
                    .foregroundStyle(RallyPalette.inkMuted)
                Picker("Player or captain", selection: $playerId) {
                    Text("Choose a player").tag(UUID?.none)
                    ForEach(app.players.filter { $0.profile(app.activeSport) != nil }) {
                        Text($0.name).tag(Optional($0.id))
                    }
                }
                .padding(16).background(RallyPalette.creamDeep, in: Capsule())
                DatePicker("Date and time", selection: $date, in: Date()...)
                    .font(RallyType.meta)
                    .padding(16).background(RallyPalette.creamDeep, in: RallySquircle(radius: 20))
                TextField("Venue", text: $venue)
                    .font(RallyType.body())
                    .padding(16).background(RallyPalette.creamDeep, in: Capsule())
                Spacer()
                RallyPillButton(title: "Add to calendar", icon: "calendar.badge.plus", style: .ink, fill: true, enabled: playerId != nil) {
                    guard let playerId, let player = app.player(playerId) else { return }
                    app.scheduleFaceOff(with: player, date: date, venue: venue, wager: "No wager")
                    dismiss()
                }
            }
            .padding(RallyLayout.gutter)
            .background(RallyPalette.cream)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { CloseIconButton { dismiss() } } }
        }
    }
}
