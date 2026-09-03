import SwiftUI
import UIKit

// MARK: - Match Point brand

struct MatchPointLogo: View {
    var compact = false
    var color = Theme.ink

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().stroke(color, lineWidth: 2)
                Circle().fill(color).frame(width: 5, height: 5).offset(x: 6, y: -5)
                Path { path in
                    path.move(to: CGPoint(x: 7, y: 21))
                    path.addLine(to: CGPoint(x: 7, y: 8))
                    path.addLine(to: CGPoint(x: 14, y: 15))
                    path.addLine(to: CGPoint(x: 21, y: 8))
                    path.addLine(to: CGPoint(x: 21, y: 21))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 28, height: 28)

            if !compact {
                Text("MATCH POINT")
                    .font(Theme.heading(15))
                    .tracking(1.1)
                    .foregroundStyle(color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Match Point")
    }
}

struct CloseIconButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
                .background(Theme.surface2, in: Circle())
                .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

// MARK: - Color from hex (for avatars)

extension Color {
    init(hex: String) {
        let s = Scanner(string: hex)
        var rgb: UInt64 = 0
        s.scanHexInt64(&rgb)
        self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
}

// MARK: - Avatar bubble

struct SportIcon: View {
    let sport: Sport
    var size: CGFloat = 28
    var isSelected = false
    var color = Theme.ink

    var body: some View {
        Group {
            if let asset = sport.illustrationIconAsset {
                RallyPhoto(name: asset, contentMode: .fit)
            } else {
                SportGlyphShape(sport: sport)
                    .stroke(
                        color,
                        style: StrokeStyle(
                            lineWidth: isSelected ? 2 : 1.6,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .padding(size * 0.08)
            }
        }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct SportGlyphShape: Shape {
    let sport: Sport

    func path(in rect: CGRect) -> Path {
        var p = Path()
        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
            p.addEllipse(in: CGRect(x: x-r, y: y-r, width: r*2, height: r*2))
        }
        func line(_ points: [CGPoint]) {
            guard let first = points.first else { return }
            p.move(to: first); points.dropFirst().forEach { p.addLine(to: $0) }
        }

        switch sport {
        case .pickleball:
            p.move(to: .init(x: 5.1, y: 3.5))
            p.addCurve(to: .init(x: 13.7, y: 13.5), control1: .init(x: 11.0, y: 0.6), control2: .init(x: 17.1, y: 7.8))
            p.addCurve(to: .init(x: 8.1, y: 15.2), control1: .init(x: 12.1, y: 15.6), control2: .init(x: 10.2, y: 16.0))
            p.addCurve(to: .init(x: 5.1, y: 3.5), control1: .init(x: 3.4, y: 11.1), control2: .init(x: 2.8, y: 6.2))
            line([.init(x: 8.7, y: 14.9), .init(x: 6.5, y: 20.8)])
            circle(18.6, 17.2, 3.2)
            circle(17.3, 16.1, 0.42); circle(19.4, 16.2, 0.42)
            circle(18.3, 17.8, 0.42); circle(20.0, 18.3, 0.42)
        case .badminton:
            circle(12, 18.5, 2.5)
            line([.init(x: 10.8, y: 16.3), .init(x: 6.5, y: 5.5)]); line([.init(x: 12, y: 16), .init(x: 12, y: 5)]); line([.init(x: 13.2, y: 16.3), .init(x: 17.5, y: 5.5)])
            p.move(to: .init(x: 6.5, y: 5.5)); p.addQuadCurve(to: .init(x: 17.5, y: 5.5), control: .init(x: 12, y: 3))
        case .tennis:
            p.addEllipse(in: CGRect(x: 4.75, y: 1.75, width: 10, height: 12.5)); line([.init(x: 9.75, y: 1.75), .init(x: 9.75, y: 14.25)]); line([.init(x: 4.75, y: 8), .init(x: 14.75, y: 8)]); line([.init(x: 9.75, y: 14.25), .init(x: 9.75, y: 21)]); circle(18.75, 18.25, 2.75)
        case .pingPong:
            circle(10, 8.75, 5.25); line([.init(x: 10, y: 14), .init(x: 10, y: 19.5)]); circle(17.75, 17.75, 2.1)
        case .squash:
            p.addEllipse(in: CGRect(x: 5.9, y: 2, width: 8.2, height: 9.8)); line([.init(x: 8.5, y: 11.3), .init(x: 10, y: 15), .init(x: 11.5, y: 11.3)]); line([.init(x: 10, y: 15), .init(x: 10, y: 21)]); circle(17.9, 18.4, 1.9); circle(17.9, 18.4, 0.08)
        case .volleyball:
            circle(12, 12, 8.5); p.move(to: .init(x: 12, y: 3.5)); p.addCurve(to: .init(x: 12, y: 20.5), control1: .init(x: 15.5, y: 8.5), control2: .init(x: 15.5, y: 15.5)); p.move(to: .init(x: 3.7, y: 10)); p.addCurve(to: .init(x: 20.3, y: 10), control1: .init(x: 8.5, y: 12.5), control2: .init(x: 15.5, y: 12.5))
        case .cricket:
            p.addRoundedRect(in: CGRect(x: 6.8, y: 7.5, width: 4.6, height: 13), cornerSize: CGSize(width: 2, height: 2)); line([.init(x: 9.1, y: 7.5), .init(x: 9.1, y: 3)]); circle(18, 17.5, 2.6); p.move(to: .init(x: 15.9, y: 16.7)); p.addQuadCurve(to: .init(x: 20.1, y: 16.7), control: .init(x: 18, y: 15.8))
        case .soccer:
            circle(12, 12, 8.5); line([.init(x: 12, y: 8.4), .init(x: 15.1, y: 10.7), .init(x: 13.9, y: 14.4), .init(x: 10.1, y: 14.4), .init(x: 8.9, y: 10.7), .init(x: 12, y: 8.4)]); line([.init(x: 12, y: 8.4), .init(x: 12, y: 3.5)]); line([.init(x: 15.1, y: 10.7), .init(x: 19.9, y: 9.2)]); line([.init(x: 13.9, y: 14.4), .init(x: 16.4, y: 18.8)]); line([.init(x: 10.1, y: 14.4), .init(x: 7.6, y: 18.8)]); line([.init(x: 8.9, y: 10.7), .init(x: 4.1, y: 9.2)])
        case .baseball:
            circle(12, 12, 8.5); p.move(to: .init(x: 5.8, y: 5.2)); p.addCurve(to: .init(x: 5.8, y: 18.8), control1: .init(x: 3.6, y: 9.3), control2: .init(x: 3.6, y: 14.7)); p.move(to: .init(x: 18.2, y: 5.2)); p.addCurve(to: .init(x: 18.2, y: 18.8), control1: .init(x: 20.4, y: 9.3), control2: .init(x: 20.4, y: 14.7)); line([.init(x: 4.6, y: 9), .init(x: 6.5, y: 9.5)]); line([.init(x: 4.3, y: 12), .init(x: 6.3, y: 12)]); line([.init(x: 4.6, y: 15), .init(x: 6.5, y: 14.5)]); line([.init(x: 19.4, y: 9), .init(x: 17.5, y: 9.5)]); line([.init(x: 19.7, y: 12), .init(x: 17.7, y: 12)]); line([.init(x: 19.4, y: 15), .init(x: 17.5, y: 14.5)])
        case .football:
            p.move(to: .init(x: 3.8, y: 20.2)); p.addCurve(to: .init(x: 20.2, y: 3.8), control1: .init(x: 3.8, y: 11.5), control2: .init(x: 11.5, y: 3.8)); p.addCurve(to: .init(x: 3.8, y: 20.2), control1: .init(x: 20.2, y: 12.5), control2: .init(x: 12.5, y: 20.2)); line([.init(x: 9.3, y: 14.7), .init(x: 14.7, y: 9.3)]); line([.init(x: 9.9, y: 12.6), .init(x: 11.4, y: 14.1)]); line([.init(x: 11.25, y: 11.25), .init(x: 12.75, y: 12.75)]); line([.init(x: 12.6, y: 9.9), .init(x: 14.1, y: 11.4)])
        }

        return p.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

struct SelectableCard: View {
    let title: String
    var sport: Sport? = nil
    let isSelected: Bool
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let sport {
                    RallySportAssetIcon(
                        sport: sport,
                        size: 32,
                        fallbackColor: isSelected ? Theme.bg : Theme.ink
                    )
                }
                Text(title).font(Theme.ui(13, weight: .bold)).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark" : "circle")
                    .foregroundStyle(isSelected ? Theme.bg : Theme.muted)
            }
            .foregroundStyle(isDisabled ? Theme.muted.opacity(0.45) : (isSelected ? Theme.bg : Theme.ink))
            .padding(12)
            .frame(minHeight: 58)
            .background(isSelected ? Theme.ink : Theme.surface,
                        in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .opacity(isDisabled ? 0.62 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A quiet, app-owned alternative to the bright native segmented control.
struct MinimalChoiceBar: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { selection = option }
                } label: {
                    Text(option)
                        .font(RallyType.action)
                        .foregroundStyle(isSelected ? Theme.bg : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            isSelected ? Theme.ink : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(RallyPressStyle())
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.faint, in: Capsule())
    }
}

/// A legible full-width choice list for labels that do not belong in cramped tabs.
struct VerticalChoiceList: View {
    let options: [String]
    @Binding var selection: String
    var selectedFill: Color = Theme.surface2
    var selectedForeground: Color = Theme.ink

    var body: some View {
        VStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    withAnimation(.easeOut(duration: 0.14)) { selection = option }
                } label: {
                    Text(option)
                        .font(Theme.ui(14, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(isSelected ? selectedForeground : Theme.ink)
                    .padding(.horizontal, 15)
                    .frame(height: 48)
                    .background(isSelected ? selectedFill : Theme.surface,
                                in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius))
                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Metrics.controlRadius)
                        .stroke(isSelected ? Theme.ink.opacity(0.34) : Theme.hairline, lineWidth: isSelected ? 1.5 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

enum AppNavigationItem: Int {
    case home, map, matches, chat, profile
}

/// Product-owned monoline navigation artwork that stays consistent at every scale.
struct AppNavigationIcon: View {
    let item: AppNavigationItem
    var size: CGFloat = 23
    var color: Color = Theme.ink

    var body: some View {
        NavigationGlyphShape(item: item)
            .stroke(color, style: StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct NavigationGlyphShape: Shape {
    let item: AppNavigationItem

    func path(in rect: CGRect) -> Path {
        var path = Path()
        func line(_ points: [CGPoint]) {
            guard let first = points.first else { return }
            path.move(to: first)
            points.dropFirst().forEach { path.addLine(to: $0) }
        }

        switch item {
        case .home:
            line([.init(x: 2.8, y: 11.2), .init(x: 12, y: 3.2), .init(x: 21.2, y: 11.2)])
            line([.init(x: 5.3, y: 9.2), .init(x: 5.3, y: 20.8), .init(x: 18.7, y: 20.8), .init(x: 18.7, y: 9.2)])
            path.addRoundedRect(in: CGRect(x: 9.4, y: 14.2, width: 5.2, height: 6.6), cornerSize: .init(width: 1.2, height: 1.2))
        case .map:
            line([.init(x: 3, y: 5.2), .init(x: 9, y: 3.2), .init(x: 15, y: 5.2), .init(x: 21, y: 3.2), .init(x: 21, y: 18.8), .init(x: 15, y: 20.8), .init(x: 9, y: 18.8), .init(x: 3, y: 20.8), .init(x: 3, y: 5.2)])
            line([.init(x: 9, y: 3), .init(x: 9, y: 19)])
            line([.init(x: 15, y: 5), .init(x: 15, y: 21)])
        case .matches:
            path.addRoundedRect(in: CGRect(x: 3, y: 4, width: 18, height: 16), cornerSize: .init(width: 3, height: 3))
            line([.init(x: 7, y: 9), .init(x: 17, y: 9)])
            line([.init(x: 8, y: 14), .init(x: 11, y: 17), .init(x: 17, y: 11)])
        case .chat:
            path.addRoundedRect(in: CGRect(x: 2.4, y: 3.6, width: 14.2, height: 11.2), cornerSize: .init(width: 3.2, height: 3.2))
            line([.init(x: 7.2, y: 14.8), .init(x: 5.3, y: 18.6), .init(x: 10.1, y: 14.8)])
            path.addRoundedRect(in: CGRect(x: 9.5, y: 9.2, width: 12.1, height: 9.2), cornerSize: .init(width: 2.8, height: 2.8))
            line([.init(x: 16.8, y: 18.4), .init(x: 19.5, y: 21), .init(x: 19, y: 18.4)])
        case .profile:
            path.addEllipse(in: CGRect(x: 8.1, y: 3.1, width: 7.8, height: 7.8))
            path.move(to: .init(x: 3.8, y: 20.8))
            path.addQuadCurve(to: .init(x: 20.2, y: 20.8), control: .init(x: 12, y: 9.2))
        }
        return path.applying(.init(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

struct AvatarView: View {
    let avatar: Avatar
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            if let imageName = avatar.portraitAssetName,
               let image = UIImage(named: imageName) ?? UIImage(named: imageName + ".png") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } else {
                Circle().fill(Theme.surface2)

                Image(systemName: avatar.symbol)
                    .font(.system(size: size * 0.43, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.surface2, lineWidth: max(1, size * 0.018)))
        .accessibilityHidden(true)
    }
}

/// Shared compact action treatment for paired Accept/Decline-style decisions.
struct CompactActionButton: View {
    let title: String
    var primary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(12, weight: .semibold))
                .foregroundStyle(primary ? Theme.bg : Theme.ink)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(primary ? Theme.ink : Theme.surface2,
                            in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(primary ? Color.clear : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Character picker

struct AvatarChoiceStrip: View {
    @Binding var selection: Avatar
    var size: CGFloat = 66
    var choices: [Avatar] = Avatar.illustratedChoices

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(choices) { avatar in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                            selection = avatar
                        }
                    } label: {
                        AvatarView(avatar: avatar, size: size)
                            .overlay {
                                Circle()
                                    .stroke(
                                        selection.id == avatar.id ? Theme.accent : Color.clear,
                                        lineWidth: 3
                                    )
                                    .padding(-3)
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if selection.id == avatar.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundStyle(Theme.bg)
                                        .frame(width: 20, height: 20)
                                        .background(Theme.accent, in: Circle())
                                        .overlay(Circle().stroke(Theme.bg, lineWidth: 2))
                                }
                            }
                            .scaleEffect(selection.id == avatar.id ? 1 : 0.94)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Character \(avatar.id.capitalized)")
                    .accessibilityAddTraits(selection.id == avatar.id ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
        }
    }
}

// MARK: - Rating badge

struct RatingBadge: View {
    let rating: Int
    var sport: Sport = .pickleball
    var showTier = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.ink)

            VStack(spacing: showTier ? 1 : 0) {
                Text("\(rating)")
                    .font(Theme.display(19).monospacedDigit())
                if showTier {
                    Text(EloRating.tier(for: rating))
                        .font(Theme.ui(8, weight: .bold))
                        .textCase(.uppercase)
                        .opacity(0.75)
                }
            }
            .foregroundStyle(Theme.bg)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
        }
        .fixedSize()
    }
}

// MARK: - Big primary button

struct BottomCTA: View {
    let title: String
    var leadingSystemImage: String? = nil
    var enabled = true
    var accent = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let leadingSystemImage { Image(systemName: leadingSystemImage) }
                Text(title).font(Theme.ui(15, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.right").foregroundStyle(enabled ? RallyPalette.sun : Theme.muted)
            }
            .foregroundStyle(enabled ? RallyPalette.cream : Theme.muted)
            .padding(.horizontal, DesignSystem.Metrics.screenPadding)
            .frame(height: 52)
            .background(enabled ? RallyPalette.ink : Theme.surface2, in: Capsule())
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(SorbetScaleButtonStyle())
        .disabled(!enabled)
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        BottomCTA(title: title, leadingSystemImage: systemImage, enabled: enabled, action: action)
    }
}

// MARK: - Section header used on setup screens

struct StepHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.heading(34))
                .foregroundStyle(Theme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
