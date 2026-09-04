import SwiftUI
import MapKit
import Charts

/// A native, screen-for-screen translation of Sashank's 8/17 React prototype.
/// This view intentionally owns its shell instead of inheriting the older app UI.
struct SashankMainView: View {
    @EnvironmentObject private var app: AppState
    @State private var tab: Tab = .home
    @State private var fabOpen = false
    @State private var globalPage: GlobalPage?
    @State private var seenIncomingMessageIDs: Set<UUID> = []
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
        case profile = "Profile"
    }

    private enum GlobalPage {
        case chats
        case notifications
    }

    private var title: String {
        if tab == .matches, app.activeSport.category == .group { return "Calendar" }
        return tab.rawValue
    }

    var body: some View {
        ZStack {
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

            if let globalPage {
                Group {
                    switch globalPage {
                    case .chats:
                        NativeChatsScreen(onBack: closeGlobalPage)
                    case .notifications:
                        NativeNotificationsPage(onBack: closeGlobalPage)
                    }
                }
                .transition(.move(edge: .trailing))
                .zIndex(20)
            }
        }
        .foregroundStyle(MP.ink)
        .tint(MP.accent(app.activeSport))
        .preferredColorScheme(.light)
        .onAppear {
            let supportedSports = app.mySports.filter(\.isAvailableInBeta)
            if supportedSports != app.mySports {
                app.mySports = supportedSports.isEmpty ? [.pickleball] : supportedSports
                app.me.profiles = app.me.profiles.filter { $0.key.isAvailableInBeta }
                if !app.mySports.contains(app.activeSport) { app.activeSport = app.mySports[0] }
            }
#if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let flag = args.firstIndex(of: "-demo-sport"),
               args.indices.contains(flag + 1),
               let sport = Sport(rawValue: args[flag + 1]),
               app.mySports.contains(sport) {
                app.activeSport = sport
            }
            if args.contains("-demo-calendar") {
                app.activeSport = .cricket
                tab = .matches
            }
            if args.contains("-demo-profile") { tab = .profile }
            if args.contains("-demo-map") { tab = .map }
            if args.contains("-demo-matches") { tab = .matches }
            if args.contains("-demo-chats")
                || args.contains("-demo-chat")
                || args.contains("-demo-native-thread") { globalPage = .chats }
            if args.contains("-demo-home") { tab = .home }
            if args.contains("-demo-sports") { showSports = true }
            if args.contains("-demo-notifications") { globalPage = .notifications }
            if args.contains("-demo-score-upload") { showScore = true }
            if args.contains("-demo-quick-challenge") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { showChallenge = true }
            }
#endif
        }
        .sheet(isPresented: $showScore) {
            SashankScoreUploadSheet { showScore = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showChallenge) {
            SashankQuickChallengeSheet()
                .presentationDetents([.height(680)])
                .presentationDragIndicator(.hidden)
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
            case .home: NativeHomeScreen(
                openTab: { tab = $0 },
                switchSport: requestSportChange
            )
            case .profile: NativeProfileScreen()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appBar: some View {
        HStack(spacing: 10) {
            Button { withAnimation(.easeOut(duration: 0.16)) { showSports.toggle() } } label: {
                HStack(spacing: 7) {
                    MPLineSportIcon(sport: app.activeSport, size: 27)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MP.ink3)
                }
                .frame(width: 68, height: 48)
                .background(RallyPalette.cream.opacity(0.96), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Switch sport. Current sport: \(app.activeSport.title)")
            .accessibilityHint("Shows your available sports")

            Spacer()

            HStack(spacing: 8) {
                Button { openGlobalPage(.notifications) } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 19, weight: .semibold))
                        .overlay(alignment: .topTrailing) {
                            if app.notificationCount > 0 { unreadDot }
                        }
                        .frame(width: 46, height: 46)
                        .background(RallyPalette.cream.opacity(0.96), in: Circle())
                }
                .buttonStyle(RallyPressStyle())
                .accessibilityLabel(app.notificationCount == 0 ? "Notifications" : "Notifications, unread items")

                Button { openGlobalPage(.chats) } label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: 19, weight: .semibold))
                        .overlay(alignment: .topTrailing) {
                            if hasUnreadChatMessages { unreadDot }
                        }
                        .frame(width: 46, height: 46)
                        .background(RallyPalette.cream.opacity(0.96), in: Circle())
                }
                .buttonStyle(RallyPressStyle())
                .accessibilityLabel(hasUnreadChatMessages ? "Chats, unread messages" : "Chats")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var unreadDot: some View {
        Circle()
            .fill(MP.accent(app.activeSport))
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(MP.background, lineWidth: 1.5))
            .offset(x: 1, y: -1)
    }

    private var incomingMessageIDs: Set<UUID> {
        Set(app.conversations.compactMap { conversation in
            guard !conversation.isMessageRequest,
                  let last = conversation.lastMessage,
                  !last.fromMe else { return nil }
            return last.id
        })
    }

    private var hasUnreadChatMessages: Bool {
        if app.hasHydratedBackend { return !app.unreadConversationIDs.isEmpty }
        return !incomingMessageIDs.subtracting(seenIncomingMessageIDs).isEmpty
    }

    private func openGlobalPage(_ page: GlobalPage) {
        showSports = false
        if page == .chats {
            seenIncomingMessageIDs.formUnion(incomingMessageIDs)
            app.markAllConversationsRead()
        }
        withAnimation(.easeOut(duration: 0.28)) { globalPage = page }
    }

    private func closeGlobalPage() {
        withAnimation(.easeIn(duration: 0.24)) { globalPage = nil }
    }

    private var sportDropdown: some View {
        VStack(spacing: 8) {
            ForEach(app.mySports.filter { $0 != app.activeSport }) { sport in
                Button {
                    requestSportChange(sport)
                    showSports = false
                } label: {
                    MPAssetSportIcon(sport: sport, size: 34)
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sport.title)
            }
        }
        .padding(8)
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
            .background(tab == item ? MP.accent(app.activeSport) : .clear, in: Capsule())
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
                    fabOption("Add a game", "calendar.badge.plus") { fabOpen = false; showFixture = true }
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
        sport.rallyAccent
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
        SportIcon(sport: sport, size: size, color: MP.ink)
    }
}

private struct MPLineSportIcon: View {
    let sport: Sport
    var size: CGFloat

    var body: some View {
        SportIcon(sport: sport, size: size, color: MP.ink)
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
    var actionHandler: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .black))
                .tracking(1.35)
                .textCase(.uppercase)
                .foregroundStyle(MP.ink)
            Spacer()
            if let action {
                if let actionHandler {
                    Button(action: actionHandler) {
                        HStack(spacing: 4) {
                            Text(action)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .black))
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MP.ink)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(action).font(.system(size: 12, weight: .bold)).foregroundStyle(MP.ink)
                }
            }
        }
    }
}

private struct NativeHomeScreen: View {
    @EnvironmentObject private var app: AppState
    let openTab: (SashankMainView.Tab) -> Void
    let switchSport: (Sport) -> Void
    @State private var selectedPlayer: Player?
    @State private var selectedVerification: FaceOff?
    @State private var selectedRequest: Player?
    @State private var selectedChallenge: FaceOff?
    @State private var selectedGroupFixture: GroupFixture?
    @State private var selectedCommunity: NearbyCommunity?
    @State private var notice: String?
    @State private var displayedRating = 0
    @State private var showAllVerifications = false
    @State private var showAllRequests = false
    @State private var showAllChallenges = false
    private let sectionHeaderSpacing: CGFloat = 8
    private let sectionContentTopInset: CGFloat = 8

    private var players: [Player] { app.players.filter { $0.profile(app.activeSport) != nil } }
    private var verifications: [FaceOff] {
        app.faceOffs.filter {
            $0.sport == app.activeSport && $0.state == .awaitingResult && $0.reportedWinnerByThem != nil
        }
    }
    private var requestPlayers: [Player] {
        app.players.filter { app.incomingFriendRequestIds.contains($0.id) && $0.profile(app.activeSport) != nil }
    }
    private var activeChallenges: [FaceOff] {
        app.faceOffs.filter {
            $0.sport == app.activeSport && [.proposed, .confirmed].contains($0.state) && $0.date > Date().addingTimeInterval(-21_600)
        }
        .sorted { lhs, rhs in
            let lhsRank = lhs.state == .proposed && !lhs.proposedByMe ? 0 : (lhs.state == .proposed ? 1 : 2)
            let rhsRank = rhs.state == .proposed && !rhs.proposedByMe ? 0 : (rhs.state == .proposed ? 1 : 2)
            return lhsRank == rhsRank ? lhs.date < rhs.date : lhsRank < rhsRank
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    hero
                    if !verifications.isEmpty {
                        faceOffSection("Verifications", action: "\(verifications.count) waiting", actionHandler: { showAllVerifications = true }, items: verifications) { faceOff in
                            selectedVerification = faceOff
                        }
                    }
                    if !requestPlayers.isEmpty {
                        requestSection
                    }
                    if app.activeSport.category == .group {
                        groupFixtureSection
                    } else if !activeChallenges.isEmpty {
                        challengeSection
                    }
                    homeSection(app.activeSport.category == .group ? "Players in your area" : "Recommended opponents", action: "Open map", items: Array(players.dropFirst(1).prefix(8))) { player, _ in
                        PersonPoster(player: player, sport: app.activeSport, line1: "\(String(format: "%.1f", player.distanceMiles)) miles away", line2: player.compactAvailability, badge: nil, badgeColor: MP.accent(app.activeSport))
                    } actionHandler: { openTab(.map) }
                    communitySection.id("community")
                    Color.clear.frame(height: 150)
                }
            }
            .sheet(item: $selectedPlayer) {
                ProfileDetailView(player: $0).presentationDragIndicator(.hidden)
            }
            .sheet(item: $selectedVerification) { NativeVerificationDetail(faceOff: $0) }
            .sheet(item: $selectedRequest) { NativeConnectionRequestDetail(player: $0) }
            .sheet(item: $selectedChallenge) { NativeChallengeDetail(faceOff: $0) }
            .sheet(item: $selectedGroupFixture) { GroupFixtureDetail(fixture: $0) }
            .sheet(item: $selectedCommunity) { CommunityHubSheet(community: $0) }
            .sheet(isPresented: $showAllVerifications) { NativeVerificationsSheet() }
            .sheet(isPresented: $showAllRequests) { NativeConnectionRequestsSheet() }
            .sheet(isPresented: $showAllChallenges) { NativeChallengesSheet() }
            .overlay(alignment: .top) {
                if let notice {
                    Text(notice).font(RallyType.caption).foregroundStyle(RallyPalette.cream)
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .background(MP.ink, in: Capsule()).padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { withAnimation { self.notice = nil } }
                }
            }
            .onAppear {
#if DEBUG
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("-demo-player-sheet") {
                    selectedPlayer = players.first
                }
                if arguments.contains("-demo-verification-sheet") {
                    selectedVerification = verifications.first
                }
                if arguments.contains("-demo-all-verifications") {
                    showAllVerifications = true
                }
                if arguments.contains("-demo-all-requests") {
                    showAllRequests = true
                }
                if arguments.contains("-demo-all-challenges") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        showAllChallenges = true
                    }
                }
                if arguments.contains("-demo-request-detail") {
                    selectedRequest = requestPlayers.first
                }
                if arguments.contains("-demo-community") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        proxy.scrollTo("community", anchor: .top)
                    }
                }
#endif
            }
        }
    }

    private var hero: some View {
        PremiumAvatarHero(
            avatar: app.me.avatar,
            sport: app.activeSport,
            name: app.me.firstName,
            rating: displayedRating
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, RallyLayout.gutter)
        .padding(.top, 12)
        .task(id: app.activeSport) {
            await playRatingChange()
        }
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
        @ViewBuilder card: @escaping (Player, Int) -> some View,
        actionHandler: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
            MPSectionHeader(title: title, action: action, actionHandler: actionHandler)
                .padding(.horizontal, RallyLayout.gutter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, player in
                        Button { selectedPlayer = player } label: { card(player, index) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, RallyLayout.gutter)
                .padding(.top, sectionContentTopInset)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 24)
    }

    private var challengeSection: some View {
        return VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
            MPSectionHeader(
                title: app.activeSport.category == .group ? "Upcoming games" : "Challenges",
                action: app.activeSport.category == .group ? "Calendar" : "See all",
                actionHandler: {
                    if app.activeSport.category == .group {
                        openTab(.matches)
                    } else {
                        showAllChallenges = true
                    }
                }
            )
                .padding(.horizontal, RallyLayout.gutter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(activeChallenges.prefix(4)) { match in
                        Button { selectedChallenge = match } label: {
                            PersonPoster(player: app.player(match.opponentId) ?? players[0], sport: match.sport, line1: match.date.formatted(date: .abbreviated, time: .shortened), line2: match.venue, badge: match.state == .proposed ? (match.proposedByMe ? "Awaiting reply" : "Needs your reply") : nil, badgeColor: MP.accent(match.sport), reservesBadgeSpace: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, RallyLayout.gutter)
                .padding(.top, sectionContentTopInset)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 24)
    }

    private var requestSection: some View {
        VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
            MPSectionHeader(title: "Connection requests", action: "See all", actionHandler: { showAllRequests = true })
                .padding(.horizontal, RallyLayout.gutter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(requestPlayers) { player in
                        Button { selectedRequest = player } label: {
                            PersonPoster(
                                player: player,
                                sport: app.activeSport,
                                line1: requestPreview(for: player),
                                line2: "@\(displayUsername(for: player)) · \(String(format: "%.1f", player.distanceMiles)) mi",
                                badge: nil,
                                badgeColor: MP.accent(app.activeSport)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, RallyLayout.gutter)
                .padding(.top, sectionContentTopInset)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 24)
    }

    private var groupFixtureSection: some View {
        let fixtures = app.groupFixtures
            .filter { $0.sport == app.activeSport && $0.date >= .now }
            .sorted { $0.date < $1.date }
        return Group {
            if !fixtures.isEmpty {
                VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
                    HStack {
                        Text("Upcoming games").font(RallyType.eyebrow).tracking(1.6).textCase(.uppercase).foregroundStyle(MP.ink3)
                        Spacer()
                        Button { openTab(.matches) } label: {
                            HStack(spacing: 4) {
                                Text("Calendar")
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .black))
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MP.ink3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, RallyLayout.gutter)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(fixtures) { fixture in
                                Button { selectedGroupFixture = fixture } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        RallySportTag(sport: fixture.sport)
                                        Text(fixture.opponent).font(RallyType.cardTitle).foregroundStyle(MP.ink).lineLimit(2)
                                        Text(fixture.title).font(RallyType.caption).foregroundStyle(MP.ink3).lineLimit(2)
                                        Spacer()
                                        Text(fixture.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11, weight: .bold))
                                        Text(fixture.venue).font(.system(size: 10)).foregroundStyle(MP.ink3).lineLimit(2)
                                    }
                                    .padding(12).frame(width: 140, height: 208, alignment: .leading)
                                    .background(MP.surface, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius))
                                    .overlay(RoundedRectangle(cornerRadius: RallyLayout.cardRadius).stroke(MP.strongLine))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, RallyLayout.gutter)
                        .padding(.top, sectionContentTopInset)
                        .padding(.bottom, 8)
                    }
                }
                .padding(.top, 24)
            }
        }
    }

    private func faceOffSection(
        _ title: String,
        action: String?,
        actionHandler: (() -> Void)? = nil,
        items: [FaceOff],
        select: @escaping (FaceOff) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
            MPSectionHeader(title: title, action: action, actionHandler: actionHandler)
                .padding(.horizontal, RallyLayout.gutter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { faceOff in
                        if let player = app.player(faceOff.opponentId) {
                            Button { select(faceOff) } label: {
                                PersonPoster(
                                    player: player,
                                    sport: faceOff.sport,
                                    line1: scoreSummary(faceOff),
                                    line2: faceOff.date.formatted(date: .abbreviated, time: .omitted),
                                    badge: nil,
                                    badgeColor: MP.accent(faceOff.sport)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, RallyLayout.gutter)
                .padding(.top, sectionContentTopInset)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 24)
    }

    private func scoreSummary(_ faceOff: FaceOff) -> String {
        let mine = faceOff.gameScores.filter(\.iWon).count
        let theirs = faceOff.gameScores.count - mine
        return "Singles · \(mine)–\(theirs) games"
    }

    @MainActor
    private func playRatingChange() async {
        let current = app.me.rating(app.activeSport)
        let start = displayedRating == 0 ? max(0, current - 8) : displayedRating
        displayedRating = start
        try? await Task.sleep(for: .milliseconds(220))

        let difference = current - start
        guard difference != 0 else {
            withAnimation(.snappy(duration: 0.25)) { displayedRating = current }
            return
        }

        let direction = difference > 0 ? 1 : -1
        for value in stride(from: start + direction, through: current, by: direction) {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(135))
            withAnimation(.snappy(duration: 0.2)) {
                displayedRating = value
            }
        }
        displayedRating = current
    }

    private func requestPreview(for player: Player) -> String {
        guard let message = app.conversation(with: player.id)?.lastMessage else { return "Sent you a connection request" }
        if case let .text(value) = message.kind { return value }
        return "Sent you a connection request"
    }

    private func displayUsername(for player: Player) -> String {
        let value = player.username.replacingOccurrences(of: "@", with: "")
        return value.isEmpty ? player.name.lowercased().replacingOccurrences(of: " ", with: "_") : value
    }

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: sectionHeaderSpacing) {
            MPSectionHeader(
                title: "Courts and clubs near you",
                action: app.isRefreshingCommunities ? "Finding nearby…" : nil
            )
                .padding(.horizontal, RallyLayout.gutter)
            if app.nearbyCommunities.isEmpty && !app.isRefreshingCommunities {
                VStack(alignment: .leading, spacing: 7) {
                    Text("No nearby courts loaded yet.").font(RallyType.cardTitle)
                    Text("Allow location access and pull this screen open again to find courts from Apple Maps.")
                        .font(RallyType.caption).foregroundStyle(MP.ink3)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MP.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(MP.strongLine))
                .padding(.horizontal, RallyLayout.gutter)
                .padding(.top, sectionContentTopInset)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(app.nearbyCommunities) { community in
                            BackendCommunityPoster(community: community, sport: app.activeSport) {
                                selectedCommunity = community
                            }
                        }
                    }
                    .padding(.horizontal, RallyLayout.gutter)
                    .padding(.top, sectionContentTopInset)
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(.top, 24)
    }
}

private struct BackendCommunityPoster: View {
    let community: NearbyCommunity
    let sport: Sport
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RallyPhoto(name: ImageCatalog.courtKey(for: sport))
                        .frame(width: 190, height: 112)
                    LinearGradient(colors: [.clear, .black.opacity(0.34)], startPoint: .top, endPoint: .bottom)
                    HStack {
                        Text(community.isClub ? "CLUB" : "COURT").rallyEyebrow(.white)
                        Spacer()
                        RallySportAssetIcon(sport: sport, size: 26)
                            .frame(width: 38, height: 38)
                            .background(MP.background.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(12).frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(width: 190, height: 112)
                .clipped()
                VStack(alignment: .leading, spacing: 7) {
                    Text(community.name)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(MP.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(String(format: "%.1f", community.distanceMiles)) mi · \(community.city.isEmpty ? "Nearby" : community.city)")
                        .font(RallyType.caption).foregroundStyle(MP.ink3).lineLimit(1)
                    if community.isClub {
                        Text("\(community.memberCount) members · \(community.groupCount) groups")
                            .font(RallyType.caption).foregroundStyle(MP.ink3)
                    } else {
                        Text("Create the first club here")
                            .font(RallyType.caption).foregroundStyle(MP.ink3).lineLimit(2)
                    }
                }
                .padding(12)
            }
            .frame(width: 190, height: 220, alignment: .topLeading)
            .background(MP.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(MP.strongLine, lineWidth: 1.2))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(RallyPressStyle())
    }
}

private struct CommunityHubSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var community: NearbyCommunity
    @State private var detail: CommunityDetailSnapshot?
    @State private var clubName = ""
    @State private var clubDescription = ""
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var isWorking = false
    @State private var message: String?

    init(community: NearbyCommunity) { _community = State(initialValue: community) }

    var body: some View {
        VStack(spacing: 0) {
            MPStickySheetHeader(title: "Facility details", dismiss: { dismiss() })
            Divider().overlay(MP.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(community.name)
                            .font(.system(size: 24, weight: .bold))
                        Text(community.locationLine.isEmpty ? "\(String(format: "%.1f", community.distanceMiles)) miles away" : community.locationLine)
                            .font(RallyType.body()).foregroundStyle(MP.ink3)
                    }

                    Text(community.description.isEmpty ? "A nearby \(app.activeSport.title.lowercased()) facility for local play." : community.description)
                        .font(RallyType.body())
                        .foregroundStyle(MP.ink2)
                        .lineSpacing(3)

                    Map(
                        initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: community.latitude, longitude: community.longitude),
                            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                        )),
                        interactionModes: []
                    ) {
                        Marker(community.name, coordinate: CLLocationCoordinate2D(latitude: community.latitude, longitude: community.longitude))
                            .tint(MP.accent(app.activeSport))
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: RallyLayout.cardRadius).stroke(MP.strongLine, lineWidth: 1))
                    .allowsHitTesting(false)

                    VStack(spacing: 0) {
                        comingSoonRow("Members")
                        Divider().overlay(MP.line)
                        comingSoonRow("Groups")
                    }
                    .padding(.horizontal, 16)
                    .background(MP.surface2.opacity(0.55), in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))

                    if let bookingURL = community.bookingURL.flatMap(URL.init(string:)) {
                        Link(destination: bookingURL) {
                            HStack {
                                Text("Book a court")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(RallyType.action)
                            .foregroundStyle(MP.background)
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(MP.ink, in: Capsule())
                        }
                    } else if let websiteURL = community.websiteURL.flatMap(URL.init(string:)) {
                        Link(destination: websiteURL) {
                            HStack {
                                Text("Visit facility website")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(RallyType.action)
                            .foregroundStyle(MP.background)
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(MP.ink, in: Capsule())
                        }
                    }
                }
                .padding(20).padding(.bottom, 40)
            }
        }
        .background(MP.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func comingSoonRow(_ title: String) -> some View {
        HStack {
            Text(title).font(RallyType.body(16, weight: .semibold))
            Spacer()
            Text("Coming soon").font(RallyType.caption).foregroundStyle(MP.ink3)
        }
        .frame(minHeight: 54)
    }

    @ViewBuilder private var memberSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MEMBERS").rallyEyebrow(MP.ink3)
            if let members = detail?.members, !members.isEmpty {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        AvatarView(avatar: member.avatar, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName).font(RallyType.cardTitle)
                            Text("@\(member.username) · \(member.role.capitalized)")
                                .font(RallyType.caption).foregroundStyle(MP.ink3)
                        }
                    }
                }
            } else {
                Text("Be the first member to join.").font(RallyType.body()).foregroundStyle(MP.ink3)
            }
        }
    }

    private func groupSection(clubID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GROUPS").rallyEyebrow(MP.ink3)
            ForEach(detail?.groups ?? []) { group in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.name).font(RallyType.cardTitle)
                        Text("\(group.memberCount) members\(group.description.isEmpty ? "" : " · \(group.description)")")
                            .font(RallyType.caption).foregroundStyle(MP.ink3).lineLimit(2)
                    }
                    Spacer()
                    Button(group.isMember ? "Leave" : "Join") {
                        Task { await toggleGroup(group) }
                    }
                    .font(RallyType.action).buttonStyle(.bordered)
                }
                .padding(14).background(MP.surface, in: RoundedRectangle(cornerRadius: 16))
            }
            if community.isMember {
                TextField("New group name", text: $groupName)
                    .textFieldStyle(.plain).padding(15).background(MP.surface, in: Capsule())
                TextField("What is this group for?", text: $groupDescription, axis: .vertical)
                    .textFieldStyle(.plain).padding(15).background(MP.surface, in: RoundedRectangle(cornerRadius: 18))
                Button("Create group") { Task { await createGroup(clubID) } }
                    .font(RallyType.action).disabled(groupName.trimmingCharacters(in: .whitespaces).count < 2 || isWorking)
            }
        }
    }

    private var createClubSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("START A CLUB HERE").rallyEyebrow(MP.ink3)
            Text("Create a home for players who use this court. You will become the club owner.")
                .font(RallyType.body()).foregroundStyle(MP.ink3)
            TextField("Club name", text: $clubName)
                .textFieldStyle(.plain).padding(15).background(MP.surface, in: Capsule())
            TextField("Short description", text: $clubDescription, axis: .vertical)
                .textFieldStyle(.plain).padding(15).background(MP.surface, in: RoundedRectangle(cornerRadius: 18))
            Button("Create club") { Task { await createClub() } }
                .font(RallyType.action).foregroundStyle(MP.background)
                .frame(maxWidth: .infinity, minHeight: 52).background(MP.ink, in: Capsule())
                .disabled(clubName.trimmingCharacters(in: .whitespaces).count < 2 || isWorking)
        }
    }

    private func loadDetail() async {
        guard let clubID = community.clubID else { return }
        detail = await app.communityDetail(clubID: clubID)
    }

    private func toggleClub(_ clubID: UUID) async {
        isWorking = true; defer { isWorking = false }
        if await app.setClubMembership(clubID: clubID, join: !community.isMember) {
            community.isMember.toggle()
            await loadDetail()
        }
    }

    private func createClub() async {
        isWorking = true; defer { isWorking = false }
        if let clubID = await app.createClub(at: community.courtID, name: clubName, description: clubDescription) {
            community = NearbyCommunity(
                courtID: community.courtID, clubID: clubID, name: clubName,
                description: clubDescription, address: community.address, city: community.city,
                distanceMiles: community.distanceMiles, latitude: community.latitude,
                longitude: community.longitude, memberCount: 1, groupCount: 0, isMember: true
            )
            await loadDetail()
        }
    }

    private func createGroup(_ clubID: UUID) async {
        isWorking = true; defer { isWorking = false }
        if await app.createCommunityGroup(clubID: clubID, name: groupName, description: groupDescription) != nil {
            groupName = ""; groupDescription = ""; await loadDetail()
        }
    }

    private func toggleGroup(_ group: CommunityGroup) async {
        isWorking = true; defer { isWorking = false }
        if await app.setCommunityGroupMembership(groupID: group.id, join: !group.isMember) { await loadDetail() }
    }
}

private struct NativeVerificationDetail: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let faceOff: FaceOff

    private var player: Player? { app.player(faceOff.opponentId) }

    var body: some View {
        VStack(spacing: 0) {
            MPStickySheetHeader(title: "Verify result", dismiss: { dismiss() })
            Divider().overlay(MP.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                if let player {
                    HStack(spacing: 14) {
                        RallyPlayerAvatar(player: player, size: 58, ring: MP.accent(faceOff.sport), ringWidth: 3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(player.name).font(RallyType.cardTitle)
                            Text("\(faceOff.date.formatted(date: .abbreviated, time: .omitted)) · \(faceOff.venue)")
                                .font(RallyType.caption).foregroundStyle(MP.ink3)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("REPORTED SCORE").rallyEyebrow(MP.ink3)
                    if faceOff.gameScores.isEmpty {
                        Text("A result was submitted without game-by-game scores.")
                            .font(RallyType.body()).foregroundStyle(MP.ink3)
                    } else {
                        ForEach(Array(faceOff.gameScores.enumerated()), id: \.element.id) { index, score in
                            HStack {
                                Text("Game \(index + 1)").font(RallyType.body())
                                Spacer()
                                Text("\(score.myScore) – \(score.opponentScore)").font(RallyType.cardTitle)
                            }
                            if index < faceOff.gameScores.count - 1 { Divider().overlay(MP.line) }
                        }
                    }
                }
                .padding(20)
                .background(MP.surface, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: RallyLayout.cardRadius).stroke(MP.line))

                if let profile = app.me.profile(faceOff.sport), let player {
                    let claimedWin = faceOff.reportedWinnerByThem == .theyWon
                    let projected = EloRating.newRating(player: profile.rating, opponent: player.rating(faceOff.sport), didWin: claimedWin)
                    HStack {
                        ratingCell("Before", value: "\(profile.rating)")
                        ratingCell("Change", value: projected == profile.rating ? "0" : String(format: "%+d", projected - profile.rating))
                        ratingCell("After", value: "\(projected)")
                    }
                }

                Text("Confirm only if the reported winner and every game score are correct. Ratings and statistics update after verification.")
                    .font(RallyType.caption).foregroundStyle(MP.ink3)

                MPPrimaryButton(title: "Confirm result", icon: nil) {
                    app.verifyIncomingResult(faceOffId: faceOff.id, agrees: true)
                    dismiss()
                }
                Button("Dispute result") {
                    app.verifyIncomingResult(faceOffId: faceOff.id, agrees: false)
                    dismiss()
                }
                .font(RallyType.action).foregroundStyle(.red)
                .frame(maxWidth: .infinity).frame(height: 54)
                .overlay(Capsule().stroke(Color.red.opacity(0.45), lineWidth: 1.5))
                }
                .padding(20)
            }
        }
        .background(MP.background).preferredColorScheme(.light)
    }

    private func ratingCell(_ label: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(value).font(RallyType.title)
            Text(label).font(RallyType.caption).foregroundStyle(MP.ink3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(MP.surface2, in: RoundedRectangle(cornerRadius: 18))
    }

}

private struct NativeConnectionRequestDetail: View {
    let player: Player

    var body: some View {
        ProfileDetailView(player: player, presentationMode: .connectionRequest)
    }
}

private struct NativeConnectionRequestsSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlayer: Player?

    private var players: [Player] {
        app.players.filter { app.incomingFriendRequestIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            MPStickySheetHeader(title: "Connection requests", dismiss: { dismiss() })
            Divider().overlay(MP.line)
            ScrollView {
                LazyVStack(spacing: 14) {
                    Text("Accepting connects you and moves their conversation into Chats.")
                        .font(RallyType.caption)
                        .foregroundStyle(MP.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(players) { player in
                        VStack(alignment: .leading, spacing: 14) {
                            Button { selectedPlayer = player } label: {
                                HStack(spacing: 12) {
                                        RallyPlayerAvatar(player: player, size: 54, ring: MP.accent(app.activeSport), ringWidth: 2)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(player.name).font(RallyType.cardTitle)
                                            Text("@\(username(for: player))")
                                                .font(RallyType.caption).foregroundStyle(MP.ink3)
                                        }
                                        Spacer()
                                        Text("\(player.rating(app.activeSport))")
                                            .font(.system(size: 11.5, weight: .bold))
                                            .frame(minWidth: 38, minHeight: 28)
                                            .background(MP.background, in: Capsule())
                                            .overlay(Capsule().stroke(MP.line, lineWidth: 1))
                                }
                            }
                            .buttonStyle(.plain)
                            Text(message(for: player))
                                .font(RallyType.body())
                                .foregroundStyle(MP.ink2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 10) {
                                Button("Delete") { app.declineFriendRequest(from: player.id) }
                                    .font(RallyType.action)
                                    .foregroundStyle(MP.ink)
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background(MP.surface, in: Capsule())
                                Button("Accept") { app.acceptFriendRequest(from: player.id) }
                                    .font(RallyType.action)
                                    .foregroundStyle(MP.background)
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background(MP.ink, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .background(MP.surface2.opacity(0.6), in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }
        }
        .background(MP.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(item: $selectedPlayer) { ProfileDetailView(player: $0) }
    }

    private func username(for player: Player) -> String {
        let value = player.username.replacingOccurrences(of: "@", with: "")
        return value.isEmpty ? player.name.lowercased().replacingOccurrences(of: " ", with: "_") : value
    }

    private func message(for player: Player) -> String {
        guard let lastMessage = app.conversation(with: player.id)?.lastMessage else { return "Sent you a connection request." }
        if case let .text(value) = lastMessage.kind { return value }
        return "Sent you a connection request."
    }
}

private struct NativeVerificationsSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReceived: FaceOff?
    @State private var selectedSent: FaceOff?

    private var received: [FaceOff] {
        app.faceOffs.filter {
            $0.sport == app.activeSport && $0.state == .awaitingResult && $0.reportedWinnerByThem != nil
        }
    }

    private var sent: [FaceOff] {
        app.faceOffs.filter {
            $0.sport == app.activeSport && $0.state == .awaitingResult &&
            $0.reportedWinnerByMe != nil && $0.reportedWinnerByThem == nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            MPStickySheetHeader(title: "Verifications", dismiss: { dismiss() })
            Divider().overlay(MP.line)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("RECEIVED").rallyEyebrow(MP.ink)
                    if received.isEmpty {
                        emptyVerificationState("No received verifications")
                    } else {
                        ForEach(received) { faceOff in
                            verificationRow(faceOff, actionLabel: "Review") { selectedReceived = faceOff }
                        }
                    }

                    Text("SENT").rallyEyebrow(MP.ink).padding(.top, 12)
                    if sent.isEmpty {
                        emptyVerificationState("No sent verifications")
                    } else {
                        ForEach(sent) { faceOff in
                            verificationRow(faceOff, actionLabel: "Edit") { selectedSent = faceOff }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }
        }
        .background(MP.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(item: $selectedReceived) { NativeVerificationDetail(faceOff: $0) }
        .sheet(item: $selectedSent) { NativeSentVerificationEditor(faceOff: $0) }
    }

    private func verificationRow(_ faceOff: FaceOff, actionLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                if let player = app.player(faceOff.opponentId) {
                    RallyPlayerAvatar(player: player, size: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.name)
                            .font(RallyType.cardTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                        Text(scoreSummary(faceOff)).font(RallyType.caption).foregroundStyle(MP.ink3)
                        Text(faceOff.date.formatted(date: .abbreviated, time: .omitted))
                            .font(RallyType.caption).foregroundStyle(MP.ink3)
                    }
                }
                Spacer()
                Text(actionLabel)
                    .font(.system(size: 12, weight: .bold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(MP.ink)
            .padding(16)
            .background(MP.surface2.opacity(0.58), in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func emptyVerificationState(_ text: String) -> some View {
        Text(text)
            .font(RallyType.caption)
            .foregroundStyle(MP.ink3)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.horizontal, 16)
            .background(MP.surface2.opacity(0.4), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func scoreSummary(_ faceOff: FaceOff) -> String {
        let mine = faceOff.gameScores.filter(\.iWon).count
        return "Singles · \(mine)–\(faceOff.gameScores.count - mine) games"
    }
}

private struct NativeSentVerificationEditor: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let faceOff: FaceOff
    @State private var scores: [GameScore]

    init(faceOff: FaceOff) {
        self.faceOff = faceOff
        _scores = State(initialValue: faceOff.gameScores.isEmpty ? [GameScore(myScore: 11, opponentScore: 7)] : faceOff.gameScores)
    }

    var body: some View {
        VStack(spacing: 0) {
            MPStickySheetHeader(title: "Edit sent verification", dismiss: { dismiss() })
            Divider().overlay(MP.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Update the score before your opponent verifies it.")
                        .font(RallyType.body())
                        .foregroundStyle(MP.ink3)
                    ForEach(scores.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 12) {
                            Text("GAME \(index + 1)").rallyEyebrow(MP.ink)
                            scoreStepper("You", value: binding(index, \.myScore))
                            scoreStepper("Opponent", value: binding(index, \.opponentScore))
                        }
                        .padding(16)
                        .background(MP.surface2.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    Button {
                        scores.append(GameScore(myScore: 11, opponentScore: 7))
                    } label: {
                        Label("Add game", systemImage: "plus")
                            .font(RallyType.action)
                            .foregroundStyle(MP.ink)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(MP.surface2, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        app.submitScoreUpdate(faceOffId: faceOff.id, scores: scores)
                        dismiss()
                    } label: {
                        Text("Update")
                            .font(RallyType.action)
                            .foregroundStyle(MP.background)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(MP.ink, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasValidWinner)
                    .opacity(hasValidWinner ? 1 : 0.42)
                }
                .padding(20)
            }
        }
        .background(MP.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private var hasValidWinner: Bool {
        let wins = scores.filter(\.iWon).count
        return scores.allSatisfy { $0.myScore != $0.opponentScore } && wins != scores.count - wins
    }

    private func binding(_ index: Int, _ keyPath: WritableKeyPath<GameScore, Int>) -> Binding<Int> {
        Binding(
            get: { scores[index][keyPath: keyPath] },
            set: { scores[index][keyPath: keyPath] = max(0, min(99, $0)) }
        )
    }

    private func scoreStepper(_ title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title).font(RallyType.body(15, weight: .semibold))
            Spacer()
            Button { value.wrappedValue -= 1 } label: { Image(systemName: "minus") }
            Text("\(value.wrappedValue)")
                .font(RallyType.numeral(24))
                .frame(width: 48)
            Button { value.wrappedValue += 1 } label: { Image(systemName: "plus") }
        }
        .buttonStyle(.plain)
    }
}

private struct NativeChallengesSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChallenge: FaceOff?

    private var awaitingReply: [FaceOff] {
        app.faceOffs
            .filter { $0.sport == app.activeSport && $0.state == .proposed }
            .sorted { $0.date < $1.date }
    }

    private var upcoming: [FaceOff] {
        app.faceOffs
            .filter { $0.sport == app.activeSport && $0.state == .confirmed && $0.date >= .now }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            MPStickySheetHeader(title: "Challenges", dismiss: { dismiss() })
            Divider().overlay(MP.line)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("AWAITING REPLY").rallyEyebrow(MP.ink)
                    if awaitingReply.isEmpty {
                        emptyState("No challenges awaiting a reply")
                    } else {
                        ForEach(awaitingReply) { challengeRow($0) }
                    }

                    Text("UPCOMING").rallyEyebrow(MP.ink).padding(.top, 14)
                    if upcoming.isEmpty {
                        emptyState("No upcoming challenges")
                    } else {
                        ForEach(upcoming) { challengeRow($0) }
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }
        }
        .background(MP.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(item: $selectedChallenge) { NativeChallengeDetail(faceOff: $0) }
    }

    private func challengeRow(_ faceOff: FaceOff) -> some View {
        Button { selectedChallenge = faceOff } label: {
            HStack(spacing: 13) {
                if let player = app.player(faceOff.opponentId) {
                    RallyPlayerAvatar(player: player, size: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.name)
                            .font(RallyType.cardTitle)
                            .lineLimit(1)
                        Text(faceOff.venue)
                            .font(RallyType.caption)
                            .foregroundStyle(MP.ink3)
                            .lineLimit(1)
                    }
                } else {
                    Circle()
                        .fill(MP.surface)
                        .frame(width: 58, height: 58)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(MP.ink3))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(faceOff.opponentName)
                            .font(RallyType.cardTitle)
                            .lineLimit(1)
                        Text(faceOff.venue)
                            .font(RallyType.caption)
                            .foregroundStyle(MP.ink3)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(faceOff.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(RallyType.action)
                    HStack(spacing: 7) {
                        Text(faceOff.date.formatted(date: .omitted, time: .shortened))
                            .font(RallyType.caption)
                            .foregroundStyle(MP.ink3)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(MP.ink3)
                    }
                }
            }
            .foregroundStyle(MP.ink)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(MP.surface2.opacity(0.58), in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func emptyState(_ title: String) -> some View {
        Text(title)
            .font(RallyType.caption)
            .foregroundStyle(MP.ink3)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.horizontal, 16)
            .background(MP.surface2.opacity(0.4), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct NativeChallengeDetail: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let faceOff: FaceOff

    var body: some View {
        VStack(spacing: 0) {
            MPStickySheetHeader(title: "Challenge details", dismiss: { dismiss() })
            Divider().overlay(MP.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                if let player = app.player(faceOff.opponentId) {
                    HStack(spacing: 14) {
                        RallyPlayerAvatar(player: player, size: 62, ring: MP.accent(faceOff.sport), ringWidth: 3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(player.name).font(RallyType.cardTitle)
                            Text(faceOff.state == .confirmed ? "Confirmed" : (faceOff.proposedByMe ? "Awaiting their reply" : "Needs your reply"))
                                .font(RallyType.action).foregroundStyle(MP.ink3)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("MATCH DETAILS").rallyEyebrow(MP.ink3)
                    detailRow("Sport", faceOff.sport.title)
                    detailRow("Venue", faceOff.venue)
                    detailRow("Wager", faceOff.wager)
                    Divider().overlay(MP.line)
                    Text(faceOff.proposedDates.count > 1 ? "PROPOSED TIMES" : "WHEN").rallyEyebrow(MP.ink3)
                    ForEach(Array((faceOff.proposedDates.isEmpty ? [faceOff.date] : faceOff.proposedDates).enumerated()), id: \.offset) { index, date in
                        HStack(spacing: 12) {
                            Text(String(format: "%02d", index + 1)).font(RallyType.action)
                                .frame(width: 38, height: 38).background(MP.accent(faceOff.sport), in: Circle())
                            Text(date.formatted(date: .abbreviated, time: .shortened)).font(RallyType.body())
                        }
                    }
                }
                .padding(20)
                .background(MP.surface, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: RallyLayout.cardRadius).stroke(MP.line))

                if faceOff.state == .proposed && !faceOff.proposedByMe {
                    MPPrimaryButton(title: "Accept challenge", icon: "checkmark") {
                        app.acceptChallenge(faceOff.id); dismiss()
                    }
                    Button("Decline") { app.declineChallenge(faceOff.id); dismiss() }
                        .font(RallyType.action).foregroundStyle(.red)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .overlay(Capsule().stroke(Color.red.opacity(0.45), lineWidth: 1.5))
                } else if faceOff.state == .proposed {
                    Button("Withdraw challenge") { app.cancelChallenge(faceOff.id); dismiss() }
                        .font(RallyType.action).foregroundStyle(.red)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .overlay(Capsule().stroke(Color.red.opacity(0.45), lineWidth: 1.5))
                }
                }
                .padding(20)
            }
        }
        .background(MP.background).preferredColorScheme(.light)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(RallyType.caption).foregroundStyle(MP.ink3)
            Spacer()
            Text(value).font(RallyType.action).multilineTextAlignment(.trailing)
        }
    }
}

private struct PersonPoster: View {
    let player: Player
    let sport: Sport
    let line1: String
    let line2: String
    let badge: String?
    let badgeColor: Color
    var reservesBadgeSpace = false

    private var usesBadgeRow: Bool {
        badge != nil || reservesBadgeSpace
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                MP.surface2
                RallyPhoto(name: player.rallyPhotoName, contentMode: .fill)
                    .frame(width: 158, height: 148)
                    .clipped()

                if sport.category == .individual {
                    Text("\(player.rating(sport))")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(MP.ink)
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(RallyPalette.cream, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 1))
                        .padding(10)
                }
            }
            .frame(width: 158, height: 148)

            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(MP.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(line1).font(.system(size: 11, weight: .medium)).foregroundStyle(MP.ink3).lineLimit(1)
                Text(line2).font(.system(size: 11, weight: .medium)).foregroundStyle(MP.ink3).lineLimit(1)
                if let badge {
                    Text(badge)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(MP.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(badgeColor, in: Capsule())
                        .padding(.top, 3)
                }
            }
            .padding(12)
            .frame(width: 158, height: usesBadgeRow ? 116 : 82, alignment: .topLeading)
            .background(MP.surface)
        }
        .frame(width: 158, height: usesBadgeRow ? 264 : 230, alignment: .topLeading)
        .background(MP.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(MP.strongLine, lineWidth: 1.4))
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
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RallyPhoto(name: catalogCourtName)
                    .frame(width: 164, height: 102)
                    .clipped()
                Text(community.kind)
                    .rallyEyebrow(MP.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(sport.rallyAccent, in: Capsule())
                    .padding(9)
            }
            .frame(width: 164, height: 102)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(community.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MP.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(community.meta)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MP.ink3)
                    .lineLimit(1)
                Spacer(minLength: 2)
            }
            .padding(11)
            }
            .frame(width: 164, height: 194)
            .background(MP.surface)
            .clipShape(RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous)
                    .stroke(MP.strongLine, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
        }
        .buttonStyle(RallyPressStyle())
    }

    private var catalogCourtName: String {
        let key = ImageCatalog.courtKey(for: sport)
        return ImageCatalog.sources[key] == nil ? community.imageName : key
    }
}

private enum NativeMapFilterPanel: Hashable {
    case audience, gender, rating
}

private struct NativeMapPlayerPoint {
    let player: Player
    let coordinate: CLLocationCoordinate2D
}

private struct NativeMapPlayerCluster: Identifiable {
    let players: [Player]
    let coordinate: CLLocationCoordinate2D
    var id: String { players.map { $0.id.uuidString }.sorted().joined(separator: "-") }
}

private struct NativeMapScreen: View {
    @EnvironmentObject private var app: AppState
    @State private var camera: MapCameraPosition = .region(.init(center: .init(latitude: 30.2672, longitude: -97.7431), span: .init(latitudeDelta: 0.16, longitudeDelta: 0.16)))
    @State private var gender: Gender?
    @State private var rating = "Any rating"
    @State private var audience = "All people"
    @State private var selected: Player?
    @State private var activeFilter: NativeMapFilterPanel?
    @State private var visibleRegion = MKCoordinateRegion(
        center: .init(latitude: 30.2672, longitude: -97.7431),
        span: .init(latitudeDelta: 0.16, longitudeDelta: 0.16)
    )

    private var players: [Player] {
        app.players.filter { player in
            guard player.profile(app.activeSport) != nil else { return false }
            guard audience != "Connections" || app.friendIds.contains(player.id) else { return false }
            guard gender == nil || player.gender == gender else { return false }
            switch rating {
            case "Under 80": return player.rating(app.activeSport) < 80
            case "80 to 110": return (80...110).contains(player.rating(app.activeSport))
            case "Above 110": return player.rating(app.activeSport) > 110
            default: return true
            }
        }
    }

    private var hasAppliedFilters: Bool {
        audience != "All people" || gender != nil || rating != "Any rating"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $camera, interactionModes: [.pan, .zoom]) {
                Annotation("You", coordinate: .init(latitude: 30.2672, longitude: -97.7431)) {
                    Circle().fill(MP.accent(app.activeSport)).frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(color: MP.accent(app.activeSport).opacity(0.3), radius: 8)
                }
                ForEach(playerClusters) { cluster in
                    Annotation(cluster.players.count == 1 ? cluster.players[0].name : "", coordinate: cluster.coordinate) {
                        if cluster.players.count == 1, let player = cluster.players.first {
                            Button { selected = player } label: {
                                ZStack(alignment: .bottom) {
                                    RallyPlayerAvatar(
                                        player: player,
                                        size: 48,
                                        ring: app.friendIds.contains(player.id) ? MP.accent(app.activeSport) : RallyPalette.cream,
                                        ringWidth: app.friendIds.contains(player.id) ? 4 : 2.5
                                    )
                                    .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
                                    Text("\(player.rating(app.activeSport))")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .frame(height: 17)
                                        .background(MP.ink, in: Capsule())
                                        .offset(y: 6)
                                }
                            }
                        } else {
                            Button { zoom(into: cluster) } label: {
                                VStack(spacing: 1) {
                                    Text("\(cluster.players.count)")
                                        .font(.system(size: 17, weight: .heavy))
                                    Text("PLAYERS")
                                        .font(.system(size: 7, weight: .black))
                                        .tracking(0.8)
                                }
                                .foregroundStyle(RallyPalette.cream)
                                .frame(width: 58, height: 58)
                                .background(MP.ink, in: Circle())
                                .overlay(Circle().stroke(RallyPalette.cream, lineWidth: 3))
                                .shadow(color: Color.black.opacity(0.2), radius: 7, y: 3)
                            }
                            .accessibilityLabel("\(cluster.players.count) players nearby. Zoom in to separate them")
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .environment(\.colorScheme, .light)
            .ignoresSafeArea(edges: .bottom)
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }

            MP.accent(app.activeSport).opacity(0.055)
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .bottom)

            ZStack(alignment: .topTrailing) {
                HStack(alignment: .top, spacing: 6) {
                    filterControl(.audience, text: audience == "All people" ? "Connections" : audience, icon: "person.2")
                    filterControl(.gender, text: gender?.rawValue ?? "Gender", icon: "person")
                    filterControl(.rating, text: rating == "Any rating" ? "Rating" : rating, icon: "bolt")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if hasAppliedFilters && activeFilter == nil {
                    Button("Clear") {
                        audience = "All people"
                        gender = nil
                        rating = "Any rating"
                    }
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(MP.ink)
                    .frame(width: 68, height: 38)
                    .background(MP.background, in: Capsule())
                    .shadow(color: MP.shadow, radius: 4, y: 1)
                    .padding(.trailing, 2)
                    .offset(y: 52)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 76)
            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: activeFilter)
            .animation(.easeOut(duration: 0.18), value: hasAppliedFilters)

            VStack {
                Spacer()
                Text("\(players.count) \(app.activeSport.title) player\(players.count == 1 ? "" : "s") nearby")
                    .font(RallyType.caption).foregroundStyle(MP.ink)
                    .padding(.horizontal, 14).frame(height: 44)
                    .background(MP.background, in: Capsule()).overlay(Capsule().stroke(MP.line))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 18)
                    .padding(.trailing, 96)
                    .padding(.bottom, 112)
            }

            VStack {
                Spacer()
                Button {
                    camera = .region(.init(center: .init(latitude: 30.2672, longitude: -97.7431), span: .init(latitudeDelta: 0.16, longitudeDelta: 0.16)))
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RallyPalette.cream)
                        .frame(width: 54, height: 54)
                        .background(MP.ink, in: Circle())
                        .shadow(color: Color.black.opacity(0.22), radius: 14, y: 7)
                }
                .buttonStyle(RallyPressStyle())
                .accessibilityLabel("Recentre the map")
            }
            .padding(.trailing, 20)
            .padding(.bottom, 153)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .sheet(item: $selected) { player in
            ProfileDetailView(player: player)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .onAppear {
#if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-demo-map-audience-filter") { activeFilter = .audience }
            if arguments.contains("-demo-map-gender-filter") { activeFilter = .gender }
            if arguments.contains("-demo-map-rating-filter") { activeFilter = .rating }
            if arguments.contains("-demo-map-filtered") { rating = "Under 80" }
#endif
        }
    }

    private func coordinate(_ index: Int) -> CLLocationCoordinate2D {
        let offsets: [(Double, Double)] = [(-0.026,-0.034),(-0.023,-0.031),(-0.020,-0.028),(0.024,0.034),(-0.044,0.008),(0.008,-0.047),(0.047,0.004),(-0.005,0.052),(0.052,-0.038),(-0.052,-0.025)]
        let pair = offsets[index % offsets.count]
        return .init(latitude: 30.2672 + pair.0, longitude: -97.7431 + pair.1)
    }

    private var playerClusters: [NativeMapPlayerCluster] {
        let points = players.enumerated().map { NativeMapPlayerPoint(player: $0.element, coordinate: coordinate($0.offset)) }
        let threshold = max(0.0012, visibleRegion.span.latitudeDelta * 0.065)
        var remaining = points
        var result: [NativeMapPlayerCluster] = []

        while let seed = remaining.first {
            let grouped = remaining.filter {
                abs($0.coordinate.latitude - seed.coordinate.latitude) <= threshold &&
                abs($0.coordinate.longitude - seed.coordinate.longitude) <= threshold
            }
            let groupedIDs = Set(grouped.map { $0.player.id })
            remaining.removeAll { groupedIDs.contains($0.player.id) }
            let latitude = grouped.map(\.coordinate.latitude).reduce(0, +) / Double(grouped.count)
            let longitude = grouped.map(\.coordinate.longitude).reduce(0, +) / Double(grouped.count)
            result.append(.init(players: grouped.map(\.player), coordinate: .init(latitude: latitude, longitude: longitude)))
        }
        return result
    }

    private func zoom(into cluster: NativeMapPlayerCluster) {
        let span = MKCoordinateSpan(
            latitudeDelta: max(visibleRegion.span.latitudeDelta * 0.28, 0.006),
            longitudeDelta: max(visibleRegion.span.longitudeDelta * 0.28, 0.006)
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            camera = .region(.init(center: cluster.coordinate, span: span))
        }
    }

    private func filterControl(_ panel: NativeMapFilterPanel, text: String, icon: String) -> some View {
        VStack(spacing: 8) {
            filterButton(panel, text: text, icon: icon)
            if activeFilter == panel {
                filterPanel(panel)
                    .zIndex(3)
                    .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func filterButton(_ panel: NativeMapFilterPanel, text: String, icon: String) -> some View {
        let expanded = activeFilter == panel
        return Button {
            activeFilter = activeFilter == panel ? nil : panel
        } label: {
            filterChip(
                text,
                icon: icon,
                expanded: expanded
            )
        }
        .buttonStyle(RallyPressStyle())
    }

    private func filterChip(_ text: String, icon: String, expanded: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .layoutPriority(1)
            Spacer(minLength: 2)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(MP.ink3)
                .rotationEffect(.degrees(expanded ? 180 : 0))
        }
        .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(MP.ink)
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(MP.background, in: Capsule())
        .shadow(color: MP.shadow, radius: 4, y: 1)
    }

    @ViewBuilder private func filterPanel(_ panel: NativeMapFilterPanel) -> some View {
        let options: [String] = switch panel {
        case .audience: ["All people", "Connections"]
        case .gender: ["Any gender"] + Gender.allCases.map(\.rawValue)
        case .rating: ["Any rating", "Under 80", "80 to 110", "Above 110"]
        }

        VStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let selected = selectedOption(panel) == option
                Button {
                    apply(option, to: panel)
                    activeFilter = nil
                } label: {
                    HStack {
                        Text(option).font(.system(size: 11.5, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(selected ? MP.background : MP.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(selected ? MP.ink : .clear, in: Capsule())
                }
                .buttonStyle(RallyPressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(5)
        .frame(maxWidth: .infinity)
        .background(MP.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .rallyLifted(0.7)
    }

    private func selectedOption(_ panel: NativeMapFilterPanel) -> String {
        switch panel {
        case .audience: audience
        case .gender: gender?.rawValue ?? "Any gender"
        case .rating: rating
        }
    }

    private func apply(_ option: String, to panel: NativeMapFilterPanel) {
        switch panel {
        case .audience: audience = option
        case .gender: gender = option == "Any gender" ? nil : Gender.allCases.first { $0.rawValue == option }
        case .rating: rating = option
        }
    }
}

private struct NativeMatchesScreen: View {
    @EnvironmentObject private var app: AppState
    let openProfile: () -> Void
    @State private var selected: MatchRecord?
    @State private var selectedChallenge: FaceOff?

    private var upcomingMatches: [FaceOff] {
        app.faceOffs
            .filter {
                $0.sport == app.activeSport &&
                [.proposed, .confirmed].contains($0.state) &&
                $0.date >= .now
            }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Matches")
                    .font(RallyType.hero)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .rallyDisplayLeading()

                MPSectionHeader(title: "Upcoming")
                    .padding(.top, 4)
                if upcomingMatches.isEmpty {
                    Text("No upcoming matches")
                        .font(RallyType.body())
                        .foregroundStyle(MP.ink3)
                        .frame(maxWidth: .infinity, minHeight: 104)
                        .background(MP.surface2.opacity(0.48), in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
                } else {
                    ForEach(upcomingMatches) { match in
                        Button { selectedChallenge = match } label: {
                            UpcomingMatchCard(match: match)
                        }
                        .buttonStyle(.plain)
                    }
                }

                MPSectionHeader(title: "Past")
                    .padding(.top, 12)
                if app.myMatches.isEmpty {
                    Text("No past matches")
                        .font(RallyType.body())
                        .foregroundStyle(MP.ink3)
                        .frame(maxWidth: .infinity, minHeight: 104)
                        .background(MP.surface2.opacity(0.48), in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
                } else {
                    ForEach(app.myMatches) { match in
                        Button { selected = match } label: { PastMatchCard(match: match) }.buttonStyle(.plain)
                    }
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
        .sheet(item: $selectedChallenge) { NativeChallengeDetail(faceOff: $0) }
    }
}

private struct NativeCalendarScreen: View {
    @EnvironmentObject private var app: AppState
    @State private var segment = "Week"
    @State private var showFixture = false
    @State private var selectedFixture: GroupFixture?
    @State private var selectedChallenge: FaceOff?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Calendar")
                    .font(RallyType.hero)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .rallyDisplayLeading()
                MPSegmented(options: ["Week", "Past matches"], selection: $segment)
                if segment == "Week" {
                    WeeklyCalendar(
                        sport: app.activeSport,
                        selectFaceOff: { selectedChallenge = $0 },
                        selectFixture: { selectedFixture = $0 }
                    )
                    CalendarLegend()
                    Text("You and your squad both add fixtures here. There are no challenges or score uploads in \(app.activeSport.title).")
                        .font(.system(size: 12)).foregroundStyle(MP.ink3).multilineTextAlignment(.center)
                } else {
                    let past = app.groupFixtures
                        .filter { $0.sport == app.activeSport && $0.date < .now }
                        .sorted { $0.date > $1.date }
                    if past.isEmpty {
                        Text("No past \(app.activeSport.title) matches.")
                            .font(RallyType.cardTitle).frame(maxWidth: .infinity).padding(.vertical, 48)
                    } else {
                        ForEach(past) { fixture in
                            Button { selectedFixture = fixture } label: {
                                GroupFixtureCard(fixture: fixture)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Color.clear.frame(height: 150)
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showFixture) { GroupFixtureSheet() }
        .sheet(item: $selectedFixture) { GroupFixtureDetail(fixture: $0) }
        .sheet(item: $selectedChallenge) { NativeChallengeDetail(faceOff: $0) }
    }
}

private struct GroupFixtureCard: View {
    let fixture: GroupFixture

    var body: some View {
        MPCard {
            VStack(spacing: 13) {
                HStack(spacing: 12) {
                    MPLineSportIcon(sport: fixture.sport, size: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fixture.opponent).font(RallyType.cardTitle)
                        Text("\(fixture.title) · \(fixture.date.formatted(date: .abbreviated, time: .shortened))")
                            .font(RallyType.caption).foregroundStyle(MP.ink3)
                    }
                    Spacer()
                    Text(fixture.result?.outcome.rawValue ?? "Result needed")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(fixture.result == nil ? MP.ink : RallyPalette.cream)
                        .padding(.horizontal, 9).frame(height: 28)
                        .background(fixture.result == nil ? fixture.sport.rallyAccent : MP.ink, in: Capsule())
                }
                Divider().overlay(MP.line)
                HStack {
                    Label(fixture.venue, systemImage: "mappin").font(RallyType.caption).foregroundStyle(MP.ink3)
                    Spacer()
                    Text(fixture.result?.summary ?? "Tap to add the result").font(RallyType.caption).foregroundStyle(MP.ink3)
                }
            }
        }
    }
}

private struct GroupFixtureDetail: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let fixture: GroupFixture
    @State private var showResult = false
    @State private var showReview = false

    private var current: GroupFixture {
        app.groupFixtures.first(where: { $0.id == fixture.id }) ?? fixture
    }

    var body: some View {
        VStack(spacing: 0) {
            MPStickySheetHeader(title: "Game details", dismiss: { dismiss() })
            Divider().overlay(MP.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(current.opponent).font(RallyType.title)
                    Text("\(current.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(RallyType.caption).foregroundStyle(MP.ink3)
                }
                HStack(spacing: 14) {
                    MPLineSportIcon(sport: current.sport, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(current.title).font(RallyType.cardTitle)
                        Text("\(current.team) versus \(current.opponent)").font(RallyType.body()).foregroundStyle(MP.ink3)
                    }
                }
                VStack(spacing: 13) {
                    fixtureRow("Sport", current.sport.title)
                    fixtureRow("Date", current.date.formatted(date: .long, time: .omitted))
                    fixtureRow("Time", "\(current.date.formatted(date: .omitted, time: .shortened)) – \(current.endDate.formatted(date: .omitted, time: .shortened))")
                    fixtureRow("Location", current.venue)
                    if let result = current.result { fixtureRow("Result", "\(result.outcome.rawValue) · \(result.summary)") }
                }
                .padding(20).background(MP.surface, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: RallyLayout.cardRadius).stroke(MP.line))

                if current.date < .now && current.result == nil {
                    MPPrimaryButton(title: "Add the result", icon: "plus") { showResult = true }
                }
                if current.date < .now {
                    Button("Submit a review") { showReview = true }
                        .font(RallyType.action).foregroundStyle(MP.ink)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .overlay(Capsule().stroke(MP.ink, lineWidth: 1.5))
                }
                Button("Remove from calendar") {
                    app.removeGroupFixture(current.id); dismiss()
                }
                .font(RallyType.action).foregroundStyle(.red)
                .frame(maxWidth: .infinity).frame(height: 54)
                }
                .padding(20)
            }
        }
        .background(MP.background).preferredColorScheme(.light)
        .sheet(isPresented: $showResult) { GroupResultSheet(fixture: current) }
        .sheet(isPresented: $showReview) { PeerReviewLauncher() }
    }

    private func fixtureRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(RallyType.caption).foregroundStyle(MP.ink3)
            Spacer()
            Text(value).font(RallyType.action).multilineTextAlignment(.trailing)
        }
    }
}

private struct GroupResultSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let fixture: GroupFixture
    @State private var outcome: GroupResultOutcome = .won
    @State private var summary = ""

    var body: some View {
        VStack(spacing: 0) {
            MPStickySheetHeader(title: "Add the result", dismiss: { dismiss() })
            Divider().overlay(MP.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Only you and your squad can see this.").font(RallyType.body()).foregroundStyle(MP.ink3)
                    Text("\(fixture.team) versus \(fixture.opponent)").font(RallyType.cardTitle)
                    HStack(spacing: 5) {
                        ForEach(GroupResultOutcome.allCases, id: \.self) { option in
                            Button(option.rawValue) { outcome = option }
                                .font(RallyType.action)
                                .foregroundStyle(outcome == option ? RallyPalette.cream : MP.ink3)
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(outcome == option ? MP.ink : MP.surface3, in: Capsule())
                                .buttonStyle(RallyPressStyle())
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SUMMARY").rallyEyebrow(MP.ink3)
                        TextField("Won by 24 runs", text: $summary)
                            .font(RallyType.body()).padding(.horizontal, 18).frame(height: 56)
                            .background(MP.surface2, in: Capsule()).overlay(Capsule().stroke(MP.line))
                        Text("Write the result the way your squad would say it out loud.").font(RallyType.caption).foregroundStyle(MP.ink3)
                    }
                    MPPrimaryButton(title: "Save the result", icon: "checkmark") {
                        app.saveGroupFixtureResult(fixture.id, outcome: outcome, summary: summary)
                        dismiss()
                    }
                }
                .padding(20)
            }
        }
        .background(MP.background).preferredColorScheme(.light)
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
    @EnvironmentObject private var app: AppState
    let sport: Sport
    var selectFaceOff: (FaceOff) -> Void = { _ in }
    var selectFixture: (GroupFixture) -> Void = { _ in }
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
                ForEach(app.faceOffs.filter {
                    app.mySports.contains($0.sport) && [.proposed, .confirmed].contains($0.state)
                }) { faceOff in
                    if let day = dayIndex(faceOff.date) {
                        calendarEvent(
                            day: day,
                            start: decimalHour(faceOff.date),
                            duration: 1.5,
                            title: faceOff.opponentName,
                            eventSport: faceOff.sport,
                            tentative: faceOff.state == .proposed,
                            action: { selectFaceOff(faceOff) }
                        )
                    }
                }
                ForEach(app.groupFixtures.filter { app.mySports.contains($0.sport) }) { fixture in
                    if let day = dayIndex(fixture.date) {
                        calendarEvent(
                            day: day,
                            start: decimalHour(fixture.date),
                            duration: max(0.75, fixture.endDate.timeIntervalSince(fixture.date) / 3_600),
                            title: fixture.opponent,
                            eventSport: fixture.sport,
                            tentative: false,
                            action: { selectFixture(fixture) }
                        )
                    }
                }
            }
            .frame(height: CGFloat(hours.count) * 40)
            .clipped()
        }
        .padding(14)
        .background(MP.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(MP.strongLine, lineWidth: 1))
    }

    private func calendarEvent(day: Int, start: Double, duration: Double, title: String, eventSport: Sport, tentative: Bool, action: @escaping () -> Void) -> some View {
        GeometryReader { geo in
            let column = (geo.size.width - 38) / 7
            let focused = eventSport == sport
            Button(action: action) {
                Text(title).font(.system(size: 9, weight: .bold)).lineLimit(2).minimumScaleFactor(0.72)
                    .foregroundStyle(MP.ink.opacity(focused ? 1 : 0.58))
                    .padding(3).frame(width: column - 2, height: duration * 40, alignment: .topLeading)
                    .background(
                        tentative
                            ? eventSport.rallyAccent.opacity(focused ? 0.10 : 0.055)
                            : eventSport.rallyAccent.opacity(focused ? 1 : 0.22),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(
                                tentative ? eventSport.rallyAccent.opacity(focused ? 1 : 0.38) : .clear,
                                style: StrokeStyle(lineWidth: 1.3, dash: tentative ? [4, 3] : [])
                            )
                    }
            }
            .buttonStyle(.plain)
            .offset(x: 38 + CGFloat(day) * column + 1, y: CGFloat(start - 7) * 40)
        }
    }

    private func dayIndex(_ date: Date) -> Int? {
        days.firstIndex { Calendar.current.isDate($0, inSameDayAs: date) }
    }

    private func decimalHour(_ date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
    }

    private func hourLabel(_ hour: Int) -> String { "\(hour > 12 ? hour - 12 : hour) \(hour >= 12 ? "PM" : "AM")" }
}

private extension View {
    func calendarNav(width: CGFloat = 34) -> some View {
        self.foregroundStyle(MP.ink2).frame(width: max(width, 44), height: 44)
            .background(MP.surface2, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct CalendarLegend: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            legend(app.activeSport.rallyAccent, "Focused sport")
            legend(app.activeSport.rallyAccent.opacity(0.22), "Your other sports")
            legend(app.activeSport.rallyAccent.opacity(0.08), "Awaiting reply", border: app.activeSport.rallyAccent, dashed: true)
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

private struct UpcomingMatchCard: View {
    @EnvironmentObject private var app: AppState
    let match: FaceOff

    private var opponent: Player? { app.player(match.opponentId) }

    var body: some View {
        MPCard {
            HStack(alignment: .center, spacing: 14) {
                if let opponent {
                    RallyPhoto(name: opponent.rallyPhotoName, contentMode: .fit)
                        .frame(width: 58, height: 58)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(match.opponentName)
                        .font(.system(size: 15.5, weight: .bold))
                        .lineLimit(2)
                    Text(match.venue.isEmpty ? "Venue to be decided" : match.venue)
                        .font(.system(size: 12))
                        .foregroundStyle(MP.ink3)
                        .lineLimit(1)
                    Text(match.state == .confirmed ? "Confirmed" : (match.proposedByMe ? "Awaiting reply" : "Needs your reply"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(match.state == .confirmed ? MP.ink3 : MP.ink)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(match.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 15, weight: .black))
                    Text(match.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 13, weight: .bold))
                    Text(match.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MP.ink3)
                }
            }
        }
    }
}

private struct PastMatchCard: View {
    @EnvironmentObject private var app: AppState
    let match: MatchRecord

    private var opponent: Player? {
        match.opponentId.flatMap { app.player($0) } ?? app.players.first { $0.name == match.opponentName }
    }

    var body: some View {
        MPCard {
            HStack(alignment: .center, spacing: 14) {
                Group {
                    if let opponent {
                        RallyPhoto(name: opponent.rallyPhotoName, contentMode: .fit)
                    } else {
                        AvatarView(avatar: match.opponentAvatar, size: 58)
                    }
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(match.didWin ? "Win against" : "Loss to") \(match.opponentName)")
                        .font(.system(size: 15.5, weight: .bold))
                        .lineLimit(2)
                    Text("Singles · \(match.didWin ? "11–8, 11–6" : "8–11, 9–11")")
                        .font(.system(size: 12))
                        .foregroundStyle(MP.ink3)
                    HStack(spacing: 7) {
                        Text(match.source == .unscheduled ? "Uploaded score" : "Scheduled match")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(MP.ink2)
                            .padding(.horizontal, 8)
                            .frame(height: 23)
                            .background(MP.surface3, in: Capsule())
                        Text(match.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 10))
                            .foregroundStyle(MP.ink3)
                    }
                }
                Spacer(minLength: 5)
                Text(match.ratingDelta > 0 ? "+\(match.ratingDelta)" : "\(match.ratingDelta)")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(match.didWin ? Color(hex: "477A19") : Color(hex: "B83218"))
            }
        }
    }
}

private struct MPPrimaryButton: View {
    @EnvironmentObject private var app: AppState
    let title: String
    let icon: String?
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
                .font(RallyType.action)
                .foregroundStyle(MP.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(MP.accent(app.activeSport), in: Capsule())
        }
        .buttonStyle(RallyPressStyle())
    }
}

private struct MPStickySheetHeader: View {
    let title: String
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Text(title).font(RallyType.title).rallyDisplayLeading()
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MP.ink)
                    .frame(width: 46, height: 46)
                    .background(MP.surface, in: Circle())
                    .overlay(Circle().stroke(MP.line, lineWidth: 1.5))
            }
            .buttonStyle(RallyPressStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(MP.background)
        .zIndex(10)
    }
}

private struct NativeMatchDetail: View {
    @Environment(\.dismiss) private var dismiss
    let record: MatchRecord
    let showStatistics: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            MPStickySheetHeader(title: "Match details", dismiss: { dismiss() })
            Divider().overlay(MP.line)
            ScrollView {
                VStack(spacing: 18) {
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
                }
                .padding(20)
            }
        }
        .presentationBackground(MP.background)
    }
}

private struct NativeChatsScreen: View {
    @EnvironmentObject private var app: AppState
    let onBack: () -> Void
    @State private var search = ""
    @State private var selectedProfile: Player?
    @State private var selectedConversation: Conversation?
    @State private var showGroupComposer = false

    private var conversations: [Conversation] {
        app.conversations.filter { conversation in
            !conversation.isMessageRequest
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(alignment: .center) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 46, height: 46)
                            .background(MP.surface2, in: Circle())
                    }
                    .buttonStyle(RallyPressStyle())
                    .accessibilityLabel("Back")
                    Text("Chats").font(RallyType.title).rallyDisplayLeading()
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
                .padding(.top, 8)
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
                        chatRow(conversation, player: player)
                    }
                }
                Color.clear.frame(height: 150)
            }
            .padding(.horizontal, 20)
        }
        .background(MP.background.ignoresSafeArea())
        .sheet(item: $selectedProfile) {
            ProfileDetailView(player: $0)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showGroupComposer) {
            GroupChatComposer()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(item: $selectedConversation) { conversation in
            NativeChatScreen(conversation: conversation) {
                selectedConversation = nil
            }
        }
        .onAppear {
#if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-demo-group-chat") {
                showGroupComposer = true
            }
            if arguments.contains("-demo-thread") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    selectedConversation = conversations.first
                }
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

    private func chatRow(_ conversation: Conversation, player: Player) -> some View {
        Button { selectedConversation = conversation } label: {
            HStack(spacing: 12) {
                playerPhoto(player)
                    .onTapGesture { selectedProfile = player }
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name).font(.system(size: 15.5, weight: .bold)).foregroundStyle(MP.ink)
                    Text(preview(conversation)).font(.system(size: 13)).foregroundStyle(MP.ink3).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(MP.ink4)
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private func requestCard(_ conversation: Conversation, player: Player) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Button { selectedProfile = player } label: {
                HStack(spacing: 12) {
                    playerPhoto(player)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(player.name).font(RallyType.body(16, weight: .bold)).foregroundStyle(MP.ink)
                            Text(app.activeSport.category == .individual ? "\(player.rating(app.activeSport))" : "Peer")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(MP.ink2)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .background(MP.surface, in: Capsule())
                                .overlay(Capsule().stroke(MP.strongLine, lineWidth: 1.2))
                        }
                        Text("@\(player.username.isEmpty ? player.name.lowercased().replacingOccurrences(of: " ", with: "_") : player.username)")
                            .font(RallyType.caption).foregroundStyle(MP.ink3)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Text(preview(conversation))
                .font(RallyType.body(15))
                .foregroundStyle(MP.ink2)

            HStack(spacing: 10) {
                Button("Delete") { app.deleteMessageRequest(conversation.id) }
                    .font(RallyType.action)
                    .foregroundStyle(MP.ink)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .overlay(Capsule().stroke(MP.line, lineWidth: 1.3))
                Button("Accept") { app.acceptMessageRequest(conversation.id) }
                    .font(RallyType.action)
                    .foregroundStyle(RallyPalette.cream)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(MP.ink, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(17)
        .background(MP.surface2, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous).stroke(MP.line, lineWidth: 1))
    }

    private func playerPhoto(_ player: Player) -> some View {
        RallyPhoto(name: player.rallyPhotoName)
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct NativeChatScreen: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let conversation: Conversation
    var onClose: (() -> Void)? = nil
    @State private var draft = ""
    @State private var showChallenge = false
    @State private var showActions = false

    private var player: Player? { app.player(conversation.partnerId) }
    private var currentConversation: Conversation {
        app.conversations.first(where: { $0.id == conversation.id }) ?? conversation
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button {
                        if let onClose { onClose() } else { dismiss() }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(RallyPressStyle())
                    Spacer()
                }

                HStack(spacing: 10) {
                    if let player { RallyPlayerAvatar(player: player, size: 40, ring: MP.background) }
                    Text(player?.name ?? "Conversation")
                        .font(.system(size: 15.5, weight: .bold))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(MP.background)
            .overlay(alignment: .bottom) { Rectangle().fill(MP.line).frame(height: 1) }

            ScrollView {
                LazyVStack(spacing: 16) {
                    if currentConversation.isMessageRequest {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "link")
                            Text("Start a conversation and wait for their response before sending your first challenge.")
                        }
                        .font(.system(size: 12)).foregroundStyle(MP.ink2).padding(12).background(MP.surface2, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Text("Today").font(.system(size: 10, weight: .bold)).foregroundStyle(MP.ink4).padding(.vertical, 8)
                    ForEach(currentConversation.messages) { message in messageBubble(message) }
                }
                .padding(20)
            }
            .background(MP.background)

            VStack(alignment: .leading, spacing: 10) {
                if showActions {
                    VStack(spacing: 2) {
                        attachmentAction("Photos & videos", icon: "photo.on.rectangle") {
                            app.send(.image, to: conversation.partnerId); showActions = false
                        }
                        attachmentAction("Camera", icon: "camera") {
                            app.send(.image, to: conversation.partnerId); showActions = false
                        }
                        attachmentAction("Share location", icon: "location") {
                            app.send(.location("Shared location · Austin, TX"), to: conversation.partnerId); showActions = false
                        }
                        if app.activeSport.category == .individual {
                            attachmentAction("Send a challenge", icon: "flag.checkered") {
                                showActions = false; showChallenge = true
                            }
                        }
                    }
                    .padding(8)
                    .frame(width: 232)
                    .background(MP.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(MP.line, lineWidth: 1.5))
                    .shadow(color: MP.shadow, radius: 18, y: 8)
                    .transition(.scale(scale: 0.92, anchor: .bottomLeading).combined(with: .opacity))
                }

                HStack(spacing: 9) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { showActions.toggle() }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(MP.ink)
                            .rotationEffect(.degrees(showActions ? 45 : 0))
                            .frame(width: 50, height: 50)
                    }
                    .buttonStyle(RallyPressStyle())
                    .accessibilityLabel(showActions ? "Close attachment options" : "Open attachment options")

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
            }
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 26).background(MP.background)
        }
        .background(MP.background.ignoresSafeArea())
        .foregroundStyle(MP.ink).preferredColorScheme(.light)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showChallenge) {
            if let player { ChallengeComposerView(player: player) }
        }
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demo-challenge") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { showChallenge = true }
            }
            if ProcessInfo.processInfo.arguments.contains("-demo-chat-actions") {
                showActions = true
            }
            if ProcessInfo.processInfo.arguments.contains("-demo-multi-option"),
               let player,
               !currentConversation.messages.contains(where: {
                   if case .system(let value) = $0.kind { return value.hasPrefix("Challenge proposed:") }
                   return false
               }) {
                let first = Date().addingTimeInterval(86_400)
                app.createChallenge(
                    with: player,
                    sport: app.activeSport,
                    date: first,
                    proposedDates: [first, first.addingTimeInterval(86_400), first.addingTimeInterval(172_800)],
                    venue: "Riverside Courts",
                    note: "",
                    isRatingExempt: false
                )
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

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.fromMe { Spacer(minLength: 54) }
            if case .challenge = message.kind {
                EmptyView()
            } else if case .system(let value) = message.kind, value.hasPrefix("Challenge proposed:") {
                challengeProposalCard(value, date: message.date)
            } else {
                Text(messageText(message))
                    .font(.system(size: 14))
                    .foregroundStyle(message.fromMe ? MP.black : MP.ink)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(message.fromMe ? MP.accent(app.activeSport) : MP.surface2, in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(message.fromMe ? .clear : MP.line))
            }
            if !message.fromMe { Spacer(minLength: 54) }
        }
    }

    private func challengeProposalCard(_ value: String, date: Date) -> some View {
        let parts = value.split(separator: "·").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let sport = parts.first?.replacingOccurrences(of: "Challenge proposed:", with: "").trimmingCharacters(in: .whitespaces) ?? app.activeSport.title
        let proposalSport = Sport.allCases.first { $0.title.caseInsensitiveCompare(sport) == .orderedSame } ?? app.activeSport
        let options = parts.count > 2 ? Array(parts.dropFirst().dropLast()) : Array(parts.dropFirst())
        let venue = parts.count > 1 ? parts.last?.trimmingCharacters(in: CharacterSet(charactersIn: ".")) ?? "Venue TBD" : "Venue TBD"
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                RallySportAssetIcon(sport: proposalSport, size: 28)
                Text("You proposed \(options.count) \(options.count == 1 ? "time" : "times")")
                    .font(.system(size: 13, weight: .bold))
            }
            Text("\(sport) · \(venue)")
                .font(.system(size: 11))
                .foregroundStyle(MP.ink3)
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Text(option)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MP.ink)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 38)
                    .background(MP.background, in: Capsule())
                    .overlay(Capsule().stroke(MP.ink.opacity(0.28), lineWidth: 1.4))
            }
            HStack {
                Text("Waiting for \(player?.firstName ?? "them") to pick a time")
                Spacer()
                Text(date.formatted(date: .omitted, time: .shortened))
            }
            .font(.system(size: 10))
            .foregroundStyle(MP.ink3)
        }
        .padding(13)
        .frame(maxWidth: 285, alignment: .leading)
        .background(MP.surface2, in: RoundedRectangle(cornerRadius: RallyLayout.insetRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RallyLayout.insetRadius).stroke(MP.ink.opacity(0.30), lineWidth: 1.5))
        .shadow(color: MP.shadow, radius: 8, y: 3)
    }

    private func attachmentAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MP.ink)
                    .frame(width: 32, height: 32)
                    .background(MP.accent(app.activeSport), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(MP.ink)
                Spacer()
            }
            .padding(.horizontal, 10).frame(height: 48)
        }
        .buttonStyle(RallyPressStyle())
    }
}

private enum NativeProfileSettings: String, Identifiable {
    case editProfile, manageSports, privacy, notifications
    var id: String { rawValue }
}

private struct NativeProfileScreen: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var session: BackendSessionController
    @State private var settingsSheet: NativeProfileSettings?
    @State private var showRatingInfo = false
    @State private var confirmAccountDeletion = false

    private var profile: SportProfile? { app.me.profile(app.activeSport) }
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    RallyPhoto(name: app.me.rallyPhotoName, contentMode: .fit)
                        .frame(width: 210, height: 205)
                        .clipped()

                    Text(app.me.city).rallyEyebrow(MP.ink.opacity(0.56))
                    Text(app.me.name.isEmpty ? "Your name" : app.me.name)
                        .font(RallyType.title)
                        .multilineTextAlignment(.center)
                    Text("@\(app.me.username) · \(app.me.age) · \(app.me.gender.rawValue)")
                        .font(RallyType.caption)
                        .foregroundStyle(MP.ink.opacity(0.62))
                        .multilineTextAlignment(.center)
                    Text("\(app.displayedFriendCount) friends")
                        .font(RallyType.caption)
                        .foregroundStyle(MP.ink.opacity(0.62))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: RallyLayout.photoRadius, style: .continuous)
                        .fill(MP.accent(app.activeSport).opacity(0.18))
                }
                .clipShape(RoundedRectangle(cornerRadius: RallyLayout.photoRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: RallyLayout.photoRadius, style: .continuous).stroke(MP.ink.opacity(0.16), lineWidth: 1.4))

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
        .sheet(item: $settingsSheet) { destination in
            NativeProfileSettingsSheet(destination: destination)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showRatingInfo) {
            MPRatingInfoSheet(sport: app.activeSport)
                .presentationDetents([.height(580), .large])
                .presentationDragIndicator(.hidden)
        }
        .confirmationDialog(
            "Permanently delete your account?",
            isPresented: $confirmAccountDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete account and all data", role: .destructive) {
                Task {
                    if await app.permanentlyDeleteAccount() {
                        await session.signOut()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your profile, messages, matches, ratings, and uploaded data. This cannot be undone.")
        }
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demo-profile-edit") {
                settingsSheet = .editProfile
            }
            if ProcessInfo.processInfo.arguments.contains("-demo-manage-sports") {
                settingsSheet = .manageSports
            }
            if ProcessInfo.processInfo.arguments.contains("-demo-rating-info") {
                showRatingInfo = true
            }
#endif
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
                if let reviews = profile?.peerWrittenReviews, !reviews.isEmpty {
                    Divider().overlay(MP.line)
                    Text("Player reviews").rallyEyebrow()
                    ForEach(reviews.prefix(2)) { review in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("“\(review.text)”")
                                .font(RallyType.body(14))
                                .foregroundStyle(MP.ink2)
                            Text(review.reviewerName)
                                .font(RallyType.caption)
                                .foregroundStyle(MP.ink3)
                        }
                    }
                }
            }
            .padding(22)
            .background(MP.surface2, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(app.activeSport.title).rallyEyebrow(MP.accent(app.activeSport))
                Text(profile?.usesElo == true ? "\(profile?.rating ?? 80)" : "Unrated")
                    .font(RallyType.numeral(profile?.usesElo == true ? 72 : 42))
                    .foregroundStyle(MP.background)
                Text(profile?.usesElo == true ? "Your current MP rating" : "This sport does not affect your rating")
                    .font(RallyType.caption)
                    .foregroundStyle(RallyPalette.creamMuted)
                Rectangle().fill(MP.background.opacity(0.16)).frame(height: 1).padding(.vertical, 5)
                Button { showRatingInfo = true } label: {
                    HStack {
                        Text("How the MP rating works").font(RallyType.action)
                        Spacer()
                        Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
        let ratings = app.ratingHistory.map(\.rating)
        let lowerBound = (ratings.min() ?? 80) - 4
        let upperBound = (ratings.max() ?? 100) + 4
        return VStack(alignment: .leading, spacing: 12) {
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
                        .interpolationMethod(.catmullRom)
                    if point.date == app.ratingHistory.last?.date {
                        PointMark(x: .value("Date", point.date), y: .value("Rating", point.rating))
                            .foregroundStyle(MP.accent(app.activeSport))
                            .symbolSize(72)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: lowerBound...upperBound)
                .frame(height: 92)

                HStack {
                    Text("\(ratings.first ?? 0) starting")
                    Spacer()
                    Text("\(ratings.last ?? 0) now")
                }
                .font(RallyType.caption)
                .foregroundStyle(MP.ink3)
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
                settingsButton("Edit profile details", destination: .editProfile)
                Rectangle().fill(MP.line).frame(height: 1)
                settingsButton("Manage your sports", destination: .manageSports)
                Rectangle().fill(MP.line).frame(height: 1)
                settingsButton("Privacy and visibility", destination: .privacy)
                Rectangle().fill(MP.line).frame(height: 1)
                settingsButton("Notification preferences", destination: .notifications)
                Rectangle().fill(MP.line).frame(height: 1)
                Button {
                    confirmAccountDeletion = true
                } label: {
                    HStack {
                        Text("Delete account").font(RallyType.body(16, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(RallyPalette.danger)
                    .frame(minHeight: 58)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func settingsButton(_ title: String, destination: NativeProfileSettings) -> some View {
        Button { settingsSheet = destination } label: {
            HStack {
                Text(title).font(RallyType.body(16, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MP.ink3)
            }
            .foregroundStyle(MP.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func stars(_ value: Double) -> some View {
        HStack(spacing: 2) { ForEach(1...5, id: \.self) { index in Image(systemName: Double(index) <= value.rounded() ? "star.fill" : "star").font(.system(size: 10)).foregroundStyle(MP.accentText(app.activeSport)) } }
    }
}

private struct MPRatingInfoSheet: View {
    let sport: Sport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(RallyPalette.ink.opacity(0.16))
                .frame(width: 42, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How MP rating works")
                        .font(RallyType.title)
                        .rallyDisplayLeading()
                    Text("A sport-specific competitive rating that changes only after verified results.")
                        .font(RallyType.body(14))
                        .foregroundStyle(RallyPalette.inkMuted)
                }
                Spacer(minLength: 8)
                CloseIconButton { dismiss() }
            }
            .padding(.horizontal, RallyLayout.gutter)
            .padding(.top, 16)
            .padding(.bottom, 18)

            Divider().overlay(RallyPalette.rule)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("80")
                                .font(RallyType.numeral(48))
                            Text("Starting rating")
                                .font(RallyType.caption)
                                .foregroundStyle(RallyPalette.inkMuted)
                        }
                        Spacer()
                        Text("\(sport.title.uppercased()) ONLY")
                            .font(RallyType.eyebrow)
                            .tracking(1)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(sport.rallyAccent, in: Capsule())
                    }

                    infoRow(
                        icon: "arrow.up.right",
                        title: "Verified wins move it gradually",
                        detail: "Most results change 1–2 points. Beating a stronger opponent can earn 3–5."
                    )
                    infoRow(
                        icon: "arrow.down.right",
                        title: "The matchup affects the change",
                        detail: "An unexpected loss costs more than losing to a stronger opponent. Expected wins move less."
                    )
                    infoRow(
                        icon: "checkmark.seal",
                        title: "Both players confirm the result",
                        detail: "Your rating and statistics update only after you and your opponent agree on the scores."
                    )
                    infoRow(
                        icon: "square.stack.3d.up",
                        title: "Every sport stays separate",
                        detail: "Your \(sport.title) rating does not change your standing in any other sport, and there is no upper ceiling."
                    )
                }
                .padding(RallyLayout.gutter)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RallyPalette.cream.ignoresSafeArea())
        .foregroundStyle(RallyPalette.ink)
        .preferredColorScheme(.light)
    }

    private func infoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 42, height: 42)
                .background(sport.rallyAccent.opacity(0.82), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(RallyType.action)
                Text(detail)
                    .font(RallyType.caption)
                    .foregroundStyle(RallyPalette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct NativeProfileSettingsSheet: View {
    let destination: NativeProfileSettings
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draftName = ""
    @State private var draftUsername = ""
    @State private var draftAge = 18
    @State private var draftGender = Gender.nonBinary
    @State private var draftAvatar = Avatar.fallback
    @State private var privacyValues = [true, true, true, true]
    @State private var notificationValues = [true, true, true, false]
    @State private var notice: String?

    private var title: String {
        switch destination {
        case .editProfile: "Edit profile details"
        case .manageSports: "Manage your sports"
        case .privacy: "Privacy and visibility"
        case .notifications: "Notification preferences"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, RallyLayout.gutter)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .background(RallyPalette.cream)
                .zIndex(10)
            Divider().overlay(RallyPalette.rule)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    switch destination {
                    case .editProfile: editProfile
                    case .manageSports: manageSports
                    case .privacy: settingsRows(privacyLabels, values: $privacyValues)
                    case .notifications: settingsRows(notificationLabels, values: $notificationValues)
                    }
                    saveButton
                }
                .padding(RallyLayout.gutter)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(RallyPalette.cream.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let notice {
                Text(notice)
                    .font(RallyType.caption)
                    .foregroundStyle(RallyPalette.cream)
                    .padding(.horizontal, 14).frame(minHeight: 42)
                    .background(RallyPalette.ink, in: Capsule())
                    .padding(.top, 68)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            draftName = app.me.name
            draftUsername = app.me.username
            draftAge = app.me.age
            draftGender = app.me.gender
            draftAvatar = app.me.avatar
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text(title).font(RallyType.title).rallyDisplayLeading()
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .frame(width: 44, height: 44)
                    .background(RallyPalette.creamDeep, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var editProfile: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Avatar").rallyEyebrow()
                HStack(spacing: 14) {
                    AvatarView(avatar: draftAvatar, size: 74)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Choose your player")
                            .font(RallyType.action)
                        Text("This avatar appears across your profile, chats, map, and home screen.")
                            .font(RallyType.caption)
                            .foregroundStyle(RallyPalette.inkMuted)
                    }
                }
                AvatarChoiceStrip(selection: $draftAvatar, size: 62)
            }
            .padding(14)
            .background(RallyPalette.creamDeep.opacity(0.42), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            brandedField("Name", text: $draftName)
            brandedField("Unique username", text: $draftUsername, autocapitalization: false)
            HStack {
                Text("Age").font(RallyType.body(15, weight: .semibold))
                Spacer()
                Button { draftAge = max(13, draftAge - 1) } label: { counterIcon("minus") }
                Text("\(draftAge)").font(RallyType.numeral(22)).frame(width: 44)
                Button { draftAge = min(99, draftAge + 1) } label: { counterIcon("plus") }
            }
            .padding(16)
            .background(RallyPalette.creamDeep.opacity(0.58), in: Capsule())
            Text("Gender").rallyEyebrow()
            VerticalChoiceList(
                options: Gender.allCases.map(\.rawValue),
                selection: Binding(get: { draftGender.rawValue }, set: { draftGender = Gender(rawValue: $0) ?? draftGender }),
                selectedFill: RallyPalette.creamDeep,
                selectedForeground: RallyPalette.ink
            )
        }
    }

    private var manageSports: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pickleball and Badminton are available in this beta. Other sports are coming soon.")
                .font(RallyType.body(15)).foregroundStyle(RallyPalette.inkMuted)
            ForEach(SportCategory.allCases, id: \.self) { category in
                Text(category.rawValue).rallyEyebrow().padding(.top, 8)
                ForEach(Sport.supported.filter { $0.category == category }) { sport in
                    SelectableCard(
                        title: sport.title,
                        sport: sport,
                        isSelected: app.mySports.contains(sport),
                        isDisabled: !sport.isAvailableInBeta || (app.mySports.count >= Sport.betaAvailable.count && !app.mySports.contains(sport))
                    ) { toggleSport(sport) }
                    if !sport.isAvailableInBeta {
                        Text("COMING SOON")
                            .rallyEyebrow(MP.ink3)
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    private var privacyLabels: [String] {
        ["Show me on the player map", "Display my rating publicly", "Allow messages from anyone nearby", "Show my calendar to my squad"]
    }

    private var notificationLabels: [String] {
        ["Challenge invitations", "Calendar changes", "Connection requests", "Community announcements"]
    }

    private func settingsRows(_ labels: [String], values: Binding<[Bool]>) -> some View {
        VStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                RallyCheckbox(
                    title: labels[index],
                    isOn: Binding(get: { values.wrappedValue[index] }, set: { values.wrappedValue[index] = $0 })
                )
                .padding(.vertical, 15)
                if index < labels.count - 1 { Divider().overlay(RallyPalette.rule) }
            }
        }
    }

    private var saveButton: some View {
        Button {
            if destination == .editProfile {
                app.me.name = draftName
                app.me.username = draftUsername.replacingOccurrences(of: "@", with: "")
                app.me.age = draftAge
                app.me.gender = draftGender
                app.me.avatar = draftAvatar
            }
            if destination == .editProfile || destination == .manageSports {
                Task {
                    if await app.persistProfileChanges() { dismiss() }
                }
            } else {
                dismiss()
            }
        } label: {
            Text(destination == .manageSports ? "Done" : "Save changes")
                .font(RallyType.action)
                .foregroundStyle(RallyPalette.cream)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RallyPalette.ink, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func brandedField(_ label: String, text: Binding<String>, autocapitalization: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).rallyEyebrow()
            TextField(label, text: text)
                .textInputAutocapitalization(autocapitalization ? .words : .never)
                .autocorrectionDisabled(!autocapitalization)
                .font(RallyType.body())
                .padding(.horizontal, 17).frame(height: 54)
                .background(RallyPalette.creamDeep.opacity(0.58), in: Capsule())
        }
    }

    private func counterIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .frame(width: 44, height: 44)
            .background(MP.accent(app.activeSport), in: Circle())
    }

    private func toggleSport(_ sport: Sport) {
        guard sport.isAvailableInBeta else {
            notice = "\(sport.title) is coming soon."
            return
        }
        if let index = app.mySports.firstIndex(of: sport) {
            guard app.mySports.count > 1 else {
                notice = "You must keep at least one sport."
                return
            }
            app.mySports.remove(at: index)
            app.me.profiles.removeValue(forKey: sport)
            if app.activeSport == sport { app.activeSport = app.mySports[0] }
        } else {
            guard app.mySports.count < Sport.betaAvailable.count else {
                notice = "Pickleball and Badminton are the two sports in this beta."
                return
            }
            app.mySports.append(sport)
            app.me.profiles[sport] = SportProfile(
                sport: sport,
                peerSkillRatings: sport.skillCategories.map { PeerSkillRating(category: $0, average: 0, count: 0) }
            )
        }
    }
}

private enum NotificationActivityFilter: String, CaseIterable {
    case all = "All"
    case verifications = "Verifications"
    case challenges = "Challenges"
    case connections = "Connections"
}

private enum NotificationSportFilter: String, CaseIterable {
    case all = "All sports"
    case pickleball = "Pickleball"
    case badminton = "Badminton"

    var sport: Sport? {
        switch self {
        case .all: nil
        case .pickleball: .pickleball
        case .badminton: .badminton
        }
    }
}

private enum NotificationAgeFilter: String, CaseIterable {
    case all = "All activity"
    case new = "New"
    case earlier = "Earlier"
}

private enum NotificationFilterPanel: CaseIterable {
    case activity
    case sport
    case age
}

private struct NativeNotificationsPage: View {
    @EnvironmentObject private var app: AppState
    let onBack: () -> Void
    @State private var selectedPlayer: Player?
    @State private var selectedVerification: FaceOff?
    @State private var selectedChallenge: FaceOff?
    @State private var activityFilter: NotificationActivityFilter = .all
    @State private var sportFilter: NotificationSportFilter = .all
    @State private var ageFilter: NotificationAgeFilter = .all
    @State private var activeFilter: NotificationFilterPanel?

    private var requestPlayers: [Player] {
        guard activityFilter == .all || activityFilter == .connections,
              ageFilter != .earlier else { return [] }
        return app.players.filter {
            app.incomingFriendRequestIds.contains($0.id) &&
            (sportFilter.sport == nil || $0.profile(sportFilter.sport!) != nil)
        }
    }
    private var verifications: [FaceOff] {
        guard activityFilter == .all || activityFilter == .verifications,
              ageFilter != .earlier else { return [] }
        return app.faceOffs.filter {
            (sportFilter.sport == nil || $0.sport == sportFilter.sport) &&
            $0.state == .awaitingResult && $0.reportedWinnerByThem != nil
        }
    }
    private var challenges: [FaceOff] {
        guard activityFilter == .all || activityFilter == .challenges,
              ageFilter != .earlier else { return [] }
        return app.faceOffs.filter {
            (sportFilter.sport == nil || $0.sport == sportFilter.sport) &&
            $0.state == .proposed && !$0.proposedByMe
        }
    }
    private var earlierRecords: [MatchRecord] {
        guard activityFilter == .all, ageFilter != .new else { return [] }
        return Array(app.matchHistory.filter {
            sportFilter.sport == nil || $0.sport == sportFilter.sport
        }.prefix(8))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 46, height: 46)
                        .background(MP.surface2, in: Circle())
                }
                .buttonStyle(RallyPressStyle())
                .accessibilityLabel("Back")
                Text("Notifications").font(RallyType.title).rallyDisplayLeading()
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(MP.background)
            Divider().overlay(MP.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 7) {
                        notificationFilterButton(.activity, title: activityFilter.rawValue, icon: "line.3.horizontal.decrease")
                        notificationFilterButton(.sport, title: sportFilter.rawValue, icon: "sport-outline")
                        notificationFilterButton(.age, title: ageFilter.rawValue, icon: "clock")
                    }
                    .overlay(alignment: .top) {
                        if let activeFilter {
                            HStack(alignment: .top, spacing: 7) {
                                ForEach(NotificationFilterPanel.allCases, id: \.self) { panel in
                                    if panel == activeFilter {
                                        notificationFilterPanel(panel)
                                    } else {
                                        Color.clear.frame(height: 1)
                                    }
                                }
                            }
                            .padding(.top, 51)
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.16), value: activeFilter)
                    .zIndex(10)

                if requestPlayers.isEmpty && verifications.isEmpty && challenges.isEmpty && earlierRecords.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash").font(.system(size: 30, weight: .medium))
                        Text("You are all caught up.").font(RallyType.cardTitle)
                        Text("New challenges, verifications, and connection requests will appear here.")
                            .font(RallyType.body()).foregroundStyle(MP.ink3).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 56)
                } else {
                    if !requestPlayers.isEmpty || !verifications.isEmpty || !challenges.isEmpty {
                        Text("NEW").rallyEyebrow(MP.ink3)
                    }

                    ForEach(requestPlayers) { player in
                        notificationRow(player: player, text: "sent you a connection request.") {
                            HStack(spacing: 6) {
                                Button("Delete") { app.declineFriendRequest(from: player.id) }
                                    .notificationAction(primary: false)
                                Button("Accept") { app.acceptFriendRequest(from: player.id) }
                                    .notificationAction(primary: true)
                            }
                        }
                    }
                    ForEach(verifications) { faceOff in
                        if let player = app.player(faceOff.opponentId) {
                            notificationRow(player: player, text: "submitted a score for you to verify.") {
                                Button("Verify") { selectedVerification = faceOff }
                                    .notificationAction(primary: true)
                            }
                        }
                    }
                    ForEach(challenges) { faceOff in
                        if let player = app.player(faceOff.opponentId) {
                            notificationRow(player: player, text: "proposed \(faceOff.proposedDates.count) challenge times.") {
                                Button { selectedChallenge = faceOff } label: {
                                    Image(systemName: "trophy").font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(MP.ink).frame(width: 44, height: 44)
                                        .background(MP.accent(app.activeSport), in: Circle())
                                }
                                .buttonStyle(RallyPressStyle())
                            }
                        }
                    }

                    if !earlierRecords.isEmpty {
                        if !app.notificationsMarkedRead {
                            Text("EARLIER").rallyEyebrow(MP.ink3).padding(.top, 10)
                        }
                        ForEach(earlierRecords) { record in
                            earlierNotificationRow(record)
                        }
                    }

                }
                }
                .padding(20)
            }
        }
        .background(MP.background.ignoresSafeArea()).foregroundStyle(MP.ink).preferredColorScheme(.light)
        .onAppear {
            app.markAllNotificationsRead()
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demo-notification-filter") {
                activeFilter = .activity
            }
#endif
        }
        .sheet(item: $selectedPlayer) {
            ProfileDetailView(player: $0).presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedVerification) { NativeVerificationDetail(faceOff: $0) }
        .sheet(item: $selectedChallenge) { NativeChallengeDetail(faceOff: $0) }
    }

    private func notificationFilterButton(_ panel: NotificationFilterPanel, title: String, icon: String) -> some View {
        Button {
            activeFilter = activeFilter == panel ? nil : panel
        } label: {
            HStack(spacing: 5) {
                if icon == "sport-outline" {
                    SportIcon(sport: sportFilter.sport ?? app.activeSport, size: 15, color: MP.ink)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Spacer(minLength: 1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(activeFilter == panel ? 180 : 0))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(MP.ink)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(MP.surface2, in: Capsule())
        }
        .buttonStyle(RallyPressStyle())
        .frame(maxWidth: .infinity)
    }

    private func notificationFilterPanel(_ panel: NotificationFilterPanel) -> some View {
        VStack(spacing: 4) {
            ForEach(notificationOptions(panel), id: \.self) { option in
                let selected = selectedNotificationOption(panel) == option
                Button {
                    applyNotificationOption(option, to: panel)
                    activeFilter = nil
                } label: {
                    HStack(spacing: 5) {
                        Text(option)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Spacer(minLength: 2)
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(selected ? MP.background : MP.ink)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(selected ? MP.ink : .clear, in: Capsule())
                }
                .buttonStyle(RallyPressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(5)
        .frame(maxWidth: .infinity)
        .background(MP.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .rallyLifted(0.7)
    }

    private func notificationOptions(_ panel: NotificationFilterPanel) -> [String] {
        switch panel {
        case .activity: NotificationActivityFilter.allCases.map(\.rawValue)
        case .sport: NotificationSportFilter.allCases.map(\.rawValue)
        case .age: NotificationAgeFilter.allCases.map(\.rawValue)
        }
    }

    private func selectedNotificationOption(_ panel: NotificationFilterPanel) -> String {
        switch panel {
        case .activity: activityFilter.rawValue
        case .sport: sportFilter.rawValue
        case .age: ageFilter.rawValue
        }
    }

    private func applyNotificationOption(_ option: String, to panel: NotificationFilterPanel) {
        switch panel {
        case .activity:
            activityFilter = NotificationActivityFilter(rawValue: option) ?? .all
        case .sport:
            sportFilter = NotificationSportFilter(rawValue: option) ?? .all
        case .age:
            ageFilter = NotificationAgeFilter(rawValue: option) ?? .all
        }
    }

    private func notificationRow<Action: View>(player: Player, text: String, @ViewBuilder action: () -> Action) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 12) {
                Button { selectedPlayer = player } label: {
                    RallyPlayerAvatar(player: player, size: 48, ring: MP.accent(app.activeSport), ringWidth: 2.5)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.name).font(RallyType.action) + Text(" \(text)").font(RallyType.body())
                    Text("Recently").font(RallyType.caption).foregroundStyle(MP.ink3)
                }
                Spacer(minLength: 5)
            }
            HStack {
                Spacer()
                action()
            }
        }
        .padding(14)
        .background(MP.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(MP.line))
    }

    private func earlierNotificationRow(_ record: MatchRecord) -> some View {
        HStack(spacing: 12) {
            AvatarView(avatar: record.opponentAvatar, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.opponentName).font(RallyType.action)
                    + Text(record.didWin
                           ? " lost to you, and your rating moved to \(record.ratingAfter)."
                           : " completed your match at \(record.venue).")
                        .font(RallyType.body())
                Text(record.date.formatted(.relative(presentation: .numeric)))
                    .font(RallyType.caption).foregroundStyle(MP.ink3)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(MP.ink4)
        }
        .padding(14)
        .background(MP.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(MP.line))
    }
}

private extension View {
    func notificationAction(primary: Bool) -> some View {
        self.font(.system(size: 12, weight: .bold))
            .foregroundStyle(primary ? RallyPalette.cream : MP.ink)
            .padding(.horizontal, 13).frame(height: 40)
            .background(primary ? MP.ink : MP.surface2, in: Capsule())
            .overlay(Capsule().stroke(primary ? Color.clear : MP.line, lineWidth: 1))
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
                    HStack(spacing: 12) {
                        Text("MATCHES PLAYED").font(.system(size: 11, weight: .heavy)).tracking(0.8).foregroundStyle(MP.ink3)
                        Spacer()
                        matchCountButton("minus") { matches = max(1, matches - 1) }
                        Text("\(matches)").font(RallyType.numeral(24)).frame(minWidth: 28)
                        matchCountButton("plus") { matches = min(5, matches + 1) }
                    }
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
    private func matchCountButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MP.background)
                .frame(width: 42, height: 42)
                .background(MP.ink, in: Circle())
        }
        .buttonStyle(RallyPressStyle())
    }
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
            .navigationTitle("Who did you play?")
            .navigationBarTitleDisplayMode(.inline)
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
    @State private var title = ""
    @State private var team = ""
    @State private var opponent = ""
    @State private var date = Date().addingTimeInterval(86_400)
    @State private var endDate = Date().addingTimeInterval(86_400 + 10_800)
    @State private var venue = "Riverside Sports Ground"

    private var complete: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !team.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !opponent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("A \(app.activeSport.title) fixture for your squad.")
                        .font(RallyType.body())
                        .foregroundStyle(RallyPalette.inkMuted)
                    fixtureField("TITLE", placeholder: "League fixture", text: $title)
                    fixtureField("YOUR TEAM", placeholder: "Riverside XI", text: $team)
                    fixtureField("OPPONENT", placeholder: "Cedar Street CC", text: $opponent)
                    RallyDateTimeSelector(label: "Starts", selection: $date)
                    RallyDateTimeSelector(label: "Ends", selection: $endDate)
                    fixtureField("LOCATION", placeholder: "Venue or ground", text: $venue)
                    Text("Everyone in your squad sees this fixture. After the date has passed, you will be prompted to add the result.")
                        .font(RallyType.caption).foregroundStyle(MP.ink3)
                    RallyPillButton(title: "Save game", icon: "calendar.badge.plus", style: .ink, fill: true, enabled: complete) {
                        app.addGroupFixture(
                            sport: app.activeSport,
                            title: title,
                            team: team,
                            opponent: opponent,
                            date: date,
                            endDate: endDate,
                            venue: venue
                        )
                        dismiss()
                    }
                }
                .padding(RallyLayout.gutter)
            }
            .background(RallyPalette.cream)
            .navigationTitle("Add a game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { CloseIconButton { dismiss() } } }
        }
    }

    private func fixtureField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).rallyEyebrow(MP.ink3)
            TextField(placeholder, text: text)
                .font(RallyType.body())
                .padding(.horizontal, 18).frame(height: 56)
                .background(RallyPalette.creamDeep, in: Capsule())
                .overlay(Capsule().stroke(MP.line, lineWidth: 1))
        }
    }
}
