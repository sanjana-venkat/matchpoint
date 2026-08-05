import SwiftUI

/// Pick one or both sports. Selecting both unlocks the in-app mode toggle later.
struct SportSelectStep: View {
    @Binding var selected: [Sport]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StepHeader(title: "What do you play?",
                               subtitle: "Choose one or both. You can add or remove sports anytime.")

                    ForEach(Sport.allCases) { sport in
                        SportCard(sport: sport, isSelected: selected.contains(sport)) {
                            toggle(sport)
                        }
                    }

                    if selected.count > 1 {
                        Label("You'll be able to switch between \(Sport.allCases.map(\.title).joined(separator: " & ")) modes from the top of the app.",
                              systemImage: "arrow.left.arrow.right.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.accent)
                            .padding()
                            .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            PrimaryButton(title: "Continue", enabled: !selected.isEmpty, action: onContinue)
                .padding()
        }
    }

    private func toggle(_ sport: Sport) {
        withAnimation(.spring(response: 0.3)) {
            if let idx = selected.firstIndex(of: sport) {
                selected.remove(at: idx)
            } else {
                selected.append(sport)
            }
        }
    }
}

private struct SportCard: View {
    let sport: Sport
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        SelectableCard(title: sport.title, sport: sport, isSelected: isSelected, action: onTap)
    }
}
