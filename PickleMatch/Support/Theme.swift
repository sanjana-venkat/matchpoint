import SwiftUI

/// Match Point's light pastel system, translated from Sashank's 8/17 prototype.
enum Scoreline {
    static let ink = Color(hex: "151821")
    static let surface = Color.white
    static let surface2 = Color(hex: "F4F6FA")
    static let surface3 = Color(hex: "EBEEF4")
    static let hairline = Color(hex: "E6E9F0")
    static let textPrimary = ink
    static let textSecondary = Color(hex: "858C9E")
    static let signal = Color(hex: "4CA85F")
    static let socialTeal = Color(hex: "3D82C4")
    static let canvas = Color(hex: "F7F8FB")
}

enum DesignSystem {
    enum Palette {
        static let appBackground = Scoreline.canvas
        static let canvas = Scoreline.canvas
        static let surfaceElevated = Scoreline.surface
        static let accent = Scoreline.textPrimary
        static let textPrimary = Scoreline.textPrimary
        static let textSecondary = Scoreline.textSecondary
        static let warning = Scoreline.signal
        static let neonBlue = Scoreline.textSecondary
        static let neonRed = Scoreline.signal
        static func sport(_ sport: Sport) -> Color { Scoreline.textPrimary }
    }

    enum Metrics {
        static let cardRadius: CGFloat = 12
        static let controlRadius: CGFloat = 12
        static let pillRadius: CGFloat = 12
        static let screenPadding: CGFloat = 20
        static let verticalRhythm: CGFloat = 16
        static let standardShadow = Color(hex: "141A2C").opacity(0.08)
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
    static let bg = Scoreline.canvas
    static let canvas = Scoreline.canvas
    static let surface = Scoreline.surface
    static let surface2 = Scoreline.surface2
    static let ink = Scoreline.textPrimary
    static let muted = Scoreline.textSecondary
    static let hairline = Scoreline.hairline
    static let faint = Scoreline.surface3
    static let accent = Scoreline.signal
    static let signal = Scoreline.signal
    static let neonBlue = Scoreline.textSecondary
    static let neonGreen = Color(hex: "4CA85F")
    static let neonOrange = Color(hex: "D0762F")
    static let neonRed = Color(hex: "CE5555")
    static let mint = Color(hex: "EFF8F1")
    static let warm = Color(hex: "FDF3E9")

    // Legacy semantic colors collapse into the monochrome system.
    static let pink = Color(hex: "CE5555")
    static let grape = Color(hex: "7857BE")
    static let blue = Color(hex: "3D82C4")
    static let lime = Color(hex: "4CA85F")
    static let badminton = Color(hex: "3D82C4")

    static func color(for sport: Sport) -> Color {
        switch sport {
        case .pickleball: return Color(hex: "4CA85F")
        case .badminton: return Color(hex: "3D82C4")
        case .tennis: return Color(hex: "B58A27")
        case .pingPong: return Color(hex: "D0762F")
        case .squash: return Color(hex: "A45C9C")
        case .volleyball: return Color(hex: "7857BE")
        case .cricket: return Color(hex: "CE5555")
        case .soccer: return Color(hex: "2F7A50")
        case .baseball: return Color(hex: "536FA8")
        case .football: return Color(hex: "9A6A43")
        }
    }
    static let cardCorner: CGFloat = 22

    /// Condensed heavy italic is exclusive to ratings, scores, and statistics.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default)
        .width(.compressed)
        .italic()
    }

    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
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
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
                    .shadow(color: DesignSystem.Metrics.standardShadow, radius: 8, y: 2)
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
