import Foundation

/// Compatibility facade for existing UI call sites. The production calculation
/// lives in `RatingEngine`; new code should carry uncertainty and exact decimals.
enum EloRating {
    static let start = 80
    static let minRating = 0

    /// Probability that player A beats player B.
    static func expectedScore(_ ratingA: Int, vs ratingB: Int) -> Double {
        RatingEngine.expectedScore(ratingA: Double(ratingA), ratingB: Double(ratingB))
    }

    /// New rating for `player` after a result against `opponent`.
    /// `didWin` = true if `player` won.
    static func newRating(player: Int, opponent: Int, didWin: Bool) -> Int {
        let current = CompetitiveRating(rating: Double(player))
        let expected = RatingEngine.expectedScore(ratingA: Double(player), ratingB: Double(opponent))
        return RatingEngine.publicRating(
            RatingEngine.update(
                player: current,
                expectedScore: expected,
                result: didWin ? .win : .loss
            ).after.rating
        )
    }

    /// Convenience: the signed point change a result would produce.
    static func delta(player: Int, opponent: Int, didWin: Bool) -> Int {
        newRating(player: player, opponent: opponent, didWin: didWin) - player
    }

    /// A friendly preview string, e.g. "+12" or "−3".
    static func deltaString(player: Int, opponent: Int, didWin: Bool) -> String {
        let d = delta(player: player, opponent: opponent, didWin: didWin)
        return d >= 0 ? "+\(d)" : "−\(abs(d))"
    }

    /// Human label for a numeric rating band.
    static func tier(for rating: Int) -> String {
        switch rating {
        case ..<60:  return "Developing"
        case ..<80:  return "Club"
        case ..<100: return "Competitive"
        case ..<120: return "Advanced"
        default:     return "Elite"
        }
    }
}
