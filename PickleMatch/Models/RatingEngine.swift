import Foundation

/// Tunable constants for Match Point's uncertainty-aware, sport-specific rating system.
/// The engine is deterministic: variation comes from matchup probability and confidence,
/// never random noise.
struct RatingConfiguration: Equatable, Sendable {
    var startingRating = 80.0
    var initialUncertainty = 12.0
    var minimumUncertainty = 3.0
    var scale = 10.0
    var minimumK = 2.0
    var maximumK = 12.0
    var uncertaintyDecay = 0.96
    var provisionalGames = 10
    var reviewPriorRating = 4.0
    var reviewPriorCount = 5.0

    static let matchPoint = RatingConfiguration()
}

enum CompetitiveResult: Double, Sendable {
    case loss = 0
    case draw = 0.5
    case win = 1

    var inverse: CompetitiveResult {
        switch self {
        case .loss: .win
        case .draw: .draw
        case .win: .loss
        }
    }
}

struct CompetitiveRating: Equatable, Sendable {
    var rating: Double
    var uncertainty: Double
    var gamesPlayed: Int
    var wins: Int
    var losses: Int
    var draws: Int

    init(
        rating: Double = RatingConfiguration.matchPoint.startingRating,
        uncertainty: Double = RatingConfiguration.matchPoint.initialUncertainty,
        gamesPlayed: Int = 0,
        wins: Int = 0,
        losses: Int = 0,
        draws: Int = 0
    ) {
        self.rating = rating
        self.uncertainty = uncertainty
        self.gamesPlayed = gamesPlayed
        self.wins = wins
        self.losses = losses
        self.draws = draws
    }
}

struct RatingUpdate: Equatable, Sendable {
    let before: CompetitiveRating
    let after: CompetitiveRating
    let expectedScore: Double
    let actualScore: Double

    var delta: Double { after.rating - before.rating }
}

struct IndividualRatingUpdates: Equatable, Sendable {
    let playerA: RatingUpdate
    let playerB: RatingUpdate
}

struct TeamRatingUpdates: Equatable, Sendable {
    let teamAExpectedScore: Double
    let teamA: [RatingUpdate]
    let teamB: [RatingUpdate]
}

enum RatingEngine {
    static func expectedScore(
        ratingA: Double,
        ratingB: Double,
        configuration: RatingConfiguration = .matchPoint
    ) -> Double {
        1 / (1 + exp(-(ratingA - ratingB) / configuration.scale))
    }

    static func kFactor(
        uncertainty: Double,
        configuration: RatingConfiguration = .matchPoint
    ) -> Double {
        let range = configuration.initialUncertainty - configuration.minimumUncertainty
        guard range > 0 else { return configuration.minimumK }
        let normalized = min(1, max(0, (uncertainty - configuration.minimumUncertainty) / range))
        return configuration.minimumK + normalized * (configuration.maximumK - configuration.minimumK)
    }

    static func newUncertainty(
        _ oldUncertainty: Double,
        configuration: RatingConfiguration = .matchPoint
    ) -> Double {
        max(configuration.minimumUncertainty, oldUncertainty * configuration.uncertaintyDecay)
    }

    static func update(
        player: CompetitiveRating,
        expectedScore: Double,
        result: CompetitiveResult,
        configuration: RatingConfiguration = .matchPoint
    ) -> RatingUpdate {
        let actual = result.rawValue
        let delta = kFactor(uncertainty: player.uncertainty, configuration: configuration)
            * (actual - expectedScore)
        var after = player
        after.rating = max(0, player.rating + delta)
        after.uncertainty = newUncertainty(player.uncertainty, configuration: configuration)
        after.gamesPlayed += 1
        switch result {
        case .win: after.wins += 1
        case .loss: after.losses += 1
        case .draw: after.draws += 1
        }
        return RatingUpdate(before: player, after: after, expectedScore: expectedScore, actualScore: actual)
    }

    /// Both changes are calculated from the same pre-match snapshot.
    static func individualMatch(
        playerA: CompetitiveRating,
        playerB: CompetitiveRating,
        resultForA: CompetitiveResult,
        configuration: RatingConfiguration = .matchPoint
    ) -> IndividualRatingUpdates {
        let expectedA = expectedScore(
            ratingA: playerA.rating,
            ratingB: playerB.rating,
            configuration: configuration
        )
        return IndividualRatingUpdates(
            playerA: update(
                player: playerA,
                expectedScore: expectedA,
                result: resultForA,
                configuration: configuration
            ),
            playerB: update(
                player: playerB,
                expectedScore: 1 - expectedA,
                result: resultForA.inverse,
                configuration: configuration
            )
        )
    }

    static func teamRating(_ players: [CompetitiveRating]) -> Double? {
        guard !players.isEmpty else { return nil }
        return players.map(\.rating).reduce(0, +) / Double(players.count)
    }

    /// Doubles evidence is shared; each player's uncertainty determines their own movement.
    /// Group sports do not call this function because they do not carry a competitive rating.
    /// All calculations use the supplied pre-match arrays and are therefore simultaneous.
    static func teamMatch(
        teamA: [CompetitiveRating],
        teamB: [CompetitiveRating],
        resultForA: CompetitiveResult,
        configuration: RatingConfiguration = .matchPoint
    ) -> TeamRatingUpdates? {
        guard let ratingA = teamRating(teamA), let ratingB = teamRating(teamB) else { return nil }
        let expectedA = expectedScore(ratingA: ratingA, ratingB: ratingB, configuration: configuration)
        return TeamRatingUpdates(
            teamAExpectedScore: expectedA,
            teamA: teamA.map {
                update(player: $0, expectedScore: expectedA, result: resultForA, configuration: configuration)
            },
            teamB: teamB.map {
                update(player: $0, expectedScore: 1 - expectedA, result: resultForA.inverse, configuration: configuration)
            }
        )
    }

    static func teammateReviewScore(
        reviewCount: Int,
        actualAverage: Double,
        configuration: RatingConfiguration = .matchPoint
    ) -> Double {
        let count = Double(max(0, reviewCount))
        return (configuration.reviewPriorCount * configuration.reviewPriorRating + count * actualAverage)
            / (configuration.reviewPriorCount + count)
    }

    static func publicRating(_ exactRating: Double) -> Int { Int(exactRating.rounded()) }

    static func isProvisional(
        gamesPlayed: Int,
        configuration: RatingConfiguration = .matchPoint
    ) -> Bool {
        gamesPlayed < configuration.provisionalGames
    }
}
