import SwiftUI

/// Full-screen profile with the two message options: start a conversation or
/// send a challenge (with an optional wager).
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
                VStack(spacing: 20) {
                    ProfileCardView(player: player, sport: app.activeSport)
                        .frame(height: 510)

                    if let profile { statBlock(profile) }

                    aboutBlock
                }
                .padding()
            }
            .background(Theme.bg)
            .safeAreaInset(edge: .bottom) { actionBar }
            .navigationTitle(player.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
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

    private func statBlock(_ profile: SportProfile) -> some View {
        HStack(spacing: 12) {
            statTile("\(profile.rating)", "Rating", app.themeColor)
            statTile(EloRating.tier(for: profile.rating), "Tier", .purple)
            statTile(profile.partnerStatus.short, "Status", .blue)
        }
    }

    private func statTile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var aboutBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The full scoop")
                .font(.system(size: 18, weight: .black, design: .rounded))
            Text(player.bio).foregroundStyle(Theme.ink.opacity(0.72))
            if let profile, !profile.homeCourt.isEmpty {
                Divider()
                Label("Plays at \(profile.homeCourt)", systemImage: "figure.pickleball")
                    .font(.subheadline)
            }
            Label("\(player.distanceMiles, specifier: "%.1f") miles away · \(player.city)", systemImage: "location.fill")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                app.like(player)
                openChat = true
            } label: {
                Label("Message", systemImage: "bubble.left.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Theme.blue, in: Capsule())
                    .overlay(Capsule().stroke(Theme.ink, lineWidth: 2.5))
            }
            .buttonStyle(SorbetScaleButtonStyle())

            Button {
                app.like(player)
                showChallenge = true
            } label: {
                Label("Challenge", systemImage: "flag.checkered")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Theme.lime, in: Capsule())
                    .overlay(Capsule().stroke(Theme.ink, lineWidth: 2.5))
            }
            .buttonStyle(SorbetScaleButtonStyle())
        }
        .padding()
        .background(Theme.surface)
        .overlay(alignment: .top) { Rectangle().fill(Theme.ink.opacity(0.14)).frame(height: 1) }
    }
}
