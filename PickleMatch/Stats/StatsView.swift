import SwiftUI
import Charts

/// Holistic analytics: win %, totals, rating peaks/lows, an interactive rating
/// chart with time-period selection, and the full match log.
struct StatsView: View {
    @EnvironmentObject var app: AppState
    @State private var period: StatsPeriod = .month

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    SorbetSectionTitle(title: "Your numbers", kicker: "Sweat receipts", color: Theme.blue)
                    headline
                    summaryGrid
                    ratingChartCard
                    peaksCard
                    matchLog
                }
                .padding()
            }
            .background(Theme.bg)
            .toolbar { ToolbarItem(placement: .principal) { SportModeToggle() } }
            .navigationBarTitleDisplayMode(.inline)
            .sorbetScreen()
        }
    }

    // MARK: Headline rating

    private var headline: some View {
        VStack(spacing: 4) {
            Text("CURRENT RATING")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(Theme.ink.opacity(0.56))
            Text("\(app.currentRating)")
                .font(.system(size: 66, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.ink)
            Text(EloRating.tier(for: app.currentRating).lowercased())
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Theme.grape)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Theme.surface.opacity(0.75), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Theme.lime, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner).stroke(Theme.ink, lineWidth: 3))
        .background {
            RoundedRectangle(cornerRadius: Theme.cardCorner)
                .fill(Theme.ink)
                .offset(x: 5, y: 6)
        }
    }

    // MARK: Summary tiles

    private var summaryGrid: some View {
        HStack(spacing: 12) {
            tile("\(app.myMatches.count)", "Matches", "figure.pickleball", Theme.blue)
            tile("\(app.wins)-\(app.losses)", "W – L", "trophy.fill", Theme.lime)
            tile("\(Int(app.winPct))%", "Win rate", "percent", Theme.pink)
        }
    }

    private func tile(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    // MARK: Rating chart

    private var filteredHistory: [RatingPoint] {
        let cutoff = period.cutoff
        let pts = app.ratingHistory.filter { $0.date >= cutoff }
        return pts.count >= 2 ? pts : app.ratingHistory.suffix(2).map { $0 }
    }

    private var ratingChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rating over time")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                Spacer()
            }
            MinimalChoiceBar(
                options: StatsPeriod.allCases.map(\.label),
                selection: Binding(
                    get: { period.label },
                    set: { label in
                        period = StatsPeriod.allCases.first { $0.label == label } ?? period
                    }
                )
            )

            if filteredHistory.count >= 2 {
                Chart(filteredHistory) { point in
                    AreaMark(x: .value("Date", point.date),
                             y: .value("Rating", point.rating))
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.grape.opacity(0.35), .clear],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    LineMark(x: .value("Date", point.date),
                             y: .value("Rating", point.rating))
                        .foregroundStyle(Theme.grape)
                        .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: chartDomain)
                .frame(height: 200)
            } else {
                Text("Play some matches to build your rating history.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(height: 120)
            }
        }
        .card()
    }

    private var chartDomain: ClosedRange<Int> {
        let ratings = filteredHistory.map(\.rating)
        let lo = max(1, (ratings.min() ?? 40) - 5)
        let hi = min(100, (ratings.max() ?? 60) + 5)
        return lo...hi
    }

    // MARK: Peaks

    private var peaksCard: some View {
        HStack(spacing: 12) {
            peak("Peak rating", app.peakRating, .green, "arrow.up.forward")
            peak("Lowest rating", app.lowRating, .red, "arrow.down.forward")
        }
    }

    private func peak(_ label: String, _ point: RatingPoint?, _ color: Color, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon).font(.caption).foregroundStyle(color)
            Text(point.map { "\($0.rating)" } ?? "—").font(.title2.bold())
            if let point {
                Text(point.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Match log

    private var matchLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Match history")
                .font(.system(size: 18, weight: .black, design: .rounded))
            if app.myMatches.isEmpty {
                Text("No matches recorded yet.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(app.myMatches) { MatchRow(record: $0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct MatchRow: View {
    let record: MatchRecord

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(avatar: record.opponentAvatar, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.opponentName)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                Text("\(record.date.formatted(date: .abbreviated, time: .omitted)) · \(record.venue)")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Opponent rating \(record.opponentRatingAtTime)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(record.didWin ? "WON" : "LOST")
                    .font(.caption.bold())
                    .foregroundStyle(record.didWin ? Theme.grape : Theme.pink)
                Text(record.ratingDelta >= 0 ? "+\(record.ratingDelta)" : "\(record.ratingDelta)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(record.ratingDelta >= 0 ? Theme.grape : Theme.pink)
            }
        }
        .padding(.vertical, 4)
        Divider().overlay(Theme.ink.opacity(0.14))
    }
}

// MARK: - Period

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week, month, year, twoYears
    var id: String { rawValue }
    var label: String {
        switch self {
        case .week: return "1W"
        case .month: return "1M"
        case .year: return "1Y"
        case .twoYears: return "2Y"
        }
    }
    var cutoff: Date {
        let cal = Calendar.current
        switch self {
        case .week: return cal.date(byAdding: .day, value: -7, to: .now)!
        case .month: return cal.date(byAdding: .month, value: -1, to: .now)!
        case .year: return cal.date(byAdding: .year, value: -1, to: .now)!
        case .twoYears: return cal.date(byAdding: .year, value: -2, to: .now)!
        }
    }
}
