import SwiftUI

/// Sport-specific onboarding questions. Drives the profile fields other players
/// filter on: partner status, home court, equipment, tournaments, self-assessment.
struct SportQuestionsStep: View {
    let sport: Sport
    @Binding var profile: SportProfile
    let isLast: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    StepHeader(title: "\(sport.title) profile",
                               subtitle: "A few quick questions so the right players find you.")

                    // Partner status
                    question("Do you have a doubles partner?") {
                        VStack(spacing: 10) {
                            ForEach(PartnerStatus.allCases) { status in
                                ChoiceRow(title: status.rawValue,
                                          systemImage: status.systemImage,
                                          isSelected: profile.partnerStatus == status,
                                          tint: Theme.accent) {
                                    profile.partnerStatus = status
                                }
                            }
                        }
                    }

                    // Home court
                    question("Where do you usually play?") {
                        TextField("Home court or facility (optional)", text: $profile.homeCourt)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Equipment
                    question("Do you have your own equipment?") {
                        Toggle(isOn: $profile.ownsEquipment) {
                            Label("I bring my own paddle & balls", systemImage: "bag.fill")
                        }
                        .tint(Theme.accent)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Tournaments
                    question("Have you played in tournaments?") {
                        Toggle(isOn: $profile.playedTournaments) {
                            Label("I've competed in tournaments", systemImage: "trophy.fill")
                        }
                        .tint(Theme.accent)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Self-assessment
                    question("How would you describe yourself?") {
                        VStack(spacing: 10) {
                            ForEach(SelfAssessment.allCases) { level in
                                ChoiceRow(title: level.rawValue,
                                          systemImage: nil,
                                          isSelected: profile.selfAssessment == level,
                                          tint: Theme.accent) {
                                    profile.selfAssessment = level
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            PrimaryButton(title: isLast ? "Finish setup" : "Next sport", action: onContinue)
                .padding()
        }
        .onAppear {
            if profile.rating == 0 { profile.rating = EloRating.start }
        }
    }

    private func question<Content: View>(_ text: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text).font(.headline)
            content()
        }
    }
}

/// A tappable selectable row used across onboarding.
struct ChoiceRow: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    var tint: Color = Theme.accent
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage).frame(width: 24)
                }
                Text(title).fontWeight(.medium)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? tint : Color.secondary.opacity(0.4))
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint, lineWidth: isSelected ? 2 : 0))
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}
