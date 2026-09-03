import Foundation

// MARK: - Sport

enum Sport: String, CaseIterable, Identifiable, Codable {
    case pickleball
    case badminton
    case tennis
    case pingPong
    case squash
    case volleyball
    case cricket
    case soccer
    case baseball
    case football

    var id: String { rawValue }

    /// The six sports currently supported by Rally's production UI and asset set.
    /// Legacy enum cases remain decodable for older local data but are not selectable.
    static let supported: [Sport] = [
        .pickleball, .badminton, .pingPong,
        .volleyball, .cricket, .soccer
    ]

    /// Sports enabled for the first public beta. The remaining supported sports
    /// stay visible in selection screens as a roadmap, but cannot be activated.
    static let betaAvailable: [Sport] = [.pickleball, .badminton]
    var isAvailableInBeta: Bool { Self.betaAvailable.contains(self) }
    var title: String {
        switch self {
        case .pingPong: return "Ping Pong"
        default: return rawValue.capitalized
        }
    }
    var sfSymbol: String {
        switch self {
        case .pickleball: return "figure.pickleball"
        case .badminton: return "figure.badminton"
        case .tennis: return "figure.tennis"
        case .pingPong: return "figure.table.tennis"
        case .squash: return "figure.racquetball"
        case .volleyball: return "figure.volleyball"
        case .cricket: return "figure.cricket"
        case .soccer: return "figure.soccer"
        case .baseball: return "figure.baseball"
        case .football: return "figure.american.football"
        }
    }

    /// Premium dimensional equipment artwork supplied for content-level sport illustration.
    var illustrationIconAsset: String? {
        switch self {
        case .pickleball: "icon.pickleball"
        case .badminton: "icon.badminton"
        case .pingPong: "icon.tabletennis"
        case .cricket: "icon.cricket"
        case .soccer: "icon.soccer"
        case .volleyball: "icon.volleyball"
        default: nil
        }
    }

    var heroIllustrationAsset: String? {
        switch self {
        case .pickleball: "hero-pickleball"
        case .badminton: "hero-badminton"
        case .pingPong: "hero-pingpong"
        case .cricket: "hero-cricket"
        case .soccer: "hero-soccer"
        case .volleyball: "hero-volleyball"
        default: nil
        }
    }

    var category: SportCategory {
        switch self {
        case .pickleball, .badminton, .tennis, .pingPong, .squash: return .individual
        case .volleyball, .cricket, .soccer, .baseball, .football: return .group
        }
    }

    var skillCategories: [String] {
        switch self {
        case .volleyball: return ["Serving", "Setting", "Defense"]
        case .cricket: return ["Batting", "Bowling", "Fielding"]
        case .soccer: return ["Passing", "Finishing", "Defense"]
        case .baseball: return ["Hitting", "Fielding", "Throwing"]
        case .football: return ["Offense", "Defense", "Game IQ"]
        default: return []
        }
    }
}

enum SportCategory: String, CaseIterable, Identifiable, Codable {
    case individual = "Individual or dual sports"
    case group = "Group sports"
    var id: String { rawValue }
}

// MARK: - Basic profile enums

enum Gender: String, CaseIterable, Identifiable, Codable {
    case male = "Male"
    case female = "Female"
    case nonBinary = "Non-binary"
    var id: String { rawValue }
}

/// Whether a player currently has a doubles partner situation.
enum PartnerStatus: String, CaseIterable, Identifiable, Codable {
    case hasPartner   = "Has a partner"
    case solo         = "Plays solo"
    case lookingForPartner = "Looking for a partner"

    var id: String { rawValue }
    var short: String {
        switch self {
        case .hasPartner: return "Partnered"
        case .solo: return "Solo"
        case .lookingForPartner: return "Seeking partner"
        }
    }
    var systemImage: String {
        switch self {
        case .hasPartner: return "person.2.fill"
        case .solo: return "person.fill"
        case .lookingForPartner: return "person.badge.plus"
        }
    }
}

enum SelfAssessment: String, CaseIterable, Identifiable, Codable {
    case newbie      = "Just starting out"
    case casual      = "Casual / social"
    case competitive = "Competitive"
    case tournament  = "Tournament regular"
    var id: String { rawValue }
}

enum SocialSkillLabel: String, CaseIterable, Identifiable, Codable {
    case casual = "Casual play"
    case amateur = "Amateur"
    case social = "Social play"
    var id: String { rawValue }
}

struct PeerSkillRating: Identifiable, Codable, Hashable {
    var id: String { category }
    var category: String
    var average: Double
    var count: Int
}

struct PeerWrittenReview: Identifiable, Codable, Hashable {
    var id = UUID()
    var reviewerName: String
    var text: String
    var createdAt: Date = .now
}

// MARK: - Avatars

/// Selectable premium Rally portraits, with a symbol fallback.
struct Avatar: Identifiable, Hashable, Codable {
    let id: String
    let imageName: String?
    let symbol: String
    let colorHex: String

    private static let illustrated: [Avatar] = (1...47).map { index in
        let identifier = String(format: "%02d", index)
        return Avatar(
            id: "rally-\(identifier)",
            imageName: "avatar.\(identifier)",
            symbol: "person.fill",
            colorHex: "F7F4EC"
        )
    }

    private static let symbolChoices: [(String, String, String)] = [
        ("explorer", "person.crop.circle.fill", "7C5CFC"), ("runner", "figure.run", "E96B4C"),
        ("cyclist", "figure.outdoor.cycle", "22A699"), ("skater", "figure.skating", "E4B363"),
        ("smile", "face.smiling.inverse", "D36B9A"), ("spark", "sparkles", "7DD3FC"),
        ("robot", "cpu.fill", "A8B0C3"), ("ghost", "theatermasks.fill", "B8A1FF"),
        ("cat", "cat.fill", "E49B5D"), ("dog", "dog.fill", "6FB1A0"),
        ("hare", "hare.fill", "C9A6FF"), ("tortoise", "tortoise.fill", "8DB580"),
        ("bird", "bird.fill", "5AB2FF"), ("fish", "fish.fill", "3B82F6"),
        ("ladybug", "ladybug.fill", "F45B69"), ("ant", "ant.fill", "A17C6B"),
        ("paw", "pawprint.fill", "F2B880"), ("leaf", "leaf.fill", "55C271"),
        ("flame", "flame.fill", "FF6B35"), ("drop", "drop.fill", "38BDF8"),
        ("sun", "sun.max.fill", "F7C948"), ("moon", "moon.stars.fill", "7879F1"),
        ("cloud", "cloud.fill", "9CB3C9"), ("mountain", "mountain.2.fill", "5F8D73"),
        ("globe", "globe.americas.fill", "1BA39C"), ("bolt", "bolt.fill", "FBD34D"),
        ("heart", "heart.fill", "FF5D8F"), ("star", "star.fill", "FFCB4C"),
        ("crown", "crown.fill", "D9A441"), ("diamond", "diamond.fill", "79D2E6"),
        ("hexagon", "hexagon.fill", "785EF0"), ("grid", "circle.hexagongrid.fill", "EF476F"),
        ("spiral", "hurricane", "8E7DBE"), ("wave", "water.waves", "2D9CDB"),
        ("target", "scope", "EF8354"), ("flag", "flag.checkered", "E8E8E8"),
        ("trophy", "trophy.fill", "F4C95D"), ("medal", "medal.fill", "E0A458"),
        ("pickleball", "figure.pickleball", "C7F000"), ("badminton", "figure.badminton", "FF876D"),
        ("cricket", "figure.cricket", "69D2E7"), ("soccer", "soccerball", "EAEAEA"),
        ("rocket", "rocket.fill", "FE6D73"), ("game", "gamecontroller.fill", "6C63FF")
    ]

    static let all: [Avatar] = illustrated + symbolChoices.map {
        Avatar(id: $0.0, imageName: nil, symbol: $0.1, colorHex: $0.2)
    }

    static let fallback = all[0]

    static let illustratedChoices = illustrated

    var portraitAssetName: String? {
        imageName
    }
}

// MARK: - Per-sport profile

/// A player's profile *within a single sport*. A player who plays both
/// sports has two of these, each with its own rating and answers.
struct SportProfile: Identifiable, Codable {
    var id: String { sport.rawValue }
    var sport: Sport
    var rating: Int = 80
    /// Hidden confidence and record fields mirror the exact server-side rating state.
    /// The app displays the rounded integer rating; Supabase retains decimal precision.
    var uncertainty: Double = RatingConfiguration.matchPoint.initialUncertainty
    var gamesPlayed: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var draws: Int = 0
    var ratingOptOut: Bool = false
    var socialSkillLabel: SocialSkillLabel? = nil
    var peerSkillRatings: [PeerSkillRating] = []
    var peerWrittenReviews: [PeerWrittenReview] = []
    var partnerStatus: PartnerStatus = .solo
    var homeCourt: String = ""
    var ownsEquipment: Bool = true
    var playedTournaments: Bool = false
    var selfAssessment: SelfAssessment = .casual
    /// Historical rating samples for the analytics chart.
    var ratingHistory: [RatingPoint] = []

    var usesElo: Bool { sport.category == .individual && !ratingOptOut }
    var isProvisional: Bool { RatingEngine.isProvisional(gamesPlayed: gamesPlayed) }
}

struct RatingPoint: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var rating: Int
}

// MARK: - Player

struct Player: Identifiable, Codable {
    var id = UUID()
    var name: String
    var username: String = ""
    var gender: Gender
    var age: Int
    var avatar: Avatar
    var city: String
    var distanceMiles: Double
    var bio: String
    /// Keyed by sport so the discover feed can switch instantly with the mode toggle.
    var profiles: [Sport: SportProfile]
    /// Concrete availability windows selected once during onboarding and editable later.
    var availability: [AvailabilitySlot] = []
    /// Privacy-preserving map position returned by the nearby RPC (roughly
    /// neighborhood-level, never the stored exact coordinate).
    var approximateLatitude: Double? = nil
    var approximateLongitude: Double? = nil

    func profile(_ sport: Sport) -> SportProfile? { profiles[sport] }
    func rating(_ sport: Sport) -> Int { profiles[sport]?.rating ?? EloRating.start }
}

// MARK: - Availability

enum AvailabilityPeriod: String, CaseIterable, Identifiable, Codable {
    case earlyMorning = "Early morning"
    case morning = "Morning"
    case midday = "Midday"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"

    var id: String { rawValue }
    var hours: String {
        switch self {
        case .earlyMorning: return "6–8 AM"
        case .morning: return "9–11 AM"
        case .midday: return "11 AM–2 PM"
        case .afternoon: return "3–5 PM"
        case .evening: return "6–8 PM"
        case .night: return "8–10 PM"
        }
    }
    var startHour: Int {
        switch self {
        case .earlyMorning: return 6
        case .morning: return 9
        case .midday: return 11
        case .afternoon: return 15
        case .evening: return 18
        case .night: return 20
        }
    }
    var endHour: Int {
        switch self {
        case .earlyMorning: return 8
        case .morning: return 11
        case .midday: return 14
        case .afternoon: return 17
        case .evening: return 20
        case .night: return 22
        }
    }
}

enum AvailabilityRule: Codable, Hashable {
    case oneOff(Date)
    /// Calendar weekday where 1 = Sunday and 7 = Saturday.
    case weekly(Int)
}

struct AvailabilitySlot: Identifiable, Codable, Hashable {
    var id = UUID()
    var rule: AvailabilityRule
    var period: AvailabilityPeriod

    init(id: UUID = UUID(), date: Date, period: AvailabilityPeriod) {
        self.id = id
        self.rule = .oneOff(Calendar.current.startOfDay(for: date))
        self.period = period
    }

    init(id: UUID = UUID(), weekday: Int, period: AvailabilityPeriod) {
        self.id = id
        self.rule = .weekly(min(7, max(1, weekday)))
        self.period = period
    }

    var isWeekly: Bool {
        if case .weekly = rule { return true }
        return false
    }

    var weekday: Int? {
        if case .weekly(let weekday) = rule { return weekday }
        return nil
    }

    /// Concrete next occurrence used by compact pills. Matching expands weekly
    /// rules over its requested horizon before comparing calendars.
    var date: Date {
        switch rule {
        case .oneOff(let date): return date
        case .weekly(let weekday):
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
                .first { calendar.component(.weekday, from: $0) == weekday } ?? today
        }
    }

    var startDate: Date {
        Calendar.current.date(bySettingHour: period.startHour, minute: 0, second: 0, of: date) ?? date
    }
    var endDate: Date {
        Calendar.current.date(bySettingHour: period.endHour, minute: 0, second: 0, of: date) ?? date
    }
}

// MARK: - Messaging

enum MessageKind: Codable, Equatable {
    case text(String)
    case image                 // placeholder attachment
    case location(String)
    case challenge(Challenge)
    case faceOff(FaceOff)
    case system(String)
}

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    var fromMe: Bool
    var kind: MessageKind
    var date: Date = Date()
}

struct Conversation: Identifiable, Codable {
    var id = UUID()
    /// Stable server identifier. The local `id` remains stable while an optimistic
    /// conversation is being created so navigation does not break mid-transition.
    var backendID: UUID? = nil
    var partnerId: UUID
    var sport: Sport
    var messages: [ChatMessage]
    var isBlocked: Bool = false
    /// Includes the direct partner for one-to-one chats and every member for groups.
    var participantIds: [UUID] = []
    var groupName: String? = nil
    var wagerProposal: WagerProposal? = nil
    /// Non-friends land in the requests folder until accepted.
    var isMessageRequest: Bool = false

    var lastMessage: ChatMessage? { messages.last }
    var isGroup: Bool { !participantIds.isEmpty && participantIds.count > 1 }
}

// MARK: - Challenge, wager & face-off

struct Challenge: Codable, Equatable {
    var id = UUID()
    var wager: String          // free-form: "a beer", "loser buys tacos", etc.
    var note: String
}

/// Suggested wager hints — the app nudges but never restricts.
enum WagerHint {
    static let all = ["a cold beer 🍺", "a meal 🌮", "$10 cash 💵", "a pickleball 🟡",
                      "coffee ☕️", "bragging rights 🏆", "loser buys the court time"]
}

enum WagerProposalState: String, Codable {
    case proposedByMe
    case proposedByThem
    case agreed
    case noWager
}

struct WagerProposal: Codable, Equatable {
    var value: String
    var state: WagerProposalState
}

enum FaceOffState: String, Codable {
    case proposed     // one side suggested time/date/venue
    case confirmed    // both agreed — it's on the calendar
    case awaitingResult
    case resultDisputed
    case completed
    case cancelled
}

struct FaceOff: Identifiable, Codable, Equatable {
    var id = UUID()
    var backendChallengeID: UUID? = nil
    var backendMatchID: UUID? = nil
    var sport: Sport
    var opponentId: UUID
    var opponentName: String
    var participantIds: [UUID] = []
    /// The server-side team assignment for this signed-in player.
    var myTeam: Int = 1
    var sideALabel: String? = nil
    var sideBLabel: String? = nil
    var date: Date
    /// Candidate times supplied with a challenge. The first becomes `date`
    /// when the challenge is created and remains the calendar fallback.
    var proposedDates: [Date] = []
    var venue: String
    var wager: String
    var state: FaceOffState = .proposed
    /// Distinguishes an outgoing proposal from one that needs this user's response.
    var proposedByMe: Bool = true
    /// Result each side reported. nil until they submit.
    var reportedWinnerByMe: MatchOutcome? = nil
    var reportedWinnerByThem: MatchOutcome? = nil
    var ratingDelta: Int? = nil        // filled in once verified
    var gameScores: [GameScore] = []
    var revision: Int = 1
    /// True when either side has no active Elo profile for this sport.
    var isRatingExempt: Bool = false
    var source: MatchSource = .scheduled
}

enum GroupResultOutcome: String, Codable, CaseIterable {
    case won = "Won"
    case lost = "Lost"
    case drawn = "Drawn"
}

struct GroupFixtureResult: Codable, Equatable {
    var outcome: GroupResultOutcome
    var summary: String
}

struct GroupFixture: Identifiable, Codable, Equatable {
    var id = UUID()
    var sport: Sport
    var title: String
    var team: String
    var opponent: String
    var date: Date
    var endDate: Date
    var venue: String
    var result: GroupFixtureResult? = nil
}

enum MatchOutcome: String, Codable, CaseIterable {
    case iWon = "I won"
    case theyWon = "They won"
}

struct GameScore: Identifiable, Codable, Equatable {
    var id = UUID()
    var myScore: Int
    var opponentScore: Int

    var iWon: Bool { myScore > opponentScore }
}

struct LiveMatchSummary: Identifiable {
    var id = UUID()
    var didWin: Bool
    var opponentName: String
    var opponentAvatar: Avatar
    var myGames: Int
    var opponentGames: Int
    var ratingBefore: Int
    var ratingAfter: Int
    var wager: String

    var ratingDelta: Int { ratingAfter - ratingBefore }
}

// MARK: - Completed match record (for stats)

enum MatchSource: String, Codable { case scheduled, unscheduled }

struct MatchRecord: Identifiable, Codable {
    var id = UUID()
    var sport: Sport
    var opponentName: String
    var opponentAvatar: Avatar
    var opponentRatingAtTime: Int
    var didWin: Bool
    var ratingBefore: Int
    var ratingAfter: Int
    var date: Date
    var venue: String
    var wager: String
    var gameScores: [GameScore] = []
    var opponentId: UUID? = nil
    var isRatingExempt: Bool = false
    var source: MatchSource = .scheduled

    var ratingDelta: Int { ratingAfter - ratingBefore }
}
