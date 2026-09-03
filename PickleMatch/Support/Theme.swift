import SwiftUI

/// Scoreline: a light, near-monochrome, typography-led athletic system.
enum Scoreline {
    static let ink = RallyPalette.cream
    static let surface = RallyPalette.cream
    static let surface2 = RallyPalette.creamDeep
    static let hairline = RallyPalette.rule
    static let textPrimary = RallyPalette.ink
    static let textSecondary = RallyPalette.inkMuted
    static let signal = RallyPalette.sun
    static let socialTeal = RallyPalette.court
}

enum DesignSystem {
    enum Palette {
        static let appBackground = Scoreline.ink
        static let canvas = Scoreline.ink
        static let surfaceElevated = Scoreline.surface
        static let accent = Scoreline.textPrimary
        static let textPrimary = Scoreline.textPrimary
        static let textSecondary = Scoreline.textSecondary
        static let warning = Scoreline.signal
        static let neonBlue = Scoreline.textSecondary
        static let neonRed = Scoreline.signal
        static func sport(_ sport: Sport) -> Color { sport.rallyAccent }
    }

    enum Metrics {
        static let cardRadius: CGFloat = RallyLayout.cardRadius
        static let controlRadius: CGFloat = RallyLayout.insetRadius
        static let pillRadius: CGFloat = 999
        static let screenPadding: CGFloat = RallyLayout.gutter
        static let verticalRhythm: CGFloat = 16
        static let standardShadow = Color.black.opacity(0.10)
    }

    enum TypeScale {
        static func screenTitle(_ size: CGFloat = 28) -> Font { Theme.heading(size) }
        static func eyebrow(_ size: CGFloat = 11) -> Font { Theme.ui(size, weight: .semibold) }
        static func body(_ size: CGFloat = 15) -> Font { Theme.ui(size) }
        static func cardTitle(_ size: CGFloat = 17) -> Font { Theme.heading(size) }
        static func caption(_ size: CGFloat = 11) -> Font { Theme.ui(size) }
    }
}

extension Color {
    static let appBackground = Scoreline.ink
    static let surfaceElevated = Scoreline.surface
    static let textPrimary = Scoreline.textPrimary
    static let textSecondary = Scoreline.textSecondary
    static let warning = Scoreline.signal
}

/// Compatibility aliases keep feature code compiling while enforcing Scoreline.
enum Theme {
    static let bg = Scoreline.ink
    static let canvas = Scoreline.ink
    static let surface = Scoreline.surface
    static let surface2 = Scoreline.surface2
    static let ink = Scoreline.textPrimary
    static let muted = Scoreline.textSecondary
    static let hairline = Scoreline.hairline
    static let faint = Scoreline.surface2
    static let accent = Scoreline.textPrimary
    static let signal = Scoreline.signal
    static let neonBlue = Scoreline.textSecondary
    static let neonGreen = Scoreline.textPrimary
    static let neonOrange = Scoreline.signal
    static let neonRed = Scoreline.signal
    static let mint = Scoreline.surface2
    static let warm = Scoreline.surface

    // Legacy semantic colors collapse into the monochrome system.
    static let pink = RallyPalette.danger
    static let grape = RallyPalette.court
    static let blue = Scoreline.socialTeal
    static let lime = RallyPalette.sun
    static let badminton = Scoreline.textPrimary

    static func color(for sport: Sport) -> Color { sport.rallyAccent }
    static let cardCorner = DesignSystem.Metrics.cardRadius

    /// Condensed heavy italic is exclusive to ratings, scores, and statistics.
    static func display(_ size: CGFloat) -> Font {
        RallyType.numeral(size)
    }

    static func heading(_ size: CGFloat) -> Font {
        RallyType.display(size)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        RallyType.body(size, weight: weight)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(SorbetCardModifier(padding: padding))
    }

    func sorbetScreen() -> some View {
        self
            .background(Theme.bg.ignoresSafeArea())
            .foregroundStyle(Theme.ink)
            .font(Theme.ui(15))
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
    }
}

private struct SorbetCardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: Theme.cardCorner)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner).stroke(Theme.hairline, lineWidth: 1))
            }
    }
}

struct Tag: View {
    let text: String
    var systemImage: String? = nil
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(Theme.ui(12, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.surface2)
        .foregroundStyle(Theme.ink)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SorbetSectionTitle: View {
    let title: String
    var kicker: String?
    var color = Theme.muted

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let kicker {
                Text(kicker.uppercased())
                    .font(Theme.ui(11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.muted)
            }
            Text(title)
                .font(Theme.heading(27))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StickerIconButton: View {
    let systemImage: String
    var color = Theme.surface
    var foreground = Theme.ink
    var size: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(color)
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.34, weight: .medium))
                    .foregroundStyle(foreground)
            }
            .frame(width: size, height: size)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(SorbetScaleButtonStyle())
    }
}

struct SorbetScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
