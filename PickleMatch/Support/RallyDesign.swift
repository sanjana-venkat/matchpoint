import SwiftUI
import UIKit

struct RallyCheckbox: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { isOn.toggle() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn ? RallyPalette.ink : RallyPalette.creamDeep)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isOn ? RallyPalette.ink : RallyPalette.rule, lineWidth: 1.5)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(RallyPalette.sun)
                    }
                }
                .frame(width: 28, height: 28)

                Text(title)
                    .font(RallyType.body(15, weight: .semibold))
                    .foregroundStyle(RallyPalette.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Selected" : "Not selected")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Rally visual system, adapted to Matchpoint's domain models

enum RallyPalette {
    /// White is the primary canvas and inverse text color. Warm neutrals are
    /// reserved for secondary controls so the brand accents and black cards pop.
    static let cream = Color.white
    static let creamDeep = Color(hex: "F5F1EA")
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

extension Sport {
    /// Sport identity colors tuned to stay saturated against Rally's cream
    /// canvas and legible beside its black typography.
    var rallyAccent: Color {
        switch self {
        case .pickleball: Color(hex: "F4C22C")
        case .soccer: Color(hex: "2CB9B0")
        case .volleyball: Color(hex: "CE4F8B")
        case .badminton: Color(hex: "79CFA6")
        case .pingPong: Color(hex: "ED7834")
        case .cricket: Color(hex: "D84A3E")
        default: RallyPalette.sun
        }
    }
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
        Group {
            switch ImageCatalog.resolve(name) {
            case .bundled(let assetName):
                if let image = UIImage(named: assetName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else {
                    catalogPlaceholder
                }
            case .remote(let url):
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.22))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure:
                        catalogPlaceholder
                    case .empty:
                        catalogPlaceholder.overlay(ProgressView().tint(RallyPalette.inkMuted))
                    @unknown default:
                        catalogPlaceholder
                    }
                }
            case .missing:
                catalogPlaceholder
            }
        }
        .accessibilityHidden(true)
    }

    private var catalogPlaceholder: some View {
        ZStack {
            RallyPalette.court
            Image(systemName: "figure.pickleball")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(RallyPalette.inkMuted)
        }
    }
}

/// Shared sport mark. MatchPoint uses one outline language throughout the app.
struct RallySportAssetIcon: View {
    let sport: Sport
    var size: CGFloat = 28
    var fallbackColor: Color = RallyPalette.ink

    var body: some View {
        SportIcon(sport: sport, size: size, color: fallbackColor)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension Player {
    var rallyPhotoName: String {
        if let portrait = avatar.portraitAssetName {
            return portrait
        }
        switch name {
        case let value where value.contains("Maya"): return ImageCatalog.playerKey(slot: 2)
        case let value where value.contains("Diego"): return ImageCatalog.playerKey(slot: 7)
        case let value where value.contains("Priya"): return ImageCatalog.playerKey(slot: 10)
        case let value where value.contains("Sam"): return ImageCatalog.playerKey(slot: 9)
        case let value where value.contains("Aisha"): return ImageCatalog.playerKey(slot: 17)
        case let value where value.contains("Tyler"): return ImageCatalog.playerKey(slot: 19)
        case let value where value.contains("Grace"): return ImageCatalog.playerKey(slot: 8)
        case let value where value.contains("Leo"): return ImageCatalog.playerKey(slot: 15)
        case let value where value.contains("Hannah"): return ImageCatalog.playerKey(slot: 4)
        case let value where value.contains("Marcus"): return ImageCatalog.playerKey(slot: 3)
        default: return ImageCatalog.playerKey(slot: 1)
        }
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
    var ringWidth: CGFloat? = nil

    var body: some View {
        RallyPhoto(name: player.rallyPhotoName)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(ring, lineWidth: ringWidth ?? max(2, size * 0.055)))
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
    var tone: Color? = nil

    var body: some View {
        ZStack {
            Circle().fill(tone ?? sport.rallyAccent)
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
                            RallySportAssetIcon(
                                sport: sport,
                                size: 24,
                                fallbackColor: active ? RallyPalette.cream : RallyPalette.ink
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

struct RallySelectorOption: Identifiable, Equatable {
    let id: String
    let title: String
    var subtitle: String? = nil
}

/// An app-owned dropdown replacement. It expands inline so selection never
/// inherits a platform menu, material, typography, or corner treatment.
struct RallyOptionSelector: View {
    let label: String
    let selection: String
    let options: [RallySelectorOption]
    var showsLabel = true
    let select: (RallySelectorOption) -> Void
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        if showsLabel {
                            Text(label).rallyEyebrow()
                        }
                        Text(selection)
                            .font(RallyType.action)
                            .foregroundStyle(RallyPalette.ink)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(RallyPalette.inkMuted)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 58)
                .background(RallyPalette.creamDeep, in: Capsule())
            }
            .buttonStyle(RallyPressStyle())
            .accessibilityLabel("\(label), \(selection)")
            .accessibilityHint(expanded ? "Collapses the options" : "Shows the options")

            if expanded {
                VStack(spacing: 4) {
                    ForEach(options) { option in
                        let selected = option.title == selection
                        Button {
                            select(option)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                                expanded = false
                            }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title).font(RallyType.action)
                                    if let subtitle = option.subtitle {
                                        Text(subtitle).font(RallyType.caption)
                                            .foregroundStyle(selected ? RallyPalette.creamMuted : RallyPalette.inkMuted)
                                    }
                                }
                                Spacer()
                                if selected {
                                    Circle().fill(RallyPalette.sun).frame(width: 12, height: 12)
                                }
                            }
                            .foregroundStyle(selected ? RallyPalette.cream : RallyPalette.ink)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 52)
                            .background(selected ? RallyPalette.ink : .clear, in: Capsule())
                        }
                        .buttonStyle(RallyPressStyle())
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(8)
                .background(RallyPalette.creamDeep, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
                .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
            }
        }
    }
}

/// Branded date/time selection made from Rally capsules rather than the native
/// compact DatePicker popover.
struct RallyDateTimeSelector: View {
    let label: String
    @Binding var selection: Date
    @State private var expanded = false

    private let calendar = Calendar.current
    private var dates: [Date] {
        let start = calendar.startOfDay(for: .now)
        return (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    private var times: [Int] { Array(stride(from: 7 * 60, through: 22 * 60, by: 30)) }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Text(label).font(RallyType.action)
                    Spacer()
                    Text(selection.formatted(.dateTime.day().month(.abbreviated)))
                    Text(selection.formatted(.dateTime.hour().minute()))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .font(RallyType.meta)
                .foregroundStyle(RallyPalette.ink)
                .padding(.horizontal, 18)
                .frame(minHeight: 56)
                .background(RallyPalette.creamDeep, in: Capsule())
            }
            .buttonStyle(RallyPressStyle())

            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose a day").rallyEyebrow()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(dates, id: \.self) { date in
                                let selected = calendar.isDate(date, inSameDayAs: selection)
                                Button { choose(date: date) } label: {
                                    VStack(spacing: 2) {
                                        Text(date.formatted(.dateTime.weekday(.abbreviated))).font(RallyType.caption)
                                        Text(date.formatted(.dateTime.day())).font(RallyType.numeral(22))
                                    }
                                    .foregroundStyle(selected ? RallyPalette.cream : RallyPalette.ink)
                                    .frame(width: 68, height: 58)
                                    .background(selected ? RallyPalette.ink : .clear, in: Capsule())
                                    .overlay(Capsule().stroke(RallyPalette.ink.opacity(selected ? 0 : 0.22), lineWidth: 1.5))
                                }
                                .buttonStyle(RallyPressStyle())
                                .accessibilityAddTraits(selected ? .isSelected : [])
                            }
                        }
                    }

                    Text("Choose a time").rallyEyebrow()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(times, id: \.self) { minutes in
                                let selected = isSelected(minutes: minutes)
                                Button { choose(minutes: minutes) } label: {
                                    Text(timeLabel(minutes))
                                        .font(RallyType.action)
                                        .foregroundStyle(selected ? RallyPalette.cream : RallyPalette.ink)
                                        .padding(.horizontal, 16)
                                        .frame(height: 46)
                                        .background(selected ? RallyPalette.ink : .clear, in: Capsule())
                                        .overlay(Capsule().stroke(RallyPalette.ink.opacity(selected ? 0 : 0.22), lineWidth: 1.5))
                                }
                                .buttonStyle(RallyPressStyle())
                                .accessibilityAddTraits(selected ? .isSelected : [])
                            }
                        }
                    }
                }
                .padding(18)
                .background(RallyPalette.creamDeep, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
                .transition(.scale(scale: 0.97, anchor: .top).combined(with: .opacity))
            }
        }
    }

    private func choose(date: Date) {
        let time = calendar.dateComponents([.hour, .minute], from: selection)
        selection = calendar.date(bySettingHour: time.hour ?? 18, minute: time.minute ?? 0, second: 0, of: date) ?? selection
    }

    private func choose(minutes: Int) {
        selection = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: selection) ?? selection
    }

    private func isSelected(minutes: Int) -> Bool {
        calendar.component(.hour, from: selection) * 60 + calendar.component(.minute, from: selection) == minutes
    }

    private func timeLabel(_ minutes: Int) -> String {
        let date = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour().minute())
    }
}
