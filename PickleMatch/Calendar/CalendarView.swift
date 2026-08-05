import SwiftUI

/// Upcoming face-offs arranged as playful match-ticket stickers.
struct CalendarView: View {
    @EnvironmentObject var app: AppState

    private var upcoming: [FaceOff] { app.upcomingFaceOffs }
    private var grouped: [(String, [FaceOff])] {
        Dictionary(grouping: upcoming) {
            $0.date.formatted(.dateTime.weekday(.wide).month().day())
        }
        .sorted { ($0.value.first?.date ?? .now) < ($1.value.first?.date ?? .now) }
        .map { ($0.key, $0.value) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    SorbetSectionTitle(
                        title: "Game days",
                        kicker: "\(upcoming.count) upcoming",
                        color: Theme.grape
                    )

                    if upcoming.isEmpty {
                        emptyState
                    } else {
                        ForEach(grouped, id: \.0) { day, faceOffs in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(day.lowercased())
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 7)
                                    .background(Theme.blue, in: Capsule())
                                    .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))

                                ForEach(faceOffs) { FaceOffTicket(faceOff: $0) }
                            }
                        }
                    }
                }
                .padding(18)
                .padding(.bottom, 12)
            }
            .toolbar { ToolbarItem(placement: .principal) { SportModeToggle() } }
            .navigationBarTitleDisplayMode(.inline)
            .sorbetScreen()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Theme.grape)
            Text("Nothing booked—yet")
                .font(.system(size: 22, weight: .black, design: .rounded))
            Text("Make a face-off official in Messages and it’ll land right here.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .card()
    }
}

private struct FaceOffTicket: View {
    let faceOff: FaceOff
    @EnvironmentObject var app: AppState

    private var opponent: Player? { app.player(faceOff.opponentId) }

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(faceOff.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 17, weight: .black, design: .rounded).monospacedDigit())
                Text(faceOff.date.formatted(.dateTime.day()))
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.grape)
            }
            .frame(width: 66)

            Rectangle()
                .fill(Theme.ink.opacity(0.18))
                .frame(width: 2)
                .overlay {
                    VStack(spacing: 5) {
                        ForEach(0..<7, id: \.self) { _ in
                            Circle().fill(Theme.bg).frame(width: 5, height: 5)
                        }
                    }
                }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 9) {
                    if let opponent { AvatarView(avatar: opponent.avatar, size: 38) }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Vs. \(faceOff.opponentName)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                        Text(faceOff.state == .awaitingResult ? "result pending" : "locked in 🔒")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(faceOff.state == .awaitingResult ? Theme.pink : Theme.grape)
                    }
                }

                Label(faceOff.venue, systemImage: "mappin.and.ellipse")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)

                if !faceOff.wager.isEmpty {
                    Tag(text: faceOff.wager, systemImage: "gift.fill", color: Theme.lime)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}
