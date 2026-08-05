import Foundation

/// Compact chess-inspired ladder. Everyone starts at 80 and the scale has no
/// upper ceiling. Changes stay intentionally small so a long-term record,
/// rather than one match, defines a player.
enum EloRating {
    static let start = 80
    static let minRating = 0

    /// Probability that player A beats player B.
    static func expectedScore(_ ratingA: Int, vs ratingB: Int) -> Double {
        1.0 / (1.0 + pow(10.0, Double(ratingB - ratingA) / 40.0))
    }

    /// New rating for `player` after a result against `opponent`.
    /// `didWin` = true if `player` won.
    static func newRating(player: Int, opponent: Int, didWin: Bool) -> Int {
        let gap = opponent - player
        let magnitude: Int
        if didWin {
            if gap >= 50 { magnitude = 5 }
            else if gap >= 30 { magnitude = 4 }
            else if gap >= 10 { magnitude = 3 }
            else { magnitude = gap < -20 ? 1 : 2 }
            return player + magnitude
        } else {
            if gap <= -50 { magnitude = 5 }
            else if gap <= -30 { magnitude = 4 }
            else if gap <= -10 { magnitude = 3 }
            else { magnitude = gap > 20 ? 1 : 2 }
            return max(minRating, player - magnitude)
        }
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
