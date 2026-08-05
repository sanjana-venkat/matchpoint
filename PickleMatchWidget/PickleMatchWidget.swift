import SwiftUI
import WidgetKit

private struct MatchWidgetEntry: TimelineEntry {
    let date: Date
    let opponent: String
    let venue: String
    let matchDate: Date
    let sport: String
    let rating: Int

    var canStart: Bool {
        let interval = matchDate.timeIntervalSince(date)
        return interval <= 60 * 60 && interval >= -6 * 60 * 60
    }
}

private struct MatchWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MatchWidgetEntry {
        entry(from: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (MatchWidgetEntry) -> Void) {
        completion(entry(from: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MatchWidgetEntry>) -> Void) {
        let now = Date()
        let current = entry(from: now)
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [current], policy: .after(refresh)))
    }

    private func entry(from now: Date) -> MatchWidgetEntry {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let matchDate = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        return MatchWidgetEntry(
            date: now,
            opponent: "Priya Nair",
            venue: "Zilker Courts",
            matchDate: matchDate,
            sport: "Pickleball",
            rating: 55
        )
    }
}

private struct PickleMatchWidgetView: View {
    let entry: MatchWidgetEntry
    @Environment(\.widgetFamily) private var family

    private let forest = Color(red: 7 / 255, green: 17 / 255, blue: 14 / 255)
    private let surface = Color(red: 18 / 255, green: 30 / 255, blue: 26 / 255)
    private let mint = Color(red: 56 / 255, green: 224 / 255, blue: 177 / 255)
    private let ink = Color(red: 244 / 255, green: 243 / 255, blue: 237 / 255)

    var body: some View {
        Group {
            if family == .systemSmall {
                small
            } else {
                medium
            }
        }
        .containerBackground(for: .widget) { forest }
        .privacySensitive()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Next \(entry.sport) match with \(entry.opponent), " +
            "\(entry.matchDate.formatted(date: .abbreviated, time: .shortened)), at \(entry.venue). " +
            (entry.canStart ? "Start game is available." : "Open PickleMatch for details.")
        )
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "asterisk")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(mint)
                Spacer()
                Text("\(entry.rating)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(forest)
                    .frame(width: 38, height: 30)
                    .background(mint, in: RoundedRectangle(cornerRadius: 10))
            }

            Spacer()

            Text(entry.canStart ? "ready to play" : "up next")
                .font(.caption2.bold())
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(mint)
            Text(entry.opponent)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(1)
            Text(entry.matchDate.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                .font(.caption.bold())
                .foregroundStyle(ink.opacity(0.75))

            if entry.canStart {
                Text("START GAME  →")
                    .font(.caption2.bold())
                    .foregroundStyle(forest)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(mint, in: Capsule())
                    .padding(.top, 9)
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Label("NEXT MATCH", systemImage: "asterisk")
                    .font(.caption2.bold())
                    .tracking(1)
                    .foregroundStyle(mint)

                Spacer()

                Text(entry.opponent)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Text(entry.matchDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                    .font(.caption.bold())
                    .foregroundStyle(ink.opacity(0.78))
                    .lineLimit(1)
                Label(entry.venue, systemImage: "mappin.and.ellipse")
                    .font(.caption2)
                    .foregroundStyle(ink.opacity(0.70))
                    .lineLimit(1)
            }

            VStack(spacing: 6) {
                Text("\(entry.rating)")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                Text("MATCH\nRATING")
                    .font(.system(size: 8, weight: .bold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(forest)
            .frame(width: 72, height: 72)
            .background(mint, in: RoundedRectangle(cornerRadius: 20))

            Image(systemName: entry.canStart ? "play.fill" : "arrow.up.right")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(forest)
                .frame(width: 44, height: 44)
                .background(mint, in: Circle())
        }
        .padding(2)
    }
}

@main
struct PickleMatchWidget: Widget {
    let kind = "PickleMatchNextMatch"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MatchWidgetProvider()) { entry in
            PickleMatchWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Match")
        .description("See your next confirmed match and jump back into PickleMatch.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
