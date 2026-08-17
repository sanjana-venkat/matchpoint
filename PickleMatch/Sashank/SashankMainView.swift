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
                appBar
                Group {
                    switch tab {
                    case .map: NativeMapScreen()
                    case .matches:
                        if app.activeSport.category == .group { NativeCalendarScreen() }
                        else { NativeMatchesScreen() }
                    case .home: NativeHomeScreen(openTab: { tab = $0 })
                    case .chats: NativeChatsScreen()
                    case .profile: NativeProfileScreen()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
#endif
        }
        .sheet(isPresented: $showNotifications) { NativeNotificationsSheet() }
        .sheet(isPresented: $showScore) { NativeScoreSheet() }
        .sheet(isPresented: $showChallenge) { NativeChallengeSheet() }
    }

    private var appBar: some View {
        HStack(spacing: 10) {
            Button { withAnimation(.easeOut(duration: 0.16)) { showSports.toggle() } } label: {
                HStack(spacing: 6) {
                    MPAssetSportIcon(sport: app.activeSport, size: 23)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MP.ink3)
                }
                .frame(minWidth: 64, minHeight: 44)
                .background(MP.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(MP.line, lineWidth: 1))
                .shadow(color: MP.shadow, radius: 8, y: 2)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity)

            Button { showNotifications = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bell")
                        .font(.system(size: 19, weight: .semibold))
                    Text("4")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 21, height: 21)
                        .background(MP.accent(app.activeSport), in: Circle())
                }
                .frame(minWidth: 64, minHeight: 44)
                .background(MP.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(MP.line, lineWidth: 1))
                .shadow(color: MP.shadow, radius: 8, y: 2)
            }
            .buttonStyle(.plain)
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
                    app.activeSport = sport
                    showSports = false
                } label: {
                    HStack(spacing: 11) {
                        MPAssetSportIcon(sport: sport, size: 21)
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
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(MP.line))
        .shadow(color: Color.black.opacity(0.16), radius: 22, y: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 20).padding(.top, 58)
    }

    private var nativeNav: some View {
        HStack(spacing: 0) {
            navItem(.map, "map")
            navItem(.matches, app.activeSport.category == .group ? "calendar" : "checkmark.rectangle")
            Button { tab = .home; fabOpen = false } label: {
                VStack(spacing: 4) {
                    Image(systemName: "house")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(tab == .home ? .white : MP.ink3)
                        .frame(width: 58, height: 58)
                        .background(tab == .home ? MP.accent(app.activeSport) : MP.surface2, in: Circle())
                        .shadow(color: tab == .home ? MP.accent(app.activeSport).opacity(0.22) : .clear, radius: 10, y: 4)
                    Text("Home")
                }
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(tab == .home ? MP.accent(app.activeSport) : MP.ink3)
                .offset(y: -16)
            }
            .frame(maxWidth: .infinity)
            navItem(.chats, "person.2")
            navItem(.profile, "person")
        }
        .frame(height: 84)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34).stroke(Color.white.opacity(0.9), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.13), radius: 24, y: 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private func navItem(_ item: Tab, _ icon: String) -> some View {
        Button { tab = item; fabOpen = false } label: {
            VStack(spacing: 5) {
                Capsule()
                    .fill(tab == item ? MP.accent(app.activeSport) : .clear)
                    .frame(width: 20, height: 3)
                Image(systemName: icon).font(.system(size: 21, weight: .medium))
                Text(item == .matches && app.activeSport.category == .group ? "Calendar" : item.rawValue)
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundStyle(tab == item ? MP.accent(app.activeSport) : MP.ink3)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var fab: some View {
        VStack(alignment: .trailing, spacing: 9) {
            if fabOpen {
                if app.activeSport.category == .group {
                    fabOption("Submit a review", "star") { fabOpen = false }
                    fabOption("Add to calendar", "calendar.badge.plus") { fabOpen = false }
                } else {
                    fabOption("Add a challenge", "trophy") { fabOpen = false; showChallenge = true }
                    fabOption("Upload scores", "chart.bar") { fabOpen = false; showScore = true }
                }
            }
            Button { withAnimation(.spring(response: 0.25)) { fabOpen.toggle() } } label: {
                Image(systemName: fabOpen ? "xmark" : "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(MP.black, in: Circle())
                    .shadow(color: Color.black.opacity(0.22), radius: 14, y: 7)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 106)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private func fabOption(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(MP.black, in: Capsule())
        }
    }
}

private enum MP {
    static let background = Color(hex: "F7F8FB")
    static let surface = Color.white
    static let surface2 = Color(hex: "F4F6FA")
    static let surface3 = Color(hex: "EBEEF4")
    static let line = Color(hex: "E6E9F0")
    static let ink = Color(hex: "151821")
    static let ink2 = Color(hex: "565D70")
    static let ink3 = Color(hex: "858C9E")
    static let ink4 = Color(hex: "A9B0BF")
    static let black = Color(hex: "14161C")
    static let danger = Color(hex: "CE5555")
    static let orange = Color(hex: "D0762F")
    static let shadow = Color(hex: "141A2C").opacity(0.07)

    static func accent(_ sport: Sport) -> Color {
        switch sport {
        case .pickleball: Color(hex: "4CA85F")
        case .badminton: Color(hex: "3D82C4")
        case .pingPong: Color(hex: "D0762F")
        case .cricket: Color(hex: "CE5555")
        case .soccer: Color(hex: "2F7A50")
        case .volleyball: Color(hex: "7857BE")
        case .tennis: Color(hex: "B58A27")
        case .squash: Color(hex: "A45C9C")
        case .baseball: Color(hex: "536FA8")
        case .football: Color(hex: "9A6A43")
        }
    }

    static func soft(_ sport: Sport) -> Color { accent(sport).opacity(0.11) }
}

private struct MPAssetSportIcon: View {
    let sport: Sport
    var size: CGFloat

    private var asset: String? {
        switch sport {
        case .pickleball: "sport_pickleball"
        case .badminton: "sport_badminton"
        case .cricket: "sport_cricket"
        case .soccer: "sport_soccer"
        case .tennis: "sport_tennis"
        default: nil
        }
    }

    var body: some View {
        if let asset {
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
            .background(MP.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(MP.line, lineWidth: 1))
            .shadow(color: MP.shadow, radius: 8, y: 2)
    }
}

private struct MPSectionHeader: View {
    let title: String
    var action: String?
    var body: some View {
        HStack {
            Text(title).font(.system(size: 17, weight: .bold))
            Spacer()
            if let action { Text(action).font(.system(size: 12, weight: .bold)).foregroundStyle(MP.ink3) }
        }
    }
}

private struct NativeHomeScreen: View {
    @EnvironmentObject private var app: AppState
    let openTab: (SashankMainView.Tab) -> Void
    @State private var selectedPlayer: Player?

    private var players: [Player] { app.players.filter { $0.profile(app.activeSport) != nil } }

    var body: some View {
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
                communitySection
                Color.clear.frame(height: 150)
            }
            .padding(.horizontal, 20)
        }
        .sheet(item: $selectedPlayer) { ProfileDetailView(player: $0) }
    }

    private var hero: some View {
        VStack(spacing: 2) {
            Text("Good Afternoon, \(firstName)!")
                .font(.system(size: 26, weight: .heavy))
                .multilineTextAlignment(.center)
            Text(app.activeSport.category == .individual ? "\(app.activeSport.title) · MP Rating \(app.currentRating)" : "\(app.activeSport.title) · Peer rated by your squad")
                .font(.system(size: 12)).foregroundStyle(MP.ink3)
            ZStack {
                Circle().fill(MP.soft(app.activeSport)).frame(width: 250, height: 250)
                Circle().fill(MP.accent(app.activeSport).opacity(0.78)).frame(width: 66, height: 66).offset(x: -112, y: -62)
                Circle().fill(MP.accent(app.activeSport).opacity(0.48)).frame(width: 50, height: 50).offset(x: 112, y: -88)
                AvatarView(avatar: app.me.avatar, size: 218)
                    .overlay(Circle().stroke(.white, lineWidth: 6))
            }
            .frame(height: 282)
        }
        .padding(.top, 2)
    }

    private var firstName: String {
        app.me.name.split(separator: " ").first.map(String.init) ?? "player"
    }

    private func homeSection(
        _ title: String,
        action: String?,
        items: [Player],
        @ViewBuilder card: @escaping (Player, Int) -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MPSectionHeader(title: title, action: action)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, player in
                        Button { selectedPlayer = player } label: { card(player, index) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 24)
    }

    private var challengeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MPSectionHeader(title: app.activeSport.category == .group ? "Upcoming fixtures" : "Challenges", action: app.activeSport.category == .group ? "Calendar" : "See all")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(app.upcomingFaceOffs.prefix(4)) { match in
                        PersonPoster(player: app.player(match.opponentId) ?? players[0], sport: match.sport, line1: match.date.formatted(date: .abbreviated, time: .shortened), line2: match.venue, badge: match.state == .proposed ? "Needs a reply" : "Confirmed", badgeColor: MP.accent(match.sport))
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 24)
    }

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MPSectionHeader(title: "\(app.activeSport.title) near you")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(NativeCommunity.forSport(app.activeSport)) { club in
                        CommunityPoster(community: club, sport: app.activeSport)
                    }
                }
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
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(colors: [MP.soft(sport), .white], startPoint: .topLeading, endPoint: .bottomTrailing)
                MPAssetSportIcon(sport: sport, size: 82).opacity(0.14).offset(x: 54, y: 34)
                AvatarView(avatar: player.avatar, size: 112)
            }
            .frame(height: 124)
            VStack(alignment: .leading, spacing: 5) {
                Text(player.name).font(.system(size: 15.5, weight: .bold)).lineLimit(1)
                Text(line1).font(.system(size: 12)).foregroundStyle(MP.ink3).lineLimit(1)
                Text(line2).font(.system(size: 12)).foregroundStyle(MP.ink3).lineLimit(1)
                if let badge {
                    Text(badge).font(.system(size: 11, weight: .bold)).foregroundStyle(badgeColor)
                        .padding(.horizontal, 10).frame(height: 27)
                        .background(badgeColor.opacity(0.11), in: Capsule()).padding(.top, 3)
                }
            }
            .padding(13)
        }
        .frame(width: 172, height: 258, alignment: .topLeading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(MP.line, lineWidth: 1))
        .shadow(color: MP.shadow, radius: 8, y: 2)
    }
}

private struct NativeCommunity: Identifiable {
    let id = UUID()
    let name: String
    let kind: String
    let meta: String

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
                LinearGradient(colors: [MP.soft(sport), MP.accent(sport).opacity(0.28)], startPoint: .topLeading, endPoint: .bottomTrailing)
                MPAssetSportIcon(sport: sport, size: 92).opacity(0.2).offset(x: 120, y: 28)
                VStack(alignment: .leading, spacing: 8) {
                    Text(community.kind).font(.system(size: 10.5, weight: .bold)).foregroundStyle(MP.accent(sport))
                        .padding(.horizontal, 10).frame(height: 25).background(.white.opacity(0.94), in: Capsule())
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(0..<3) { _ in Circle().fill(.white.opacity(0.82)).frame(width: 17, height: 17) }
                    }
                }
                .padding(12)
            }
            .frame(height: 104)
            VStack(alignment: .leading, spacing: 6) {
                Text(community.name).font(.system(size: 15.5, weight: .bold)).lineLimit(1)
                Text(community.meta).font(.system(size: 12)).foregroundStyle(MP.ink3).lineLimit(1)
                Text(community.kind == "Facility" ? "View facility" : (community.kind == "Club" ? "Join community" : "Join league"))
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(MP.accent(sport))
                    .frame(maxWidth: .infinity).frame(height: 38)
                    .background(MP.soft(sport), in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(MP.accent(sport).opacity(0.22), lineWidth: 1))
            }
            .padding(13)
        }
        .frame(width: 236, height: 226)
        .background(.white).clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(MP.line, lineWidth: 1))
        .shadow(color: MP.shadow, radius: 8, y: 2)
    }
}

private struct NativeMapScreen: View {
    @EnvironmentObject private var app: AppState
    @State private var camera: MapCameraPosition = .region(.init(center: .init(latitude: 30.2672, longitude: -97.7431), span: .init(latitudeDelta: 0.16, longitudeDelta: 0.16)))
    @State private var gender: Gender?
    @State private var rating = "Any rating"
    @State private var selected: Player?

    private var players: [Player] {
        app.players.filter { player in
            guard player.profile(app.activeSport) != nil else { return false }
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
            Map(position: $camera) {
                Annotation("You", coordinate: .init(latitude: 30.2672, longitude: -97.7431)) {
                    Circle().fill(MP.accent(app.activeSport)).frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(color: MP.accent(app.activeSport).opacity(0.3), radius: 8)
                }
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    Annotation(player.name, coordinate: coordinate(index)) {
                        Button { selected = player } label: {
                            ZStack(alignment: .bottom) {
                                AvatarView(avatar: player.avatar, size: 48)
                                    .overlay(Circle().stroke(.white, lineWidth: 3))
                                    .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
                                Text("\(player.rating(app.activeSport))")
                                    .font(.system(size: 9, weight: .bold)).foregroundStyle(MP.accent(app.activeSport))
                                    .padding(.horizontal, 5).frame(height: 15).background(.white, in: Capsule()).offset(y: 5)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .environment(\.colorScheme, .light)
            .ignoresSafeArea(edges: .bottom)

            HStack(spacing: 8) {
                Menu {
                    Button("Any gender") { gender = nil }
                    ForEach(Gender.allCases) { value in Button(value.rawValue) { gender = value } }
                } label: { filterChip(gender?.rawValue ?? "Gender", icon: "person.2") }
                Menu {
                    ForEach(["Any rating", "Under 80", "80 to 110", "Above 110"], id: \.self) { value in Button(value) { rating = value } }
                } label: { filterChip(rating == "Any rating" ? "Rating" : rating, icon: "bolt") }
                if gender != nil || rating != "Any rating" {
                    Button("Clear filters") { gender = nil; rating = "Any rating" }
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(MP.ink2)
                        .padding(.horizontal, 13).frame(height: 36).background(.white, in: Capsule())
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
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

    private func filterChip(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(MP.ink3)
        }
        .font(.system(size: 12, weight: .semibold)).foregroundStyle(MP.ink)
        .padding(.horizontal, 13).frame(height: 36).background(.white, in: Capsule())
        .overlay(Capsule().stroke(MP.line, lineWidth: 1)).shadow(color: MP.shadow, radius: 4, y: 1)
    }
}

private struct NativeMatchesScreen: View {
    @EnvironmentObject private var app: AppState
    @State private var segment = "Past"
    @State private var selected: MatchRecord?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                MPSegmented(options: ["Past", "Upcoming"], selection: $segment)
                if segment == "Past" {
                    Text("This log combines scheduled matches and manually uploaded scores.")
                        .font(.system(size: 12)).foregroundStyle(MP.ink3).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(app.myMatches) { match in
                        Button { selected = match } label: { PastMatchCard(match: match) }.buttonStyle(.plain)
                    }
                } else {
                    WeeklyCalendar(sport: app.activeSport)
                    CalendarLegend(sport: app.activeSport)
                    MPPrimaryButton(title: "Add a Challenge", icon: "plus") {}
                }
                Color.clear.frame(height: 150)
            }
            .padding(.horizontal, 20)
        }
        .sheet(item: $selected) { record in NativeMatchDetail(record: record).presentationDetents([.medium]) }
    }
}

private struct NativeCalendarScreen: View {
    @EnvironmentObject private var app: AppState
    @State private var segment = "Week"

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                MPSegmented(options: ["Week", "Past matches"], selection: $segment)
                if segment == "Week" {
                    WeeklyCalendar(sport: app.activeSport)
                    CalendarLegend(sport: app.activeSport)
                    MPPrimaryButton(title: "Add to calendar", icon: "plus") {}
                    Text("You and your squad both add fixtures here. There are no challenges or score uploads in \(app.activeSport.title).")
                        .font(.system(size: 12)).foregroundStyle(MP.ink3).multilineTextAlignment(.center)
                } else {
                    ForEach(app.myMatches) { match in PastMatchCard(match: match) }
                }
                Color.clear.frame(height: 150)
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct MPSegmented: View {
    let options: [String]
    @Binding var selection: String
    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                Button(option) { selection = option }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(selection == option ? MP.ink : MP.ink3)
                    .frame(maxWidth: .infinity).frame(height: 38)
                    .background(selection == option ? .white : .clear, in: RoundedRectangle(cornerRadius: 11))
                    .shadow(color: selection == option ? MP.shadow : .clear, radius: 4, y: 1)
            }
        }
        .padding(3).background(MP.surface3, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct WeeklyCalendar: View {
    let sport: Sport
    private let hours = Array(7...22)
    private let days = ["M 10", "T 11", "W 12", "T 13", "F 14", "S 15", "S 16"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("August 2026").font(.system(size: 15.5, weight: .bold))
                Spacer()
                Button {} label: { Image(systemName: "chevron.left") }.calendarNav()
                Button("Today") {}.font(.system(size: 12, weight: .bold)).calendarNav(width: 58)
                Button {} label: { Image(systemName: "chevron.right") }.calendarNav()
            }
            .padding(.bottom, 12)

            HStack(spacing: 0) {
                Color.clear.frame(width: 38)
                ForEach(days, id: \.self) { day in
                    let today = day == "T 11"
                    VStack(spacing: 4) {
                        Text(day.prefix(1)).font(.system(size: 10, weight: .bold)).foregroundStyle(today ? MP.accent(sport) : MP.ink3)
                        Text(day.split(separator: " ").last ?? "")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(today ? .white : MP.ink)
                            .frame(width: 24, height: 24).background(today ? MP.accent(sport) : .clear, in: Circle())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 7)

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(hours, id: \.self) { hour in
                            Text(hourLabel(hour)).font(.system(size: 9)).foregroundStyle(MP.ink4)
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
    }

    private func calendarEvent(day: Int, start: Double, duration: Double, title: String, tentative: Bool) -> some View {
        GeometryReader { geo in
            let column = (geo.size.width - 38) / 7
            Text(title).font(.system(size: 8.5, weight: .bold)).lineLimit(3)
                .foregroundStyle(tentative ? MP.accent(sport) : .white)
                .padding(4).frame(width: column - 2, height: duration * 40, alignment: .topLeading)
                .background(tentative ? MP.soft(sport) : MP.accent(sport), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(tentative ? MP.accent(sport) : .clear, style: StrokeStyle(lineWidth: 1.2, dash: tentative ? [4, 3] : [])))
                .offset(x: 38 + CGFloat(day) * column + 1, y: CGFloat(start - 7) * 40)
        }
    }

    private func hourLabel(_ hour: Int) -> String { "\(hour > 12 ? hour - 12 : hour) \(hour >= 12 ? "PM" : "AM")" }
}

private extension View {
    func calendarNav(width: CGFloat = 34) -> some View {
        self.foregroundStyle(MP.ink2).frame(width: width, height: 32)
            .background(.white, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(MP.line, lineWidth: 1))
    }
}

private struct CalendarLegend: View {
    @EnvironmentObject private var app: AppState
    let sport: Sport
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            legend(MP.accent(sport), "\(sport.title), confirmed")
            legend(MP.soft(sport), "Awaiting a reply", border: MP.accent(sport))
            if let other = app.mySports.first(where: { $0 != sport }) { legend(MP.accent(other).opacity(0.3), other.title) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func legend(_ color: Color, _ title: String, border: Color = .clear) -> some View {
        HStack(spacing: 8) { RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 14, height: 14).overlay(RoundedRectangle(cornerRadius: 3).stroke(border)); Text(title).font(.system(size: 11)).foregroundStyle(MP.ink3) }
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
                        Text(match.ratingDelta > 0 ? "+\(match.ratingDelta)" : "\(match.ratingDelta)").font(.system(size: 17, weight: .heavy)).foregroundStyle(match.didWin ? Color(hex: "4CA85F") : MP.danger)
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
        Button(action: action) { Label(title, systemImage: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 50).background(MP.black, in: RoundedRectangle(cornerRadius: 16)) }
    }
}

private struct NativeMatchDetail: View {
    let record: MatchRecord
    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(MP.line).frame(width: 42, height: 5)
            AvatarView(avatar: record.opponentAvatar, size: 72)
            Text(record.didWin ? "Win against \(record.opponentName)" : "Loss to \(record.opponentName)").font(.system(size: 21, weight: .bold))
            Text(record.didWin ? "11–8, 11–6" : "8–11, 9–11").font(.system(size: 26, weight: .heavy)).foregroundStyle(record.didWin ? Color(hex: "4CA85F") : MP.danger)
            Text("\(record.date.formatted(date: .long, time: .omitted)) · \(record.venue)").font(.system(size: 13)).foregroundStyle(MP.ink3)
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

    private var conversations: [Conversation] {
        app.conversations.filter { conversation in
            conversation.sport == app.activeSport &&
            (segment == "Requests" ? conversation.isMessageRequest : !conversation.isMessageRequest)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                MPSegmented(options: ["Chats", "Requests"], selection: $segment)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(MP.ink4)
                    TextField("Search by name or username", text: $search).font(.system(size: 14))
                }
                .padding(.horizontal, 14).frame(height: 46).background(.white, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(MP.line))

                ForEach(conversations.filter { conversation in
                    guard !search.isEmpty, let player = app.player(conversation.partnerId) else { return search.isEmpty }
                    return player.name.localizedCaseInsensitiveContains(search) || player.username.localizedCaseInsensitiveContains(search)
                }) { conversation in
                    if let player = app.player(conversation.partnerId) {
                        Button { selectedConversation = conversation } label: {
                            HStack(spacing: 12) {
                                AvatarView(avatar: player.avatar, size: 46)
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
        .fullScreenCover(item: $selectedConversation) { conversation in
            NativeChatScreen(conversation: conversation)
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

private struct NativeChatScreen: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let conversation: Conversation
    @State private var draft = ""

    private var player: Player? { app.player(conversation.partnerId) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).frame(width: 36, height: 36).background(.white, in: Circle()).overlay(Circle().stroke(MP.line)) }
                if let player { AvatarView(avatar: player.avatar, size: 36) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(player?.name ?? "Conversation").font(.system(size: 15.5, weight: .bold))
                    Text(player?.username ?? "").font(.system(size: 11)).foregroundStyle(MP.ink3)
                }
                Spacer()
                if app.activeSport.category == .individual {
                    Button {} label: { Image(systemName: "trophy").frame(width: 36, height: 36).background(.white, in: Circle()).overlay(Circle().stroke(MP.line)) }
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 10)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if conversation.isMessageRequest {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "link")
                            Text("Start a conversation and wait for their response before sending your first challenge.")
                        }
                        .font(.system(size: 12)).foregroundStyle(MP.ink2).padding(12).background(MP.surface2, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Text("Today").font(.system(size: 10, weight: .bold)).foregroundStyle(MP.ink4).padding(.vertical, 8)
                    ForEach(conversation.messages) { message in
                        HStack {
                            if message.fromMe { Spacer(minLength: 70) }
                            Text(messageText(message))
                                .font(.system(size: 14)).foregroundStyle(message.fromMe ? .white : MP.ink)
                                .padding(.horizontal, 13).padding(.vertical, 10)
                                .background(message.fromMe ? MP.accent(app.activeSport) : .white, in: RoundedRectangle(cornerRadius: 17))
                                .overlay(RoundedRectangle(cornerRadius: 17).stroke(message.fromMe ? .clear : MP.line))
                            if !message.fromMe { Spacer(minLength: 70) }
                        }
                    }
                }
                .padding(20)
            }
            .background(MP.background)

            HStack(spacing: 9) {
                TextField("Write a message", text: $draft)
                    .padding(.horizontal, 14).frame(height: 44).background(.white, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(MP.line))
                Button { draft = "" } label: { Image(systemName: "paperplane.fill").foregroundStyle(.white).frame(width: 44, height: 44).background(MP.accent(app.activeSport), in: Circle()) }
            }
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 26).background(.white.opacity(0.94))
        }
        .foregroundStyle(MP.ink).preferredColorScheme(.light)
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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 7) {
                    AvatarView(avatar: app.me.avatar, size: 84)
                        .overlay(Circle().stroke(.white, lineWidth: 4))
                        .shadow(color: MP.shadow, radius: 8, y: 2)
                    Text(app.me.name.isEmpty ? "Your name" : app.me.name).font(.system(size: 21, weight: .bold))
                    Text("@\(app.me.username) · \(app.me.age) · \(app.me.gender.rawValue)").font(.system(size: 12)).foregroundStyle(MP.ink3)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(app.mySports) { sport in
                                Button { app.activeSport = sport } label: {
                                    HStack(spacing: 5) { MPAssetSportIcon(sport: sport, size: 15); Text(sport.title) }
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(app.activeSport == sport ? MP.accent(sport) : MP.ink3)
                                        .padding(.horizontal, 12).frame(height: 36)
                                        .background(app.activeSport == sport ? MP.soft(sport) : .white, in: Capsule())
                                        .overlay(Capsule().stroke(app.activeSport == sport ? MP.accent(sport).opacity(0.24) : MP.line))
                                }
                            }
                        }
                    }
                }
                .padding(.top, 6)

                ratingCard
                MPSectionHeader(title: "\(app.activeSport.title) statistics")
                HStack(spacing: 10) {
                    statistic("\(app.myMatches.count)", app.activeSport.category == .group ? "Fixtures" : "Matches")
                    statistic("\(app.wins)", "Wins", color: MP.accent(app.activeSport))
                    statistic("\(Int(app.winPct))%", "Win rate")
                }
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
            MPCard {
                VStack(alignment: .leading, spacing: 11) {
                    Text("PEER SKILL EVALUATION").font(.system(size: 10.5, weight: .heavy)).tracking(1).foregroundStyle(MP.ink3)
                    ForEach(profile?.peerSkillRatings ?? []) { skill in
                        VStack(spacing: 5) {
                            HStack { Text(skill.category).font(.system(size: 14, weight: .semibold)); Spacer(); stars(skill.average); Text(String(format: "%.1f", skill.average)).font(.system(size: 13, weight: .bold)) }
                            GeometryReader { geo in Capsule().fill(MP.surface3).overlay(alignment: .leading) { Capsule().fill(MP.accent(app.activeSport)).frame(width: geo.size.width * skill.average / 5) } }.frame(height: 5)
                        }
                    }
                }
            }
        } else {
            MPCard {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("MP RATING").font(.system(size: 10.5, weight: .heavy)).tracking(1).foregroundStyle(MP.ink3)
                            Text(profile?.usesElo == true ? "\(profile?.rating ?? 80)" : "Unrated").font(.system(size: 40, weight: .heavy)).foregroundStyle(MP.accent(app.activeSport))
                            Text("Everyone starts at 80 and moves in small steps.").font(.system(size: 12)).foregroundStyle(MP.ink3)
                        }
                        Spacer(); MPAssetSportIcon(sport: app.activeSport, size: 50).opacity(0.6)
                    }
                    Divider().overlay(MP.line)
                    Text("How the MP Rating works").font(.system(size: 13, weight: .bold)).foregroundStyle(MP.accent(app.activeSport))
                }
            }
        }
    }

    private func statistic(_ value: String, _ label: String, color: Color = MP.ink) -> some View {
        VStack(spacing: 4) { Text(value).font(.system(size: 25, weight: .heavy)).foregroundStyle(color); Text(label).font(.system(size: 11)).foregroundStyle(MP.ink3) }
            .frame(maxWidth: .infinity).padding(.vertical, 14).background(.white, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(MP.line))
    }

    private var ratingTrend: some View {
        VStack(alignment: .leading, spacing: 12) {
            MPSectionHeader(title: "Rating trend")
            MPCard {
                Chart(app.ratingHistory) { point in
                    AreaMark(x: .value("Date", point.date), y: .value("Rating", point.rating)).foregroundStyle(MP.soft(app.activeSport))
                    LineMark(x: .value("Date", point.date), y: .value("Rating", point.rating)).foregroundStyle(MP.accent(app.activeSport)).lineStyle(.init(lineWidth: 2.4, lineCap: .round))
                }
                .chartXAxis(.hidden).frame(height: 90)
            }
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
            MPCard {
                VStack(spacing: 0) {
                    ForEach(["Edit profile details", "Manage your sports", "Privacy and visibility", "Notification preferences"], id: \.self) { title in
                        HStack { Image(systemName: "gearshape").foregroundStyle(MP.ink4); Text(title).font(.system(size: 14, weight: .semibold)); Spacer(); Image(systemName: "chevron.right").foregroundStyle(MP.ink4) }
                            .frame(height: 50)
                        Divider().overlay(MP.line)
                    }
                    HStack { Image(systemName: "nosign"); Text("Reset this account").font(.system(size: 14, weight: .semibold)); Spacer() }.foregroundStyle(MP.danger).frame(height: 50)
                }
            }
        }
    }

    private func stars(_ value: Double) -> some View {
        HStack(spacing: 2) { ForEach(1...5, id: \.self) { index in Image(systemName: Double(index) <= value.rounded() ? "star.fill" : "star").font(.system(size: 10)).foregroundStyle(MP.accent(app.activeSport)) } }
    }
}

private struct NativeNotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Label("Elena sent a connection request.", systemImage: "person.badge.plus")
                Label("Your score is ready to verify.", systemImage: "checkmark.seal")
                Label("A challenge time was proposed.", systemImage: "calendar")
                Label("Your rating moved up three points.", systemImage: "chart.line.uptrend.xyaxis")
            }
            .navigationTitle("Notifications")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { dismiss() } label: { Image(systemName: "xmark") } } }
        }
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
                                        .foregroundStyle(MP.ink).padding(8).background(opponent == player.id ? MP.soft(app.activeSport) : .white, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(opponent == player.id ? MP.accent(app.activeSport) : MP.line))
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
                    TextField("Venue", text: $venue).padding(.horizontal, 14).frame(height: 48).background(.white, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(MP.line))
                    MPPrimaryButton(title: "Send the Challenge", icon: "paperplane") { dismiss() }.opacity(opponent == nil ? 0.45 : 1).disabled(opponent == nil)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(MP.background).foregroundStyle(MP.ink).preferredColorScheme(.light)
    }

    private func fieldLabel(_ value: String) -> some View { Text(value.uppercased()).font(.system(size: 11, weight: .heavy)).tracking(0.8).foregroundStyle(MP.ink3) }
    private func choice(_ value: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(value).font(.system(size: 12, weight: .bold)).foregroundStyle(selected ? MP.accent(app.activeSport) : MP.ink2).padding(.horizontal, 12).frame(height: 38).background(selected ? MP.soft(app.activeSport) : .white, in: Capsule()).overlay(Capsule().stroke(selected ? MP.accent(app.activeSport) : MP.line)) }
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
        Button(action: action) { Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(selected ? .white : MP.ink2).frame(maxWidth: .infinity).frame(height: 40).background(selected ? MP.accent(app.activeSport) : MP.surface2, in: RoundedRectangle(cornerRadius: 12)) }
    }
}
