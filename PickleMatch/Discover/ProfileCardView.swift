import SwiftUI

/// Swipeable player sticker card using the shared Sorbet Pop visual language.
struct ProfileCardView: View {
    let player: Player
    let sport: Sport

    private var profile: SportProfile? { player.profile(sport) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                .fill(Theme.ink)
                .offset(x: 7, y: 8)

            VStack(spacing: 0) {
                header
                details
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .stroke(Theme.ink, lineWidth: 3.5)
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 510)
        .padding(.trailing, 7)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        ZStack {
            Theme.surface

            Circle()
                .stroke(Theme.ink.opacity(0.11), lineWidth: 18)
                .frame(width: 116, height: 116)
                .offset(x: -94, y: -22)

            SportIcon(sport: sport, size: 150)
                .opacity(0.10)
                .rotationEffect(.degrees(-11))
                .offset(x: 80, y: 22)

            VStack(spacing: 0) {
                HStack {
                    Text(sport == .pickleball ? "DINK PARTNER" : "RALLY PARTNER")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Theme.ink.opacity(0.68))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.surface.opacity(0.84), in: Capsule())
                    Spacer()
                    RatingBadge(rating: player.rating(sport), sport: sport, showTier: true)
                }

                Spacer()

                AvatarView(avatar: player.avatar, size: 104)
                    .rotationEffect(.degrees(-3))

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(player.name)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                        Text("\(player.age)")
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    .foregroundStyle(Theme.ink)

                    HStack(spacing: 12) {
                        Label("\(player.distanceMiles, specifier: "%.1f") mi", systemImage: "location.fill")
                        Label(player.city, systemImage: "mappin.circle.fill")
                    }
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink.opacity(0.72))
                }
            }
            .padding(20)
        }
        .frame(height: 306)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 11) {
            if let profile {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Tag(
                            text: profile.partnerStatus.short,
                            systemImage: profile.partnerStatus.systemImage,
                            color: Theme.blue
                        )
                        Tag(
                            text: profile.selfAssessment.rawValue,
                            systemImage: "figure.mind.and.body",
                            color: Theme.pink
                        )
                        if profile.ownsEquipment {
                            Tag(text: "Has gear", systemImage: "bag.fill", color: Theme.lime)
                        }
                        if profile.playedTournaments {
                            Tag(text: "Tournament", systemImage: "trophy.fill", color: Theme.grape)
                        }
                    }
                }

                if !profile.homeCourt.isEmpty {
                    HStack(spacing: 6) {
                        SportIcon(sport: sport, size: 16)
                        Text(profile.homeCourt)
                    }
                    .font(Theme.ui(12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                }
            }

            Text(player.bio)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.72))
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            HStack {
                Text("Tap for the full scoop")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.grape)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.grape)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
