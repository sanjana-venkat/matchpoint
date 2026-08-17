import SwiftUI
import Combine

/// Single source of truth for the whole prototype. All data is in-memory mock
/// data — no backend. Swapping `activeSport` re-skins and re-filters the app.
@MainActor
final class AppState: ObservableObject {
    private let availabilityStorageKey = "picklematch.profile.availability.v1"

    // MARK: Onboarding / me
    @Published var hasCompletedOnboarding = false
    @Published var me = MockData.emptyMe()
    /// Sports the user opted into during onboarding.
    @Published var mySports: [Sport] = []
    /// Which sport "mode" the app is currently showing.
    @Published var activeSport: Sport = .pickleball {
        didSet { objectWillChange.send() }
    }

    // MARK: Community
    @Published var players: [Player] = []
    @Published var conversations: [Conversation] = []
    @Published var faceOffs: [FaceOff] = []
    @Published var matchHistory: [MatchRecord] = []
    @Published var friendIds: Set<UUID> = []
    @Published var incomingFriendRequestIds: Set<UUID> = []
    @Published var outgoingFriendRequestIds: Set<UUID> = []
    @Published var friendCountOverride: Int = 0
    @Published var hasUnsavedDraft = false

    // MARK: Discover filters (per session)
    @Published var filters = DiscoverFilters()

    init() {
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
        }
#endif
    }

    var myProfile: SportProfile? { me.profiles[activeSport] }
    var themeColor: Color { Theme.color(for: activeSport) }
    var hasMultipleSports: Bool { mySports.count > 1 }
    var displayedFriendCount: Int { max(friendIds.count, friendCountOverride) }

    // MARK: - Prototype states

    func loadNewUserPrototype() {
        me = MockData.emptyMe()
        mySports = []
        activeSport = .pickleball
        conversations = []
        faceOffs = []
        matchHistory = []
        friendIds = []
        incomingFriendRequestIds = []
        outgoingFriendRequestIds = []
        friendCountOverride = 0
        hasCompletedOnboarding = false
    }

    func loadEstablishedPrototype() {
        players = MockData.players()
        conversations = MockData.conversations(players: players)
        faceOffs = MockData.faceOffs(players: players)
        matchHistory = MockData.matchHistory()

        var veteran = MockData.emptyMe()
        veteran.name = "Alex Morgan"
        veteran.username = "alexplaysall"
        veteran.gender = .nonBinary
        veteran.age = 32
        veteran.avatar = Avatar.all[6]
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
        friendIds = Set(players.map(\.id))
        friendCountOverride = 42
        incomingFriendRequestIds = []
        outgoingFriendRequestIds = []

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
        for index in conversations.indices { conversations[index].isMessageRequest = false }

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
    }

    func updateMyAvailability(_ slots: [AvailabilitySlot]) {
        me.availability = slots.sorted { $0.startDate < $1.startDate }
        persistAvailability()
    }

    private func persistAvailability() {
        guard let data = try? JSONEncoder().encode(me.availability) else { return }
        UserDefaults.standard.set(data, forKey: availabilityStorageKey)
    }

    /// Add a second (or later) sport after initial onboarding.
    func addSport(_ sport: Sport, profile: SportProfile) {
        guard !mySports.contains(sport), mySports.count < 4 else { return }
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
    }

    func acceptFriendRequest(from playerId: UUID) {
        incomingFriendRequestIds.remove(playerId)
        outgoingFriendRequestIds.remove(playerId)
        friendIds.insert(playerId)
        if let index = conversations.firstIndex(where: { $0.partnerId == playerId }) {
            conversations[index].isMessageRequest = false
        }
    }

    func declineFriendRequest(from playerId: UUID) {
        incomingFriendRequestIds.remove(playerId)
    }

    func acceptMessageRequest(_ conversationId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[index].isMessageRequest = false
        acceptFriendRequest(from: conversations[index].partnerId)
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
        guard let idx = conversationIndex(playerId) else { return }
        conversations[idx].isBlocked.toggle()
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

    func createChallenge(with player: Player, sport: Sport, date: Date, venue: String,
                         note: String, isRatingExempt: Bool = false) {
        let challenge = FaceOff(
            sport: sport,
            opponentId: player.id,
            opponentName: player.name,
            date: date,
            venue: venue,
            wager: "No wager",
            state: .proposed,
            isRatingExempt: isRatingExempt
        )
        faceOffs.append(challenge)
        send(.challenge(Challenge(wager: "No wager proposed", note: note)), to: player.id)
        send(.system("Challenge proposed: \(sport.title) · \(date.formatted(date: .abbreviated, time: .shortened)) · \(venue)."), to: player.id)
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
        send(.faceOff(faceOffs[index]), to: faceOffs[index].opponentId)
        send(.system("Challenge accepted and added to both schedules."), to: faceOffs[index].opponentId)
    }

    func declineChallenge(_ faceOffId: UUID) {
        guard let index = faceOffs.firstIndex(where: { $0.id == faceOffId }) else { return }
        faceOffs[index].state = .cancelled
        send(.system("Challenge declined."), to: faceOffs[index].opponentId)
    }

    func cancelChallenge(_ faceOffId: UUID) {
        guard let index = faceOffs.firstIndex(where: { $0.id == faceOffId }) else { return }
        faceOffs[index].state = .cancelled
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
        let after = usesElo ? EloRating.newRating(player: before, opponent: oppRating, didWin: iWon) : before

        if usesElo {
            myProf.rating = after
            myProf.ratingHistory.append(RatingPoint(date: fo.date, rating: after))
        }
        me.profiles[fo.sport] = myProf

        if let playerIndex = players.firstIndex(where: { $0.id == fo.opponentId }),
           var opponentProfile = players[playerIndex].profiles[fo.sport],
           opponentProfile.usesElo,
           !fo.isRatingExempt {
            opponentProfile.rating = EloRating.newRating(
                player: opponentProfile.rating,
                opponent: before,
                didWin: !iWon
            )
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
        let after = myProfile?.usesElo == true && !faceOffs[index].isRatingExempt
            ? EloRating.newRating(player: before, opponent: opponentRating, didWin: myGames > opponentGames)
            : before
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

    func submitPeerRatings(playerId: UUID, sport: Sport, values: [String: Int]) {
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
