import SwiftUI

// MARK: - Rally visual system, adapted to Match Point's domain models

enum RallyPalette {
    static let cream = Color(hex: "F2E9DC")
    static let creamDeep = Color(hex: "E6D9C4")
    static let ink = Color(hex: "16150F")
    static let inkMuted = ink.opacity(0.55)
    static let creamMuted = cream.opacity(0.64)
    static let sun = Color(hex: "F4C22C")
    static let court = Color(hex: "3F5240")
    static let rule = ink.opacity(0.12)
    static let danger = Color(hex: "A93824")

    static let photoScrim = LinearGradient(
        colors: [.clear, ink.opacity(0.14), ink.opacity(0.90)],
        startPoint: .top,
        endPoint: .bottom
    )
}

enum RallyLayout {
    static let gutter: CGFloat = 24
    static let stack: CGFloat = 16
    static let section: CGFloat = 40
    static let photoRadius: CGFloat = 32
    static let cardRadius: CGFloat = 28
    static let insetRadius: CGFloat = 20
    static let navigationClearance: CGFloat = 118
}

enum RallyType {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default).width(.expanded)
    }

    static func numeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default).width(.expanded)
    }

    static func body(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static let hero = display(44)
    static let title = display(32)
    static let cardTitle = display(21)
    static let meta = body(15, weight: .medium)
    static let caption = body(13, weight: .medium)
    static let action = body(16, weight: .semibold)
    static let eyebrow = body(11, weight: .bold)
}

struct RallySquircle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }
}

extension View {
    func rallyPageGutter() -> some View {
        padding(.horizontal, RallyLayout.gutter)
    }

    func rallyLifted(_ strength: Double = 1) -> some View {
        shadow(
            color: RallyPalette.ink.opacity(0.10 * strength),
            radius: 24 * strength,
            x: 0,
            y: 12 * strength
        )
    }

    func rallyEyebrow(_ color: Color = RallyPalette.inkMuted) -> some View {
        font(RallyType.eyebrow)
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    func rallyDisplayLeading() -> some View {
        lineSpacing(-2).kerning(-0.6)
    }
}

struct RallyPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

struct RallyPillButton: View {
    enum Style { case ink, sun, outline, glass, court }

    let title: String
    var icon: String?
    var style: Style = .ink
    var fill = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .bold))
                }
            }
            .font(RallyType.action)
            .foregroundStyle(foreground)
            .padding(.horizontal, 22)
            .frame(maxWidth: fill ? .infinity : nil, minHeight: 50)
            .background(background)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(
                    RallyPalette.ink.opacity(style == .outline ? 0.88 : 0),
                    lineWidth: 1.5
                )
            }
            .opacity(enabled ? 1 : 0.42)
        }
        .buttonStyle(RallyPressStyle())
        .disabled(!enabled)
    }

    private var foreground: Color {
        switch style {
        case .ink, .court, .glass: RallyPalette.cream
        case .sun, .outline: RallyPalette.ink
        }
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .ink: RallyPalette.ink
        case .sun: RallyPalette.sun
        case .outline: Color.clear
        case .court: RallyPalette.court
        case .glass: Color.black.opacity(0.34).background(.ultraThinMaterial)
        }
    }
}

struct RallySectionHead: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).rallyEyebrow()
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(RallyType.caption)
                    .foregroundStyle(RallyPalette.inkMuted)
            }
        }
    }
}

struct RallyPhoto: View {
    let name: String
    var contentMode: ContentMode = .fill

    var body: some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .accessibilityHidden(true)
    }
}

extension Player {
    var rallyPhotoName: String {
        let key: String
        switch name {
        case let value where value.contains("Maya"): key = "player-maya"
        case let value where value.contains("Diego"): key = "player-andre"
        case let value where value.contains("Priya"): key = "player-june"
        case let value where value.contains("Sam"): key = "player-sam"
        case let value where value.contains("Aisha"): key = "player-nina"
        case let value where value.contains("Tyler"): key = "player-teo"
        case let value where value.contains("Grace"): key = "player-maya"
        case let value where value.contains("Leo"): key = "player-andre"
        case let value where value.contains("Hannah"): key = "player-june"
        case let value where value.contains("Marcus"): key = "player-sam"
        default: key = "player-teo"
        }
        return "Rally-\(key)"
    }

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var compactAvailability: String {
        guard let next = availability.sorted(by: { $0.startDate < $1.startDate }).first else {
            return "Availability not added"
        }
        return "\(next.startDate.formatted(.dateTime.weekday(.abbreviated))) · \(next.period.hours)"
    }
}

struct RallyPlayerAvatar: View {
    let player: Player
    var size: CGFloat = 48
    var ring = RallyPalette.cream

    var body: some View {
        RallyPhoto(name: player.rallyPhotoName)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(ring, lineWidth: max(2, size * 0.055)))
            .accessibilityLabel(player.name)
    }
}

struct RallySportTag: View {
    let sport: Sport
    var tone = RallyPalette.cream

    var body: some View {
        Text(sport.title)
            .rallyEyebrow(tone)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(tone.opacity(0.45), lineWidth: 1))
    }
}

struct RallyRatingPlate: View {
    let sport: Sport
    let profile: SportProfile?
    var diameter: CGFloat = 82
    var tone = RallyPalette.sun

    var body: some View {
        ZStack {
            Circle().fill(tone)
            VStack(spacing: -2) {
                Text(value)
                    .font(RallyType.numeral(diameter * (sport.category == .group ? 0.24 : 0.37)))
                    .foregroundStyle(RallyPalette.ink)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                Text(label)
                    .font(RallyType.body(diameter * 0.105, weight: .bold))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(RallyPalette.ink.opacity(0.60))
            }
            .padding(5)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityValue)
    }

    private var value: String {
        if sport.category == .group { return "PEER" }
        guard profile?.usesElo != false else { return "—" }
        return "\(profile?.rating ?? EloRating.start)"
    }

    private var label: String {
        if sport.category == .group { return "rated" }
        return profile?.usesElo == false ? "unrated" : "MP rating"
    }

    private var accessibilityValue: String {
        sport.category == .group
            ? "Peer rated in \(sport.title)"
            : (profile?.usesElo == false ? "Unrated in \(sport.title)" : "MP Rating \(profile?.rating ?? EloRating.start)")
    }
}

struct RallySportSelector: View {
    let sports: [Sport]
    let selection: Sport
    let select: (Sport) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(sports) { sport in
                    let active = sport == selection
                    Button { select(sport) } label: {
                        HStack(spacing: 8) {
                            SportIcon(
                                sport: sport,
                                size: 20,
                                isSelected: active,
                                color: active ? RallyPalette.cream : RallyPalette.ink
                            )
                            Text(sport.title)
                                .font(RallyType.action)
                        }
                        .foregroundStyle(active ? RallyPalette.cream : RallyPalette.ink)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 48)
                        .background(active ? RallyPalette.ink : .clear, in: Capsule())
                        .overlay {
                            Capsule().stroke(
                                RallyPalette.ink.opacity(active ? 0 : 0.22),
                                lineWidth: 1.5
                            )
                        }
                    }
                    .buttonStyle(RallyPressStyle())
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(.horizontal, RallyLayout.gutter)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }
}
