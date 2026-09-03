import SwiftUI
import Combine
import CoreLocation

/// UI-facing state. Prototype data remains available for design previews while
/// authenticated profile data is loaded and persisted through the repository.
@MainActor
final class AppState: ObservableObject {
    private let availabilityStorageKey = "picklematch.profile.availability.v1"
    private let avatarStorageKey = "picklematch.profile.avatar.v1"

    // MARK: Onboarding / me
    @Published var hasCompletedOnboarding = false
    @Published var me = MockData.emptyMe()
    /// Sports the user opted into during onboarding.
    @Published var mySports: [Sport] = []
    /// Which sport "mode" the app is currently showing.
    @Published var activeSport: Sport = .pickleball {
        didSet {
            objectWillChange.send()
            guard hydratedUserID != nil else { return }
            Task {
                async let players: Void = refreshCommunity()
                async let communities: Void = refreshNearbyCommunities()
                _ = await (players, communities)
            }
        }
    }

    // MARK: Community
    @Published var players: [Player] = []
    @Published var conversations: [Conversation] = []
    @Published var faceOffs: [FaceOff] = []
    @Published var groupFixtures: [GroupFixture] = []
    @Published var matchHistory: [MatchRecord] = []
    @Published var friendIds: Set<UUID> = []
    @Published var incomingFriendRequestIds: Set<UUID> = []
    @Published var outgoingFriendRequestIds: Set<UUID> = []
    @Published var friendCountOverride: Int = 0
    @Published var hasUnsavedDraft = false
    @Published var notificationsMarkedRead = false
    @Published private(set) var isHydratingBackend = false
    @Published private(set) var hasHydratedBackend = false
    @Published private(set) var backendSyncError: String?
    @Published private(set) var remoteUnreadNotificationCount = 0
    @Published private(set) var unreadConversationIDs: Set<UUID> = []
    @Published private(set) var isRefreshingCommunity = false
    @Published private(set) var nearbyCommunities: [NearbyCommunity] = []
    @Published private(set) var isRefreshingCommunities = false

    // MARK: Discover filters (per session)
    @Published var filters = DiscoverFilters()

    private let profileRepository: ProfileRepository?
    private let productionRepository: ProductionRepository?
    private let courtDiscoveryService: CourtDiscoveryService
    private var hydratedUserID: UUID?
    private var connectionIDsByPeer: [UUID: UUID] = [:]
    private var latestLocation: CLLocation?

    init(
        profileRepository: ProfileRepository? = BackendDependencies.shared.profiles,
        productionRepository: ProductionRepository? = BackendDependencies.shared.production,
        courtDiscoveryService: CourtDiscoveryService = CourtDiscoveryService()
    ) {
        self.profileRepository = profileRepository
        self.productionRepository = productionRepository
        self.courtDiscoveryService = courtDiscoveryService
        players = MockData.players()
        conversations = MockData.conversations(players: players)
        faceOffs = MockData.faceOffs(players: players)
        matchHistory = MockData.matchHistory()
        for index in matchHistory.indices.prefix(4) where !players.isEmpty {
            let opponent = players[index % min(2, players.count)]
            matchHistory[index].opponentId = opponent.id
            matchHistory[index].opponentName = opponent.name
            matchHistory[index].opponentAvatar = opponent.avatar
            matchHistory[index].sport = .pickleball
        }
        friendIds = Set(players.prefix(2).map(\.id))
        if players.indices.contains(2) { incomingFriendRequestIds.insert(players[2].id) }
        for index in conversations.indices {
            conversations[index].isMessageRequest = !friendIds.contains(conversations[index].partnerId)
        }
        if let data = UserDefaults.standard.data(forKey: availabilityStorageKey),
           let saved = try? JSONDecoder().decode([AvailabilitySlot].self, from: data) {
            me.availability = saved
        }
        if let data = UserDefaults.standard.data(forKey: avatarStorageKey),
           let saved = try? JSONDecoder().decode(Avatar.self, from: data) {
            me.avatar = saved
        }

#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo-established") {
            loadEstablishedPrototype()
        }
        if ProcessInfo.processInfo.arguments.contains("-demo-main") {
            var demo = MockData.emptyMe()
            demo.name = "Alex"
            demo.age = 27
            demo.bio = "Always down for a close match and post-game tacos."
            demo.profiles[.pickleball] = SportProfile(
                sport: .pickleball,
                rating: 84,
                partnerStatus: .lookingForPartner,
                homeCourt: "Zilker Courts",
                ownsEquipment: true,
                playedTournaments: false,
                selfAssessment: .casual,
                ratingHistory: matchHistory.prefix(8).map {
                    RatingPoint(date: $0.date, rating: $0.ratingAfter)
                }
            )
            demo.profiles[.badminton] = SportProfile(
                sport: .badminton,
                rating: 80,
                partnerStatus: .solo,
                homeCourt: "Rec Center",
                ownsEquipment: true,
                playedTournaments: false,
                selfAssessment: .casual,
                ratingHistory: [RatingPoint(date: .now, rating: EloRating.start)]
            )
            demo.profiles[.soccer] = SportProfile(
                sport: .soccer,
                peerSkillRatings: .demo(for: .soccer)
            )
            me = demo
            if me.availability.isEmpty {
                me.availability = MockData.sampleAvailability(seed: 0)
            }
            mySports = [.pickleball, .badminton, .soccer]
            activeSport = .pickleball
            hasCompletedOnboarding = true
            faceOffs.append(contentsOf: MockData.pendingVerifications(players: players))
            faceOffs.append(contentsOf: MockData.sentVerifications(players: players))
            nearbyCommunities = MockData.nearbyCommunities()
        }
#endif
    }

    func hydrateAuthenticatedUser(id: UUID) async {
        guard hydratedUserID != id else { return }
        guard let profileRepository else {
            backendSyncError = "The profile service is not configured."
            hasHydratedBackend = true
            return
        }
        isHydratingBackend = true
        backendSyncError = nil
        defer {
            hydratedUserID = id
            isHydratingBackend = false
            hasHydratedBackend = true
        }

        do {
            let snapshot = try await profileRepository.fetchProfile(userID: id)
            me = snapshot.player
            let betaSports = snapshot.sports.filter(\.isAvailableInBeta)
            mySports = betaSports.isEmpty ? [.pickleball] : betaSports
            activeSport = mySports.first ?? .pickleball
            hasCompletedOnboarding = snapshot.onboardingCompleted

            // Never mix the real signed-in account with prototype community data.
            players = []
            conversations = []
            faceOffs = []
            groupFixtures = []
            matchHistory = []
            nearbyCommunities = []
            friendIds = []
            incomingFriendRequestIds = []
            outgoingFriendRequestIds = []
            hydratedUserID = id
            async let community: Void = refreshCommunity()
            async let inbox: Void = refreshInbox()
            async let matchbook: Void = refreshMatchbook()
            _ = await (community, inbox, matchbook)
        } catch {
            // The auth trigger creates an intentionally incomplete profile row.
            // Preserve the authenticated identity while onboarding fills it in.
            loadNewUserPrototype()
            me.id = id
            backendSyncError = error.localizedDescription
        }
    }

    var myProfile: SportProfile? { me.profiles[activeSport] }
    var themeColor: Color { Theme.color(for: activeSport) }
    var hasMultipleSports: Bool { mySports.count > 1 }
    var displayedFriendCount: Int { max(friendIds.count, friendCountOverride) }
    var notificationCount: Int {
        if hydratedUserID != nil { return remoteUnreadNotificationCount }
        guard !notificationsMarkedRead else { return 0 }
        let verificationCount = faceOffs.filter {
            $0.sport == activeSport && $0.state == .awaitingResult && $0.reportedWinnerByThem != nil
        }.count
        let challengeCount = faceOffs.filter {
            $0.sport == activeSport && $0.state == .proposed && !$0.proposedByMe
        }.count
        let requestCount = players.filter {
            incomingFriendRequestIds.contains($0.id) && $0.profile(activeSport) != nil
        }.count
        return requestCount + verificationCount + challengeCount
    }

    func syncLocationAndRefresh(_ location: CLLocation) async {
        guard let productionRepository, hydratedUserID != nil else { return }
        do {
            latestLocation = location
            try await productionRepository.updateLocation(location)
            async let playerRefresh: Void = refreshCommunity()
            async let communityRefresh: Void = refreshNearbyCommunities(discoverWith: location)
            _ = await (playerRefresh, communityRefresh)
        } catch {
            backendSyncError = error.localizedDescription
        }
    }

    func disableLocationDiscovery() async {
        guard let productionRepository else { return }
        do {
            try await productionRepository.clearLocation()
            players = []
            nearbyCommunities = []
        } catch {
            backendSyncError = error.localizedDescription
        }
    }

    func refreshNearbyCommunities(discoverWith location: CLLocation? = nil) async {
        guard let productionRepository, hydratedUserID != nil, activeSport.isAvailableInBeta else {
            nearbyCommunities = []
            return
        }
        isRefreshingCommunities = true
        defer { isRefreshingCommunities = false }
        do {
            if let location = location ?? latestLocation {
                let discovered = try await courtDiscoveryService.discover(
                    sport: activeSport,
                    near: location,
                    radiusMiles: filters.maxDistance
                )
                try await productionRepository.syncDiscoveredCourts(discovered)
            }
            nearbyCommunities = try await productionRepository.fetchNearbyCommunities(
                sport: activeSport,
                radiusMiles: filters.maxDistance
            )
        } catch {
            backendSyncError = error.localizedDescription
        }
    }

    func communityDetail(clubID: UUID) async -> CommunityDetailSnapshot? {
        do {
            return try await productionRepository?.fetchCommunityDetail(clubID: clubID)
        } catch {
            backendSyncError = error.localizedDescription
            return nil
        }
    }

    func setClubMembership(clubID: UUID, join: Bool) async -> Bool {
        guard let productionRepository else { return false }
        do {
            try await productionRepository.setClubMembership(clubID: clubID, join: join)
            await refreshNearbyCommunities()
            return true
        } catch {
            backendSyncError = error.localizedDescription
            return false
        }
    }

    func createClub(at courtID: UUID, name: String, description: String) async -> UUID? {
        guard let productionRepository else { return nil }
        do {
            let id = try await productionRepository.createClub(
                sport: activeSport, courtID: courtID, name: name, description: description
            )
            await refreshNearbyCommunities()
            return id
        } catch {
            backendSyncError = error.localizedDescription
            return nil
        }
    }

    func createCommunityGroup(clubID: UUID, name: String, description: String) async -> UUID? {
        guard let productionRepository else { return nil }
        do {
            return try await productionRepository.createCommunityGroup(
                clubID: clubID, name: name, description: description
            )
        } catch {
            backendSyncError = error.localizedDescription
            return nil
        }
    }

    func setCommunityGroupMembership(groupID: UUID, join: Bool) async -> Bool {
        guard let productionRepository else { return false }
        do {
            try await productionRepository.setCommunityGroupMembership(groupID: groupID, join: join)
            return true
        } catch {
            backendSyncError = error.localizedDescription
            return false
        }
    }

    func permanentlyDeleteAccount() async -> Bool {
        guard let productionRepository else {
            backendSyncError = "The account service is unavailable."
            return false
        }
        do {
            try await productionRepository.deleteAccount()
            return true
        } catch {
            backendSyncError = error.localizedDescription
            return false
        }
    }

    func refreshCommunity() async {
        guard let productionRepository, hydratedUserID != nil, !isRefreshingCommunity else { return }
        isRefreshingCommunity = true
        defer { isRefreshingCommunity = false }
        do {
            let cachedPlayers = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
            let snapshot = try await productionRepository.fetchCommunity(
                sport: activeSport,
                radiusMiles: filters.maxDistance
            )
            players = snapshot.players
            // Keep chat participants who may be outside the current discovery radius.
            for conversation in conversations {
                for participantID in participantIds(for: conversation)
                    where !players.contains(where: { $0.id == participantID }) {
                    if let cached = cachedPlayers[participantID] { players.append(cached) }
                }
            }
            friendIds = snapshot.friendIDs
            incomingFriendRequestIds = snapshot.incomingRequestIDs
            outgoingFriendRequestIds = snapshot.outgoingRequestIDs
            connectionIDsByPeer = snapshot.connectionIDsByPeer
            remoteUnreadNotificationCount = snapshot.unreadNotificationCount
            backendSyncError = nil
        } catch {
            backendSyncError = error.localizedDescription
        }
    }

    func refreshInbox() async {
        guard let productionRepository, hydratedUserID != nil else { return }
        do {
            let snapshot = try await productionRepository.fetchInbox()
            conversations = snapshot.conversations
            unreadConversationIDs = snapshot.unreadConversationIDs
            for participant in snapshot.participants {
                if let index = players.firstIndex(where: { $0.id == participant.id }) {
                    for (sport, profile) in participant.profiles where players[index].profiles[sport] == nil {
                        players[index].profiles[sport] = profile
                    }
                } else {
                    players.append(participant)
                }
            }
        } catch {
            backendSyncError = error.localizedDescription
        }
    }

    func markAllNotificationsRead() {
        notificationsMarkedRead = true
        remoteUnreadNotificationCount = 0
        guard let productionRepository, hydratedUserID != nil else { return }
        Task {
            do { try await productionRepository.markNotificationsRead(ids: nil) }
            catch { backendSyncError = error.localizedDescription }
        }
    }

    func markAllConversationsRead() {
        let ids = hasHydratedBackend
            ? Array(unreadConversationIDs)
            : conversations.filter { !$0.isMessageRequest }.compactMap { $0.lastMessage?.fromMe == false ? $0.id : nil }
        unreadConversationIDs.removeAll()
        guard let productionRepository, hydratedUserID != nil, !ids.isEmpty else { return }
        Task {
            do { try await productionRepository.markConversationsRead(ids: ids) }
            catch { backendSyncError = error.localizedDescription }
        }
    }

    func refreshMatchbook() async {
        guard let productionRepository, hydratedUserID != nil else { return }
        do {
            let snapshot = try await productionRepository.fetchMatchbook()
            faceOffs = snapshot.faceOffs
            matchHistory = snapshot.history
            for participant in snapshot.participants {
                if let index = players.firstIndex(where: { $0.id == participant.id }) {
                    for (sport, profile) in participant.profiles where players[index].profiles[sport] == nil {
                        players[index].profiles[sport] = profile
                    }
                } else {
                    players.append(participant)
                }
            }
        } catch {
            backendSyncError = error.localizedDescription
        }
    }

    // MARK: - Prototype states

    func loadNewUserPrototype() {
        me = MockData.emptyMe()
        mySports = []
        activeSport = .pickleball
        conversations = []
        faceOffs = []
        groupFixtures = []
        matchHistory = []
        friendIds = []
        incomingFriendRequestIds = []
        outgoingFriendRequestIds = []
        friendCountOverride = 0
        notificationsMarkedRead = false
        nearbyCommunities = MockData.nearbyCommunities()
        hasCompletedOnboarding = false
    }

    func loadEstablishedPrototype() {
        players = MockData.players()
        conversations = MockData.conversations(players: players)
        faceOffs = MockData.faceOffs(players: players)
        groupFixtures = []
        matchHistory = MockData.matchHistory()

        var veteran = MockData.emptyMe()
        veteran.name = "Alex Morgan"
        veteran.username = "alexplaysall"
        veteran.gender = .nonBinary
        veteran.age = 32
        veteran.avatar = Avatar.all[2]
        veteran.bio = "Competitive when the score matters, welcoming when it does not. Always ready for one more game."
        veteran.availability = [
            AvailabilitySlot(weekday: 2, period: .evening),
            AvailabilitySlot(weekday: 7, period: .afternoon),
            AvailabilitySlot(weekday: 1, period: .morning)
        ]

        let pickleHistory = matchHistory.prefix(12).reversed().enumerated().map { index, record in
            RatingPoint(date: record.date, rating: 102 + index * 2)
        } + [RatingPoint(date: .now, rating: 125)]
        let badmintonHistory = matchHistory.prefix(10).reversed().enumerated().map { index, record in
            RatingPoint(date: record.date, rating: 101 + index * 2)
        } + [RatingPoint(date: .now, rating: 121)]

        veteran.profiles[.pickleball] = SportProfile(
            sport: .pickleball, rating: 125, partnerStatus: .hasPartner,
            homeCourt: "Zilker Courts", ownsEquipment: true, playedTournaments: true,
            selfAssessment: .tournament, ratingHistory: pickleHistory
        )
        veteran.profiles[.badminton] = SportProfile(
            sport: .badminton, rating: 121, partnerStatus: .lookingForPartner,
            homeCourt: "Austin Recreation Center", ownsEquipment: true, playedTournaments: true,
            selfAssessment: .competitive, ratingHistory: badmintonHistory
        )
        veteran.profiles[.cricket] = SportProfile(
            sport: .cricket, ratingOptOut: true, socialSkillLabel: .amateur,
            peerSkillRatings: [
                PeerSkillRating(category: "Batting", average: 4.7, count: 28),
                PeerSkillRating(category: "Bowling", average: 4.4, count: 24),
                PeerSkillRating(category: "Fielding", average: 4.8, count: 31)
            ], partnerStatus: .hasPartner, homeCourt: "Roy G. Guerrero Cricket Ground",
            ownsEquipment: true, playedTournaments: true, selfAssessment: .competitive
        )

        me = veteran
        mySports = [.pickleball, .badminton, .cricket]
        activeSport = .pickleball
        friendIds = Set(players.prefix(6).map(\.id))
        friendCountOverride = 42
        incomingFriendRequestIds = Set(players.dropFirst(6).prefix(2).map(\.id))
        outgoingFriendRequestIds = []
        notificationsMarkedRead = false

        let calendar = Calendar.current
        func fixtureDate(days: Int, hour: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: days, to: .now) ?? .now
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }
        groupFixtures = [
            GroupFixture(sport: .cricket, title: "League fixture", team: "Riverside XI", opponent: "Cedar Street CC", date: fixtureDate(days: 3, hour: 11), endDate: fixtureDate(days: 3, hour: 15), venue: "Roy G. Guerrero Cricket Ground"),
            GroupFixture(sport: .cricket, title: "T20 cup", team: "Riverside XI", opponent: "East Austin Strikers", date: fixtureDate(days: 6, hour: 14), endDate: fixtureDate(days: 6, hour: 17), venue: "Fairmont Cricket Ground"),
            GroupFixture(sport: .cricket, title: "League fixture", team: "Riverside XI", opponent: "North Loop CC", date: fixtureDate(days: -5, hour: 10), endDate: fixtureDate(days: -5, hour: 14), venue: "Zilker Cricket Field", result: GroupFixtureResult(outcome: .won, summary: "Won by 24 runs")),
            GroupFixture(sport: .cricket, title: "Friendly", team: "Riverside XI", opponent: "Mueller XI", date: fixtureDate(days: -2, hour: 17), endDate: fixtureDate(days: -2, hour: 20), venue: "Mueller Sports Ground")
        ]

        // Sashank's established state includes score reports waiting for this
        // player to verify, plus both incoming and outgoing challenge proposals.
        // Keep these as real FaceOff records so every home action updates the
        // same data shown in Chats, Matches, and the calendar.
        faceOffs.append(contentsOf: MockData.pendingVerifications(players: players))
        if players.count > 5 {
            let first = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
            let second = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
            let third = Calendar.current.date(byAdding: .day, value: 5, to: .now) ?? .now
            faceOffs.append(
                FaceOff(
                    sport: .pickleball,
                    opponentId: players[4].id,
                    opponentName: players[4].name,
                    date: first,
                    proposedDates: [first, second, third],
                    venue: "Mueller Lake Park Courts",
                    wager: "Bragging rights",
                    state: .proposed,
                    proposedByMe: false
                )
            )
            faceOffs.append(
                FaceOff(
                    sport: .pickleball,
                    opponentId: players[5].id,
                    opponentName: players[5].name,
                    date: second,
                    proposedDates: [second, third],
                    venue: "Riverside Courts",
                    wager: "Loser buys coffee",
                    state: .proposed,
                    proposedByMe: true
                )
            )
        }

        let baseConversations = conversations
        for sport in [Sport.badminton, .cricket] {
            for original in baseConversations.prefix(2) {
                var copy = original
                copy.id = UUID()
                copy.sport = sport
                copy.isMessageRequest = false
                conversations.append(copy)
            }
        }
        for requestPlayer in players.dropFirst(6).prefix(2) {
            conversations.append(
                Conversation(
                    partnerId: requestPlayer.id,
                    sport: .pickleball,
                    messages: [ChatMessage(fromMe: false, kind: .text("Would you like to play this week?"))],
                    isMessageRequest: true
                )
            )
        }
        for index in conversations.indices {
            conversations[index].isMessageRequest = incomingFriendRequestIds.contains(conversations[index].partnerId)
        }

        let badmintonRecords = matchHistory.prefix(8).enumerated().map { index, original -> MatchRecord in
            var copy = original
            copy.id = UUID()
            copy.sport = .badminton
            copy.ratingBefore = 105 + index * 2
            copy.ratingAfter = min(121, copy.ratingBefore + (copy.didWin ? 2 : -1))
            copy.source = index.isMultiple(of: 2) ? .unscheduled : .scheduled
            return copy
        }
        matchHistory.append(contentsOf: badmintonRecords)
        hasCompletedOnboarding = true
    }

    // MARK: - Onboarding completion

    func completeOnboarding() {
        let betaSports = mySports.filter(\.isAvailableInBeta)
        mySports = betaSports.isEmpty ? [.pickleball] : betaSports
        me.profiles = me.profiles.filter { $0.key.isAvailableInBeta }
        // Seed my rating history with the starting point.
        for sport in mySports {
            if me.profiles[sport] == nil {
                me.profiles[sport] = SportProfile(sport: sport)
            }
            if me.profiles[sport]?.usesElo == true {
                me.profiles[sport]?.ratingHistory = [
                    RatingPoint(date: Date(), rating: me.profiles[sport]?.rating ?? EloRating.start)
                ]
            } else {
                me.profiles[sport]?.ratingHistory = []
            }
        }
        activeSport = mySports.first ?? .pickleball
        hasCompletedOnboarding = true
        persistAvailability()
        persistAvatar()
        persistProfileToBackend()
    }

    private func persistProfileToBackend() {
        guard let profileRepository else { return }
        let player = me
        let sports = mySports
        Task {
            do {
                try await profileRepository.saveOnboarding(player: player, sports: sports)
                backendSyncError = nil
            } catch {
                backendSyncError = error.localizedDescription
            }
        }
    }

    func persistProfileChanges() async -> Bool {
        guard let profileRepository else {
            backendSyncError = "The profile service is unavailable."
            return false
        }
        do {
            let sports = mySports.filter(\.isAvailableInBeta)
            try await profileRepository.saveOnboarding(
                player: me,
                sports: sports.isEmpty ? [.pickleball] : sports
            )
            backendSyncError = nil
            return true
        } catch {
            backendSyncError = error.localizedDescription
            return false
        }
    }

    func updateMyAvailability(_ slots: [AvailabilitySlot]) {
        me.availability = slots.sorted { $0.startDate < $1.startDate }
        persistAvailability()
        if hydratedUserID != nil {
            Task { _ = await persistProfileChanges() }
        }
    }

    private func persistAvailability() {
        guard let data = try? JSONEncoder().encode(me.availability) else { return }
        UserDefaults.standard.set(data, forKey: availabilityStorageKey)
    }

    private func persistAvatar() {
        guard let data = try? JSONEncoder().encode(me.avatar) else { return }
        UserDefaults.standard.set(data, forKey: avatarStorageKey)
    }

    /// Add a second (or later) sport after initial onboarding.
    func addSport(_ sport: Sport, profile: SportProfile) {
        guard sport.isAvailableInBeta,
              !mySports.contains(sport),
              mySports.count < Sport.betaAvailable.count else { return }
        mySports.append(sport)
        var p = profile
        p.ratingHistory = [RatingPoint(date: Date(), rating: p.rating)]
        me.profiles[sport] = p
    }

    // MARK: - Discover feed

    /// Players who play the active sport, passing the current filters,
    /// excluding anyone already swiped this session.
    @Published var passedIds: Set<UUID> = []

    var discoverDeck: [Player] {
        players.filter { player in
            guard let prof = player.profile(activeSport) else { return false }
            guard !passedIds.contains(player.id) else { return false }
            return filters.matches(player: player, profile: prof)
        }
    }

    func pass(_ player: Player) { passedIds.insert(player.id) }

    func like(_ player: Player) {
        passedIds.insert(player.id)
        // Opening a conversation is how a "like" manifests here.
        if conversation(with: player.id) == nil {
            let convo = Conversation(partnerId: player.id, sport: activeSport, messages: [])
            conversations.insert(convo, at: 0)
            createRemoteConversationIfNeeded(localConversationID: convo.id)
        }
    }

    func resetDeck() { passedIds.removeAll() }

    // MARK: - Conversations

    func conversation(with playerId: UUID) -> Conversation? {
        conversations.first { $0.partnerId == playerId && $0.sport == activeSport }
    }

    // MARK: - Friend and request graph

    func friendshipState(with playerId: UUID) -> FriendshipState {
        if friendIds.contains(playerId) { return .friends }
        if incomingFriendRequestIds.contains(playerId) { return .incoming }
        if outgoingFriendRequestIds.contains(playerId) { return .outgoing }
        return .none
    }

    func sendFriendRequest(to playerId: UUID) {
        guard !friendIds.contains(playerId) else { return }
        outgoingFriendRequestIds.insert(playerId)
        guard let productionRepository, hydratedUserID != nil else { return }
        Task {
            do {
                try await productionRepository.sendConnectionRequest(to: playerId)
                await refreshCommunity()
            } catch {
                outgoingFriendRequestIds.remove(playerId)
                backendSyncError = error.localizedDescription
            }
        }
    }

    func acceptFriendRequest(from playerId: UUID) {
        incomingFriendRequestIds.remove(playerId)
        outgoingFriendRequestIds.remove(playerId)
        friendIds.insert(playerId)
        if let index = conversations.firstIndex(where: { $0.partnerId == playerId }) {
            conversations[index].isMessageRequest = false
        }
        respondToRemoteConnection(from: playerId, accept: true)
    }

    func declineFriendRequest(from playerId: UUID) {
        incomingFriendRequestIds.remove(playerId)
        respondToRemoteConnection(from: playerId, accept: false)
    }

    func acceptMessageRequest(_ conversationId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[index].isMessageRequest = false
        acceptFriendRequest(from: conversations[index].partnerId)
        if let productionRepository, let backendID = conversations[index].backendID, hydratedUserID != nil {
            Task {
                do { try await productionRepository.acceptConversation(id: backendID) }
                catch { backendSyncError = error.localizedDescription }
            }
        }
    }

    func deleteMessageRequest(_ conversationId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        let backendID = conversations[index].backendID
        incomingFriendRequestIds.remove(conversations[index].partnerId)
        conversations.remove(at: index)
        if let productionRepository, let backendID, hydratedUserID != nil {
            Task {
                do { try await productionRepository.leaveConversation(id: backendID) }
                catch { backendSyncError = error.localizedDescription }
            }
        }
    }

    func createGroupConversation(name: String, participantIds: [UUID]) -> Conversation? {
        let ids = Array(Set(participantIds))
        guard ids.count >= 2, let anchor = ids.first else { return nil }
        let conversation = Conversation(
            partnerId: anchor,
            sport: activeSport,
            messages: [ChatMessage(fromMe: true, kind: .system("Group created. Find a time that works for everyone."))],
            participantIds: ids,
            groupName: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Court crew" : name
        )
        conversations.insert(conversation, at: 0)
        createRemoteConversationIfNeeded(localConversationID: conversation.id)
        return conversation
    }

    func participantIds(for conversation: Conversation) -> [UUID] {
        conversation.participantIds.isEmpty ? [conversation.partnerId] : conversation.participantIds
    }

    func nextAlignedAvailability(with participantIds: [UUID], after now: Date = .now) -> AvailabilitySlot? {
        alignedAvailabilities(with: participantIds, after: now, limit: 1).first
    }

    func alignedAvailabilities(
        with participantIds: [UUID],
        after now: Date = .now,
        limit: Int = 4
    ) -> [AvailabilitySlot] {
        let calendars = [me.availability] + participantIds.compactMap { player($0)?.availability }
        guard calendars.count == participantIds.count + 1 else { return [] }

        let expanded = calendars.map { expandAvailability($0, after: now) }

        return Array(expanded[0]
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .filter { mine in
                expanded.dropFirst().allSatisfy { slots in
                    slots.contains {
                        Calendar.current.isDate($0.date, inSameDayAs: mine.date) &&
                        $0.period == mine.period
                    }
                }
            }
            .prefix(max(0, limit)))
    }

    private func expandAvailability(_ slots: [AvailabilitySlot], after now: Date,
                                    horizonDays: Int = 56) -> [AvailabilitySlot] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        return slots.flatMap { slot -> [AvailabilitySlot] in
            switch slot.rule {
            case .oneOff(let date):
                return [AvailabilitySlot(id: slot.id, date: date, period: slot.period)]
            case .weekly(let weekday):
                return (0..<horizonDays).compactMap { offset in
                    guard let date = calendar.date(byAdding: .day, value: offset, to: start),
                          calendar.component(.weekday, from: date) == weekday else { return nil }
                    return AvailabilitySlot(date: date, period: slot.period)
                }
            }
        }
    }

    func player(_ id: UUID) -> Player? { players.first { $0.id == id } }

    func send(_ kind: MessageKind, to playerId: UUID) {
        ensureConversation(with: playerId)
        guard let idx = conversationIndex(playerId) else { return }
        conversations[idx].messages.append(ChatMessage(fromMe: true, kind: kind))
        if productionRepository != nil, hydratedUserID != nil {
            let localID = conversations[idx].id
            Task { await sendRemote(kind, localConversationID: localID) }
            return
        }
        // Simulate a reply so the prototype feels alive.
        simulateReply(to: playerId, for: kind)
    }

    private func ensureConversation(with playerId: UUID) {
        if conversationIndex(playerId) == nil {
            conversations.insert(
                Conversation(
                    partnerId: playerId,
                    sport: activeSport,
                    messages: [],
                    isMessageRequest: !friendIds.contains(playerId)
                ),
                at: 0
            )
        }
    }

    private func conversationIndex(_ playerId: UUID) -> Int? {
        conversations.firstIndex { $0.partnerId == playerId && $0.sport == activeSport }
    }

    private func createRemoteConversationIfNeeded(localConversationID: UUID) {
        guard productionRepository != nil, hydratedUserID != nil else { return }
        Task { await ensureRemoteConversation(localConversationID: localConversationID) }
    }

    private func ensureRemoteConversation(localConversationID: UUID) async -> UUID? {
        guard let productionRepository,
              let index = conversations.firstIndex(where: { $0.id == localConversationID }) else { return nil }
        if let backendID = conversations[index].backendID { return backendID }
        let memberIDs = participantIds(for: conversations[index])
        do {
            let backendID = try await productionRepository.createConversation(
                sport: conversations[index].sport,
                memberIDs: memberIDs,
                title: conversations[index].groupName
            )
            if let current = conversations.firstIndex(where: { $0.id == localConversationID }) {
                conversations[current].backendID = backendID
            }
            return backendID
        } catch {
            backendSyncError = error.localizedDescription
            return nil
        }
    }

    private func sendRemote(_ kind: MessageKind, localConversationID: UUID) async {
        guard let productionRepository,
              let backendID = await ensureRemoteConversation(localConversationID: localConversationID) else { return }
        do {
            _ = try await productionRepository.sendMessage(kind, conversationID: backendID)
        } catch {
            backendSyncError = error.localizedDescription
        }
    }

    private func respondToRemoteConnection(from playerID: UUID, accept: Bool) {
        guard let productionRepository,
              hydratedUserID != nil,
              let connectionID = connectionIDsByPeer[playerID] else { return }
        Task {
            do {
                try await productionRepository.respondToConnection(id: connectionID, accept: accept)
                await refreshCommunity()
            } catch {
                backendSyncError = error.localizedDescription
            }
        }
    }

    private func simulateReply(to playerId: UUID, for kind: MessageKind) {
        guard let idx = conversationIndex(playerId) else { return }
        let reply: ChatMessage
        switch kind {
        case .challenge:
            reply = ChatMessage(fromMe: false, kind: .text("You're on! When and where? 🔥"))
        case .text:
            reply = ChatMessage(fromMe: false, kind: .text("Sounds good — down to hit soon?"))
        default:
            reply = ChatMessage(fromMe: false, kind: .text("👍"))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            self?.conversations[idx].messages.append(reply)
            self?.objectWillChange.send()
        }
    }

    func toggleBlock(_ playerId: UUID) {
        ensureConversation(with: playerId)
        guard let idx = conversationIndex(playerId) else { return }
        conversations[idx].isBlocked.toggle()
        guard let productionRepository, hydratedUserID != nil else { return }
        let blocked = conversations[idx].isBlocked
        let localConversationID = conversations[idx].id
        Task {
            do {
                try await productionRepository.setBlocked(blocked, playerID: playerId)
                await refreshCommunity()
            } catch {
                if let current = conversations.firstIndex(where: { $0.id == localConversationID }) {
                    conversations[current].isBlocked.toggle()
                }
                backendSyncError = error.localizedDescription
            }
        }
    }

    func proposeWager(_ value: String, in conversationId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[index].wagerProposal = WagerProposal(value: value, state: .proposedByMe)
        conversations[index].messages.append(
            ChatMessage(fromMe: true, kind: .system("You proposed a wager: \(value)"))
        )
    }

    func acceptWager(in conversationId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }),
              var proposal = conversations[index].wagerProposal else { return }
        proposal.state = .agreed
        conversations[index].wagerProposal = proposal
        conversations[index].messages.append(
            ChatMessage(fromMe: true, kind: .system("Wager agreed: \(proposal.value)"))
        )
    }

    func chooseNoWager(in conversationId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[index].wagerProposal = WagerProposal(value: "No wager", state: .noWager)
        conversations[index].messages.append(
            ChatMessage(fromMe: true, kind: .system("You chose to play without a wager."))
        )
    }

    func agreedWager(with participantIds: [UUID]) -> String {
        guard let first = participantIds.first,
              let conversation = conversations.first(where: { $0.partnerId == first }),
              let proposal = conversation.wagerProposal,
              proposal.state == .agreed else { return "No wager" }
        return proposal.value
    }

    // MARK: - Face-offs

    private func createRemoteChallengeIfNeeded(localFaceOffID: UUID, note: String) {
        guard let productionRepository, hydratedUserID != nil,
              let index = faceOffs.firstIndex(where: { $0.id == localFaceOffID }),
              faceOffs[index].backendChallengeID == nil else { return }
        let faceOff = faceOffs[index]
        let opponentIDs = faceOff.participantIds.isEmpty ? [faceOff.opponentId] : faceOff.participantIds
        let format = opponentIDs.count >= 3 ? "doubles" : "singles"
        let participants = opponentIDs.enumerated().map { offset, id in
            BackendChallengeParticipant(userID: id, team: offset == 0 && opponentIDs.count >= 3 ? 1 : 2)
        }
        Task {
            do {
                let backendID = try await productionRepository.createChallenge(BackendChallengeDraft(
                    sport: faceOff.sport,
                    format: format,
                    participants: participants,
                    proposedStarts: faceOff.proposedDates.isEmpty ? [faceOff.date] : faceOff.proposedDates,
                    duration: 3_600,
                    note: note,
                    venue: faceOff.venue,
                    conversationID: conversations.first(where: { $0.partnerId == faceOff.opponentId && $0.sport == faceOff.sport })?.backendID,
                    ratingExempt: faceOff.isRatingExempt
                ))
                if let current = faceOffs.firstIndex(where: { $0.id == localFaceOffID }) {
                    faceOffs[current].backendChallengeID = backendID
                }
            } catch {
                backendSyncError = error.localizedDescription
            }
        }
    }

    private func respondToRemoteChallenge(localFaceOffID: UUID, accept: Bool) {
        guard let productionRepository, hydratedUserID != nil,
              let index = faceOffs.firstIndex(where: { $0.id == localFaceOffID }),
              let backendID = faceOffs[index].backendChallengeID else { return }
        Task {
            do {
                let matchID = try await productionRepository.respondToChallenge(
                    id: backendID, accept: accept, selectedSlotID: nil
                )
                if let current = faceOffs.firstIndex(where: { $0.id == localFaceOffID }) {
                    faceOffs[current].backendMatchID = matchID
                }
            } catch {
                backendSyncError = error.localizedDescription
            }
        }
    }

    func isRatingExempt(opponentIds: [UUID], sport: Sport) -> Bool {
        guard sport.category == .individual,
              me.profile(sport)?.usesElo == true else { return false }
        return opponentIds.contains { player($0)?.profile(sport)?.usesElo != true }
    }

    func scheduleFaceOff(with player: Player, date: Date, venue: String, wager: String) {
        let fo = FaceOff(sport: activeSport,
                         opponentId: player.id,
                         opponentName: player.name,
                         date: date,
                         venue: venue,
                         wager: wager,
                         state: .confirmed,
                         isRatingExempt: isRatingExempt(opponentIds: [player.id], sport: activeSport))
        faceOffs.append(fo)
        send(.faceOff(fo), to: player.id)
    }

    func createChallenge(with player: Player, sport: Sport, date: Date, proposedDates: [Date] = [], venue: String,
                         note: String, isRatingExempt: Bool = false) {
        let options = proposedDates.isEmpty ? [date] : proposedDates
        let challenge = FaceOff(
            sport: sport,
            opponentId: player.id,
            opponentName: player.name,
            date: date,
            proposedDates: options,
            venue: venue,
            wager: "No wager",
            state: .proposed,
            isRatingExempt: isRatingExempt
        )
        faceOffs.append(challenge)
        createRemoteChallengeIfNeeded(localFaceOffID: challenge.id, note: note)
        send(.challenge(Challenge(wager: "No wager proposed", note: note)), to: player.id)
        let formattedOptions = options
            .map { $0.formatted(date: .abbreviated, time: .shortened) }
            .joined(separator: " · ")
        send(.system("Challenge proposed: \(sport.title) · \(formattedOptions) · \(venue)."), to: player.id)
    }

    @discardableResult
    func createUnscheduledMatch(sport: Sport, participantIds: [UUID], opponentIds: [UUID],
                                isRatingExempt: Bool) -> FaceOff? {
        guard let firstOpponentId = opponentIds.first,
              let firstOpponent = player(firstOpponentId) else { return nil }
        let names = opponentIds.compactMap { player($0)?.name.split(separator: " ").first.map(String.init) }
        let teammateIds = participantIds.filter { !opponentIds.contains($0) }
        let teammateNames = teammateIds.compactMap { player($0)?.name.split(separator: " ").first.map(String.init) }
        let myName = me.name.split(separator: " ").first.map(String.init) ?? "You"
        let mySide = ([myName] + teammateNames).joined(separator: " & ")
        let opponentSide = names.joined(separator: " & ")
        let faceOff = FaceOff(
            sport: sport,
            opponentId: firstOpponentId,
            opponentName: names.isEmpty ? firstOpponent.name : names.joined(separator: " & "),
            participantIds: participantIds,
            sideALabel: mySide,
            sideBLabel: opponentSide,
            date: .now,
            venue: "Unscheduled game",
            wager: "No wager",
            state: .confirmed,
            isRatingExempt: isRatingExempt,
            source: .unscheduled
        )
        faceOffs.append(faceOff)
        if let productionRepository, hydratedUserID != nil {
            let localID = faceOff.id
            let backendParticipants = teammateIds.map {
                BackendChallengeParticipant(userID: $0, team: 1)
            } + opponentIds.map {
                BackendChallengeParticipant(userID: $0, team: 2)
            }
            Task {
                do {
                    let matchID = try await productionRepository.createUploadedMatch(BackendUploadedMatchDraft(
                        sport: sport,
                        format: participantIds.count >= 3 ? "doubles" : "singles",
                        participants: backendParticipants,
                        startsAt: faceOff.date,
                        ratingExempt: isRatingExempt
                    ))
                    if let current = faceOffs.firstIndex(where: { $0.id == localID }) {
                        faceOffs[current].backendMatchID = matchID
                    }
                } catch {
                    backendSyncError = error.localizedDescription
                }
            }
        }
        return faceOff
    }

    func activeChallenges(with playerId: UUID) -> [FaceOff] {
        faceOffs
            .filter {
                $0.opponentId == playerId &&
                $0.sport == activeSport &&
                [.proposed, .confirmed, .awaitingResult].contains($0.state)
            }
            .sorted { $0.date < $1.date }
    }

    func acceptChallenge(_ faceOffId: UUID) {
        guard let index = faceOffs.firstIndex(where: { $0.id == faceOffId }) else { return }
        faceOffs[index].state = .confirmed
        respondToRemoteChallenge(localFaceOffID: faceOffId, accept: true)
        send(.faceOff(faceOffs[index]), to: faceOffs[index].opponentId)
        send(.system("Challenge accepted and added to both schedules."), to: faceOffs[index].opponentId)
    }

    func declineChallenge(_ faceOffId: UUID) {
        guard let index = faceOffs.firstIndex(where: { $0.id == faceOffId }) else { return }
        faceOffs[index].state = .cancelled
        respondToRemoteChallenge(localFaceOffID: faceOffId, accept: false)
        send(.system("Challenge declined."), to: faceOffs[index].opponentId)
    }

    func cancelChallenge(_ faceOffId: UUID) {
        guard let index = faceOffs.firstIndex(where: { $0.id == faceOffId }) else { return }
        faceOffs[index].state = .cancelled
        respondToRemoteChallenge(localFaceOffID: faceOffId, accept: false)
        send(.system("Challenge cancelled."), to: faceOffs[index].opponentId)
    }

    func updateChallenge(_ faceOffId: UUID, date: Date, venue: String) {
        guard let index = faceOffs.firstIndex(where: { $0.id == faceOffId }) else { return }
        faceOffs[index].date = date
        faceOffs[index].venue = venue
        faceOffs[index].revision += 1
        faceOffs[index].state = .proposed
        send(.system("Updated challenge sent for confirmation: \(date.formatted(date: .abbreviated, time: .shortened)) at \(venue)."), to: faceOffs[index].opponentId)
    }

    @discardableResult
    func scheduleAlignedFaceOff(
        participantIds: [UUID],
        date: Date,
        venue: String = "Zilker Courts",
        wager: String = "bragging rights 🏆"
    ) -> FaceOff? {
        guard let firstId = participantIds.first, let opponent = player(firstId) else { return nil }
        let faceOff = FaceOff(
            sport: activeSport,
            opponentId: firstId,
            opponentName: participantIds.count > 1 ? "\(participantIds.count)-player match" : opponent.name,
            date: date,
            venue: venue,
            wager: wager,
            state: .confirmed,
            isRatingExempt: isRatingExempt(opponentIds: participantIds, sport: activeSport)
        )
        faceOffs.append(faceOff)
        send(.faceOff(faceOff), to: firstId)
        return faceOff
    }

    func addGroupFixture(
        sport: Sport,
        title: String,
        team: String,
        opponent: String,
        date: Date,
        endDate: Date,
        venue: String
    ) {
        groupFixtures.append(
            GroupFixture(
                sport: sport,
                title: title,
                team: team,
                opponent: opponent,
                date: date,
                endDate: max(endDate, date.addingTimeInterval(3_600)),
                venue: venue
            )
        )
    }

    func removeGroupFixture(_ id: UUID) {
        groupFixtures.removeAll { $0.id == id }
    }

    func saveGroupFixtureResult(_ id: UUID, outcome: GroupResultOutcome, summary: String) {
        guard let index = groupFixtures.firstIndex(where: { $0.id == id }) else { return }
        groupFixtures[index].result = GroupFixtureResult(
            outcome: outcome,
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    var upcomingFaceOffs: [FaceOff] {
        faceOffs
            .filter {
                $0.sport == activeSport &&
                $0.state == .confirmed &&
                $0.date > Date().addingTimeInterval(-6 * 3600)
            }
            .sorted { $0.date < $1.date }
    }

    var scoreUpdatesNeeded: [FaceOff] {
        faceOffs
            .filter { $0.state == .confirmed && $0.date <= .now }
            .sorted { $0.date > $1.date }
    }

    /// The current user reports who won. Marks awaiting confirmation.
    func reportResult(faceOffId: UUID, outcome: MatchOutcome) {
        guard let i = faceOffs.firstIndex(where: { $0.id == faceOffId }) else { return }
        faceOffs[i].reportedWinnerByMe = outcome
        faceOffs[i].state = .awaitingResult
        if let productionRepository, hydratedUserID != nil {
            let myTeam = faceOffs[i].myTeam
            let winningTeam = outcome == .iWon ? myTeam : (myTeam == 1 ? 2 : 1)
            let serverScores = myTeam == 1 ? faceOffs[i].gameScores : faceOffs[i].gameScores.map {
                GameScore(id: $0.id, myScore: $0.opponentScore, opponentScore: $0.myScore)
            }
            Task {
                do {
                    var matchID = faceOffs.first(where: { $0.id == faceOffId })?.backendMatchID
                    for _ in 0..<30 where matchID == nil {
                        try await Task.sleep(for: .milliseconds(100))
                        matchID = faceOffs.first(where: { $0.id == faceOffId })?.backendMatchID
                    }
                    guard let matchID else {
                        backendSyncError = "The match is still being created. Please submit the score again."
                        return
                    }
                    try await productionRepository.reportMatchResult(
                        matchID: matchID,
                        winningTeam: winningTeam,
                        scores: serverScores
                    )
                    await refreshMatchbook()
                } catch {
                    backendSyncError = error.localizedDescription
                }
            }
        }
        send(.system("Scores submitted. Waiting for opponent verification before stats or Elo update."),
             to: faceOffs[i].opponentId)
        // A backend delivery creates the opponent's verification request. Statistics
        // remain unchanged until `opponentConfirms` is called from that response.
    }

    func submitScoreUpdate(faceOffId: UUID, scores: [GameScore]) {
        guard let index = faceOffs.firstIndex(where: { $0.id == faceOffId }), !scores.isEmpty else { return }
        faceOffs[index].gameScores = scores
        let myWins = scores.filter(\.iWon).count
        let theirWins = scores.count - myWins
        guard myWins != theirWins else { return }
        reportResult(faceOffId: faceOffId, outcome: myWins > theirWins ? .iWon : .theyWon)
    }

    /// Opponent confirms (or disputes) my report. Only matching reports settle the rating.
    func opponentConfirms(faceOffId: UUID, agrees: Bool) {
        guard let i = faceOffs.firstIndex(where: { $0.id == faceOffId }),
              let mine = faceOffs[i].reportedWinnerByMe else { return }
        let theirs: MatchOutcome = agrees ? mine.mirrored : mine
        faceOffs[i].reportedWinnerByThem = theirs

        if mine.agrees(with: theirs) {
            settleRating(faceOffIndex: i, iWon: mine == .iWon)
        } else {
            faceOffs[i].state = .resultDisputed
        }
        objectWillChange.send()
    }

    /// Handles a score report received from the opponent's account.
    func verifyIncomingResult(faceOffId: UUID, agrees: Bool) {
        guard let index = faceOffs.firstIndex(where: { $0.id == faceOffId }),
              let theirs = faceOffs[index].reportedWinnerByThem else { return }
        if agrees {
            let mine = theirs.mirrored
            faceOffs[index].reportedWinnerByMe = mine
            settleRating(faceOffIndex: index, iWon: mine == .iWon)
        } else {
            faceOffs[index].state = .resultDisputed
            send(.system("The submitted score was disputed. Both players need to review it."),
                 to: faceOffs[index].opponentId)
        }
    }

    private func settleRating(faceOffIndex i: Int, iWon: Bool) {
        let fo = faceOffs[i]
        guard let opponent = player(fo.opponentId),
              var myProf = me.profiles[fo.sport] else { return }
        let oppRating = opponent.rating(fo.sport)
        let before = myProf.rating
        let usesElo = myProf.usesElo && !fo.isRatingExempt
        var after = before

        let opponentSnapshot = opponent.profile(fo.sport)
        let updates = RatingEngine.individualMatch(
            playerA: CompetitiveRating(
                rating: Double(before),
                uncertainty: myProf.uncertainty,
                gamesPlayed: myProf.gamesPlayed,
                wins: myProf.wins,
                losses: myProf.losses,
                draws: myProf.draws
            ),
            playerB: CompetitiveRating(
                rating: Double(oppRating),
                uncertainty: opponentSnapshot?.uncertainty ?? RatingConfiguration.matchPoint.initialUncertainty,
                gamesPlayed: opponentSnapshot?.gamesPlayed ?? 0,
                wins: opponentSnapshot?.wins ?? 0,
                losses: opponentSnapshot?.losses ?? 0,
                draws: opponentSnapshot?.draws ?? 0
            ),
            resultForA: iWon ? .win : .loss
        )

        if usesElo {
            after = RatingEngine.publicRating(updates.playerA.after.rating)
            myProf.rating = after
            myProf.uncertainty = updates.playerA.after.uncertainty
            myProf.gamesPlayed = updates.playerA.after.gamesPlayed
            myProf.wins = updates.playerA.after.wins
            myProf.losses = updates.playerA.after.losses
            myProf.draws = updates.playerA.after.draws
            myProf.ratingHistory.append(RatingPoint(date: fo.date, rating: after))
        }
        me.profiles[fo.sport] = myProf

        if let playerIndex = players.firstIndex(where: { $0.id == fo.opponentId }),
           var opponentProfile = players[playerIndex].profiles[fo.sport],
           opponentProfile.usesElo,
           !fo.isRatingExempt {
            opponentProfile.rating = RatingEngine.publicRating(updates.playerB.after.rating)
            opponentProfile.uncertainty = updates.playerB.after.uncertainty
            opponentProfile.gamesPlayed = updates.playerB.after.gamesPlayed
            opponentProfile.wins = updates.playerB.after.wins
            opponentProfile.losses = updates.playerB.after.losses
            opponentProfile.draws = updates.playerB.after.draws
            opponentProfile.ratingHistory.append(RatingPoint(date: fo.date, rating: opponentProfile.rating))
            players[playerIndex].profiles[fo.sport] = opponentProfile
        }

        faceOffs[i].state = .completed
        faceOffs[i].ratingDelta = after - before

        matchHistory.insert(
            MatchRecord(sport: fo.sport,
                        opponentName: opponent.name,
                        opponentAvatar: opponent.avatar,
                        opponentRatingAtTime: oppRating,
                        didWin: iWon,
                        ratingBefore: before,
                        ratingAfter: after,
                        date: fo.date,
                        venue: fo.venue,
                        wager: fo.wager,
                        gameScores: fo.gameScores,
                        opponentId: fo.opponentId,
                        isRatingExempt: fo.isRatingExempt,
                        source: fo.source),
            at: 0)
    }

    @discardableResult
    func completeLiveMatch(faceOffId: UUID, scores: [GameScore]) -> LiveMatchSummary? {
        guard !scores.isEmpty,
              let index = faceOffs.firstIndex(where: { $0.id == faceOffId }),
              let opponent = player(faceOffs[index].opponentId) else { return nil }

        let myGames = scores.filter(\.iWon).count
        let opponentGames = scores.count - myGames
        guard myGames != opponentGames else { return nil }

        let before = currentRating
        faceOffs[index].gameScores = scores
        faceOffs[index].reportedWinnerByMe = myGames > opponentGames ? .iWon : .theyWon
        faceOffs[index].state = .awaitingResult
        let opponentRating = opponent.rating(faceOffs[index].sport)
        let after: Int
        if let profile = myProfile, profile.usesElo, !faceOffs[index].isRatingExempt {
            let expected = RatingEngine.expectedScore(
                ratingA: Double(before),
                ratingB: Double(opponentRating)
            )
            let update = RatingEngine.update(
                player: CompetitiveRating(
                    rating: Double(before),
                    uncertainty: profile.uncertainty,
                    gamesPlayed: profile.gamesPlayed,
                    wins: profile.wins,
                    losses: profile.losses,
                    draws: profile.draws
                ),
                expectedScore: expected,
                result: myGames > opponentGames ? .win : .loss
            )
            after = RatingEngine.publicRating(update.after.rating)
        } else {
            after = before
        }
        return LiveMatchSummary(
            didWin: myGames > opponentGames,
            opponentName: opponent.name,
            opponentAvatar: opponent.avatar,
            myGames: myGames,
            opponentGames: opponentGames,
            ratingBefore: before,
            ratingAfter: after,
            wager: faceOffs[index].wager
        )
    }

    // MARK: - Stats (active sport)

    var myMatches: [MatchRecord] {
        matchHistory.filter { $0.sport == activeSport && !$0.isRatingExempt }.sorted { $0.date > $1.date }
    }
    var wins: Int { myMatches.filter(\.didWin).count }
    var losses: Int { myMatches.filter { !$0.didWin }.count }
    var winPct: Double {
        let total = myMatches.count
        return total == 0 ? 0 : Double(wins) / Double(total) * 100
    }
    var ratingHistory: [RatingPoint] {
        (me.profiles[activeSport]?.ratingHistory ?? []).sorted { $0.date < $1.date }
    }
    var peakRating: RatingPoint? { ratingHistory.max { $0.rating < $1.rating } }
    var lowRating: RatingPoint? { ratingHistory.min { $0.rating < $1.rating } }
    var currentRating: Int { me.profiles[activeSport]?.rating ?? EloRating.start }

    func headToHead(with player: Player, sport: Sport? = nil) -> [MatchRecord] {
        matchHistory.filter { record in
            (record.opponentId == player.id || record.opponentName == player.name) &&
            (sport == nil || record.sport == sport)
        }
        .sorted { $0.date > $1.date }
    }

    func submitPeerRatings(
        playerId: UUID,
        sport: Sport,
        values: [String: Int],
        writtenReview: String = ""
    ) {
        guard sport.category == .group,
              let playerIndex = players.firstIndex(where: { $0.id == playerId }),
              var profile = players[playerIndex].profiles[sport] else { return }

        for (category, value) in values {
            if let ratingIndex = profile.peerSkillRatings.firstIndex(where: { $0.category == category }) {
                let existing = profile.peerSkillRatings[ratingIndex]
                let newCount = existing.count + 1
                let newAverage = ((existing.average * Double(existing.count)) + Double(value)) / Double(newCount)
                profile.peerSkillRatings[ratingIndex].average = newAverage
                profile.peerSkillRatings[ratingIndex].count = newCount
            } else {
                profile.peerSkillRatings.append(PeerSkillRating(category: category, average: Double(value), count: 1))
            }
        }
        let review = writtenReview.trimmingCharacters(in: .whitespacesAndNewlines)
        if !review.isEmpty {
            profile.peerWrittenReviews.insert(
                PeerWrittenReview(reviewerName: me.name, text: String(review.prefix(500))),
                at: 0
            )
        }
        players[playerIndex].profiles[sport] = profile
    }
}

enum FriendshipState {
    case none, outgoing, incoming, friends
}

private extension Array where Element == PeerSkillRating {
    static func demo(for sport: Sport) -> [PeerSkillRating] {
        sport.skillCategories.enumerated().map { index, category in
            PeerSkillRating(category: category, average: 4.4 + Double(index) * 0.2, count: 8 + index * 4)
        }
    }
}

private extension MatchOutcome {
    var mirrored: MatchOutcome { self == .iWon ? .theyWon : .iWon }
    /// Two reports agree if exactly one player is named the winner.
    func agrees(with other: MatchOutcome) -> Bool { self.mirrored == other }
}

// MARK: - Filters

struct DiscoverFilters {
    var maxDistance: Double = 25          // miles
    var ratingRange: ClosedRange<Double> = 0...200
    var partnerStatuses: Set<PartnerStatus> = Set(PartnerStatus.allCases)
    var requireEquipment = false
    var tournamentsOnly = false

    var isActive: Bool {
        maxDistance < 25 || ratingRange != 0...200 ||
        partnerStatuses.count != PartnerStatus.allCases.count ||
        requireEquipment || tournamentsOnly
    }

    func matches(player: Player, profile: SportProfile) -> Bool {
        guard player.distanceMiles <= maxDistance else { return false }
        if profile.usesElo {
            guard ratingRange.contains(Double(profile.rating)) else { return false }
        }
        guard partnerStatuses.contains(profile.partnerStatus) else { return false }
        if requireEquipment && !profile.ownsEquipment { return false }
        if tournamentsOnly && !profile.playedTournaments { return false }
        return true
    }

    mutating func reset() { self = DiscoverFilters() }
}
