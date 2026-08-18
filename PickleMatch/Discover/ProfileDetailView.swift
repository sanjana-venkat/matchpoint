import SwiftUI

/// A focused player profile sheet that uses the same quiet, editorial hierarchy
/// as the rest of Match Point. Summary information appears once, followed by
/// sport statistics and actions.
struct ProfileDetailView: View {
    let player: Player
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var openChat = false
    @State private var showChallenge = false

    private var profile: SportProfile? { player.profile(app.activeSport) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    identityBlock

                    if let profile {
                        statBlock(profile)
                        aboutBlock(profile)
                    } else {
                        aboutBlock(nil)
                    }
                }
                .padding(.horizontal, DesignSystem.Metrics.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Theme.bg)
            .safeAreaInset(edge: .bottom) { actionBar }
            .navigationTitle("Player profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseIconButton { dismiss() }
                }
            }
            .navigationDestination(isPresented: $openChat) {
                if let convo = app.conversation(with: player.id) {
                    ChatView(conversationId: convo.id)
                }
            }
            .sheet(isPresented: $showChallenge) {
                ChallengeComposerView(player: player)
            }
        }
    }

    private var identityBlock: some View {
        HStack(alignment: .center, spacing: 18) {
            AvatarView(avatar: player.avatar, size: 92)

            VStack(alignment: .leading, spacing: 7) {
                Text(player.name)
                    .font(Theme.heading(28))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)

                Text("Age \(player.age)")
                    .font(Theme.ui(15, weight: .medium))
                    .foregroundStyle(Theme.muted)

                Label(
                    "\(String(format: "%.1f", player.distanceMiles)) miles away · \(player.city)",
                    systemImage: "location.fill"
                )
                .font(Theme.ui(14, weight: .medium))
                .foregroundStyle(Theme.muted)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardCorner)
                .stroke(Theme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func statBlock(_ profile: SportProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("\(app.activeSport.title) overview")

            HStack(spacing: 10) {
                statTile("\(profile.rating)", "Rating")
                statTile(EloRating.tier(for: profile.rating), "Tier")
                statTile(profile.partnerStatus.short, "Status")
            }
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(Theme.heading(16))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(Theme.ui(12, weight: .medium))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardCorner)
                .stroke(Theme.hairline, lineWidth: 1)
        }
    }

    private func aboutBlock(_ profile: SportProfile?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("About \(player.name.components(separatedBy: " ").first ?? player.name)")

            Text(player.bio)
                .font(Theme.ui(16))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let profile {
                Divider()

                if !profile.homeCourt.isEmpty {
                    infoRow(
                        title: "Home court",
                        value: profile.homeCourt,
                        systemImage: "figure.pickleball"
                    )
                }

                infoRow(
                    title: "Playing style",
                    value: profile.selfAssessment.rawValue,
                    systemImage: "figure.mind.and.body"
                )

                infoRow(
                    title: "Looking for",
                    value: profile.partnerStatus.short,
                    systemImage: profile.partnerStatus.systemImage
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardCorner)
                .stroke(Theme.hairline, lineWidth: 1)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.heading(18))
            .foregroundStyle(Theme.ink)
    }

    private func infoRow(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.muted)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.ui(12, weight: .medium))
                    .foregroundStyle(Theme.muted)
                Text(value)
                    .font(Theme.ui(15, weight: .medium))
                    .foregroundStyle(Theme.ink)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            profileAction(
                title: "Message",
                systemImage: "bubble.left",
                filled: false
            ) {
                app.like(player)
                openChat = true
            }

            profileAction(
                title: "Create challenge",
                systemImage: "flag.checkered",
                filled: true
            ) {
                app.like(player)
                showChallenge = true
            }
        }
        .padding(.horizontal, DesignSystem.Metrics.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }

    private func profileAction(
        title: String,
        systemImage: String,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Theme.ui(14, weight: .semibold))
                .foregroundStyle(filled ? Theme.surface : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    filled ? Theme.ink : Theme.surface,
                    in: RoundedRectangle(cornerRadius: Theme.cardCorner)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cardCorner)
                        .stroke(Theme.ink, lineWidth: filled ? 0 : 1)
                }
        }
        .buttonStyle(SorbetScaleButtonStyle())
    }
}
