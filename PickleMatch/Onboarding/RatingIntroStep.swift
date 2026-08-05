import SwiftUI

/// Explains the optional, uncapped per-sport Elo system and its starting rating.
struct RatingIntroStep: View {
    let sport: Sport
    let onContinue: () -> Void

    @State private var revealed = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StepHeader(title: "Your \(sport.title) rating",
                               subtitle: "Everyone starts here. Play to move it.")

                    // Starting rating hero
                    VStack(spacing: 6) {
                        Text("Starting rating")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(revealed ? "80" : "–")
                            .font(.system(size: 72, weight: .heavy).monospacedDigit())
                            .foregroundStyle(Theme.accent)
                            .contentTransition(.numericText())
                        Text(EloRating.tier(for: EloRating.start))
                            .font(.headline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Theme.accent.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 20))
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.6).delay(0.2)) { revealed = true }
                    }

                    // Scale
                    ratingScale

                    // How it works
                    VStack(alignment: .leading, spacing: 14) {
                        Text("How it works").font(.title3.bold())
                        bullet("scalemass", "Every sport starts at 80.", "There is no upper ceiling, and this number is separate from your other sports.")
                        bullet("arrow.up.right", "Verified wins move it gradually.", "Typical results change 1–2 points; beating stronger players can earn 3–5.")
                        bullet("arrow.down.right", "Lose and it dips.", "Losing to a lower-rated player costs more than losing to a stronger one.")
                        bullet("checkmark.seal", "Both players confirm the result.", "Ratings only change once you and your opponent agree on who won — the same idea chess.com uses.")
                    }
                }
                .padding()
            }
            PrimaryButton(title: "Got it — let's set up", action: onContinue)
                .padding()
        }
    }

    private var ratingScale: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    LinearGradient(colors: [.red, .orange, .yellow, .green],
                                   startPoint: .leading, endPoint: .trailing)
                        .clipShape(Capsule())
                    // Starting marker
                    Circle().fill(.white)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Theme.accent, lineWidth: 4))
                        .offset(x: geo.size.width * 0.4 - 9)
                }
            }
            .frame(height: 14)
            HStack {
                Text("0 · New").font(.caption2)
                Spacer()
                Text("80 · You").font(.caption2.bold())
                Spacer()
                Text("200+ · Uncapped").font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func bullet(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
