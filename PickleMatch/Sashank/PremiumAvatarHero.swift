import SwiftUI

/// The static home identity treatment. The portrait stays consistent across
/// sports; only the equipment marker and sport theme change with the picker.
struct PremiumAvatarHero: View {
    let avatar: Avatar
    let sport: Sport
    let name: String
    let rating: Int

    var body: some View {
        compactHero
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(sport.title), \(rating) MP rating")
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
                Text(sport.title)
                    .font(RallyType.caption)
                    .foregroundStyle(RallyPalette.inkMuted)
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

}

#Preview {
    PremiumAvatarHero(avatar: .fallback, sport: .pickleball, name: "Alex", rating: 86)
        .padding()
        .background(RallyPalette.cream)
}
