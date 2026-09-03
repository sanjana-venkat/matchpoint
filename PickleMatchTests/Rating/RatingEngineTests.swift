import XCTest
@testable import MatchPointRating

final class RatingEngineTests: XCTestCase {
    private let provisional = CompetitiveRating(rating: 80, uncertainty: 12)

    func testEqualPlayersMoveSymmetrically() {
        let win = RatingEngine.individualMatch(
            playerA: provisional,
            playerB: provisional,
            resultForA: .win
        )
        XCTAssertEqual(win.playerA.expectedScore, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(win.playerA.delta, 6, accuracy: 0.000_001)
        XCTAssertEqual(win.playerB.delta, -6, accuracy: 0.000_001)

        let loss = RatingEngine.individualMatch(
            playerA: provisional,
            playerB: provisional,
            resultForA: .loss
        )
        XCTAssertEqual(loss.playerA.delta, -6, accuracy: 0.000_001)
        XCTAssertEqual(loss.playerB.delta, 6, accuracy: 0.000_001)
    }

    func testStrongerAndWeakerOpponentEvidence() {
        let stronger = CompetitiveRating(rating: 95, uncertainty: 12)
        let weaker = CompetitiveRating(rating: 65, uncertainty: 12)

        let beatStronger = RatingEngine.individualMatch(
            playerA: provisional,
            playerB: stronger,
            resultForA: .win
        ).playerA.delta
        let beatEqual = RatingEngine.individualMatch(
            playerA: provisional,
            playerB: provisional,
            resultForA: .win
        ).playerA.delta
        let beatWeaker = RatingEngine.individualMatch(
            playerA: provisional,
            playerB: weaker,
            resultForA: .win
        ).playerA.delta

        XCTAssertGreaterThan(beatStronger, beatEqual)
        XCTAssertGreaterThan(beatEqual, beatWeaker)

        let loseToWeaker = RatingEngine.individualMatch(
            playerA: provisional,
            playerB: weaker,
            resultForA: .loss
        ).playerA.delta
        let loseToStronger = RatingEngine.individualMatch(
            playerA: provisional,
            playerB: stronger,
            resultForA: .loss
        ).playerA.delta
        XCTAssertLessThan(loseToWeaker, loseToStronger)
    }

    func testAllRequestedStrengthCombinationsHaveCorrectDirection() {
        let rating95 = CompetitiveRating(rating: 95, uncertainty: 12)
        let rating80 = CompetitiveRating(rating: 80, uncertainty: 12)

        XCTAssertGreaterThan(RatingEngine.individualMatch(playerA: rating80, playerB: rating95, resultForA: .win).playerA.delta, 0)
        XCTAssertLessThan(RatingEngine.individualMatch(playerA: rating80, playerB: rating95, resultForA: .loss).playerA.delta, 0)
        XCTAssertGreaterThan(RatingEngine.individualMatch(playerA: rating95, playerB: rating80, resultForA: .win).playerA.delta, 0)
        XCTAssertLessThan(RatingEngine.individualMatch(playerA: rating95, playerB: rating80, resultForA: .loss).playerA.delta, 0)
    }

    func testProvisionalPlayerMovesMoreThanEstablishedPlayer() {
        let established = CompetitiveRating(rating: 80, uncertainty: 3, gamesPlayed: 40)
        let provisionalDelta = RatingEngine.individualMatch(
            playerA: provisional,
            playerB: provisional,
            resultForA: .win
        ).playerA.delta
        let establishedDelta = RatingEngine.individualMatch(
            playerA: established,
            playerB: provisional,
            resultForA: .win
        ).playerA.delta
        XCTAssertGreaterThan(provisionalDelta, establishedDelta)
        XCTAssertEqual(establishedDelta, 1, accuracy: 0.000_001)
    }

    func testUncertaintyDecaysButNeverBelowMinimum() {
        XCTAssertEqual(RatingEngine.newUncertainty(12), 11.52, accuracy: 0.000_001)
        XCTAssertEqual(RatingEngine.newUncertainty(3), 3, accuracy: 0.000_001)
    }

    func testDoublesTeamAveragesAndDirections() throws {
        let teamA = [82.0, 78, 75, 85].map { CompetitiveRating(rating: $0, uncertainty: 12) }
        let teamB = [88.0, 84, 83, 79].map { CompetitiveRating(rating: $0, uncertainty: 12) }
        XCTAssertEqual(try XCTUnwrap(RatingEngine.teamRating(teamA)), 80, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(RatingEngine.teamRating(teamB)), 83.5, accuracy: 0.000_001)

        let updates = try XCTUnwrap(RatingEngine.teamMatch(teamA: teamA, teamB: teamB, resultForA: .win))
        XCTAssertTrue(updates.teamA.allSatisfy { $0.delta > 0 })
        XCTAssertTrue(updates.teamB.allSatisfy { $0.delta < 0 })
    }

    func testDoublesPartnersUseTheirOwnUncertainty() throws {
        let provisionalPlayer = CompetitiveRating(rating: 80, uncertainty: 12)
        let establishedPlayer = CompetitiveRating(rating: 80, uncertainty: 3, gamesPlayed: 30)
        let opponent = CompetitiveRating(rating: 80, uncertainty: 12)
        let updates = try XCTUnwrap(
            RatingEngine.teamMatch(
                teamA: [provisionalPlayer, establishedPlayer],
                teamB: [opponent, opponent],
                resultForA: .win
            )
        )
        XCTAssertGreaterThan(updates.teamA[0].delta, updates.teamA[1].delta)
    }

    func testBayesianReviewScoreProtectsSmallSamples() {
        let onePerfectReview = RatingEngine.teammateReviewScore(reviewCount: 1, actualAverage: 5)
        let twentyPerfectReviews = RatingEngine.teammateReviewScore(reviewCount: 20, actualAverage: 5)
        XCTAssertEqual(onePerfectReview, 25.0 / 6.0, accuracy: 0.000_001)
        XCTAssertLessThan(onePerfectReview, 5)
        XCTAssertGreaterThan(twentyPerfectReviews, onePerfectReview)
        XCTAssertEqual(twentyPerfectReviews, 4.8, accuracy: 0.000_001)
    }

    func testReviewCalculationCannotModifyCompetitiveRating() {
        let player = CompetitiveRating(rating: 84.387, uncertainty: 4, gamesPlayed: 27)
        _ = RatingEngine.teammateReviewScore(reviewCount: 23, actualAverage: 4.7)
        XCTAssertEqual(player.rating, 84.387, accuracy: 0.000_001)
    }

    func testPublicRatingAndProvisionalStatus() {
        XCTAssertEqual(RatingEngine.publicRating(84.387), 84)
        XCTAssertTrue(RatingEngine.isProvisional(gamesPlayed: 9))
        XCTAssertFalse(RatingEngine.isProvisional(gamesPlayed: 10))
    }
}
