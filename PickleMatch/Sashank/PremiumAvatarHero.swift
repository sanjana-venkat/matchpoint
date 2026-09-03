import SwiftUI

/// The static home identity treatment. The portrait stays consistent across
/// sports; only the equipment marker and sport theme change with the picker.
struct PremiumAvatarHero: View {
    let avatar: Avatar
    let sport: Sport
    let name: String
    let rating: Int
    var isCompact = false

    var body: some View {
        Group {
            if isCompact {
                compactHero
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else {
                expandedHero
                    .transition(.scale(scale: 1.03).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.86), value: isCompact)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(sport.title), \(rating) MP rating")
    }

    private var expandedHero: some View {
        VStack(spacing: 8) {
            Text(name)
                .font(RallyType.title)
                .foregroundStyle(RallyPalette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(sport.rallyAccent.opacity(0.18))

                portrait
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    // Center the portrait's face/torso axis rather than the
                    // asymmetric waving-hand artwork bounds.
                    .offset(x: 10)

                sportMarker
                    .padding(16)

                VStack(alignment: .leading, spacing: -2) {
                    Text("\(rating)")
                        .font(RallyType.numeral(52))
                        .contentTransition(.numericText(value: Double(rating)))
                    Text(sport.category == .individual ? "MP RATING" : "PEER RATED")
                        .font(RallyType.eyebrow)
                        .tracking(1.1)
                }
                .foregroundStyle(RallyPalette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 54)
                .background(RallyPalette.cream.opacity(0.94), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(RallyPalette.ink.opacity(0.14), lineWidth: 1))
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(height: 278)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(RallyPalette.ink.opacity(0.16), lineWidth: 1.4))
        }
    }

    private var compactHero: some View {
        HStack(spacing: 14) {
            portrait
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(RallyType.cardTitle)
                    .foregroundStyle(RallyPalette.ink)
                HStack(spacing: 6) {
                    RallySportAssetIcon(sport: sport, size: 21)
                    Text(sport.title)
                        .font(RallyType.caption)
                        .foregroundStyle(RallyPalette.inkMuted)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: -2) {
                Text("\(rating)")
                    .font(RallyType.numeral(34))
                    .contentTransition(.numericText(value: Double(rating)))
                Text(sport.category == .individual ? "MP RATING" : "PEER RATED")
                    .font(RallyType.eyebrow)
                    .tracking(1)
            }
            .foregroundStyle(RallyPalette.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(sport.rallyAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @ViewBuilder private var portrait: some View {
        if let imageName = avatar.portraitAssetName {
            RallyPhoto(name: imageName, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            AvatarView(avatar: avatar, size: 210)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder private var sportMarker: some View {
        RallySportAssetIcon(sport: sport, size: 38)
            .frame(width: 54, height: 54)
            .background(RallyPalette.cream.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    PremiumAvatarHero(avatar: .fallback, sport: .pickleball, name: "Alex", rating: 86)
        .padding()
        .background(RallyPalette.cream)
}
