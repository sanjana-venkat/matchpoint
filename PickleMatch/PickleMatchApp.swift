import SwiftUI

@main
struct PickleMatchApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .tint(app.themeColor)
                .preferredColorScheme(.dark)
        }
    }
}

/// Top-level router. Shows onboarding until the user has completed setup,
/// then shows the main tabbed experience.
struct RootView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedPrototype = ProcessInfo.processInfo.arguments.contains("-demo-established")

    var body: some View {
        Group {
            if !selectedPrototype {
                PrototypeStateChooser { established in
                    established ? app.loadEstablishedPrototype() : app.loadNewUserPrototype()
                    withAnimation(.easeInOut(duration: 0.25)) { selectedPrototype = true }
                }
            } else {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demo-chat"),
               app.hasCompletedOnboarding,
               let conversation = app.conversations.first {
                NavigationStack {
                    ChatView(conversationId: conversation.id)
                }
            } else if app.hasCompletedOnboarding {
                SashankMainView()
                    .transition(.opacity)
            } else {
                OnboardingFlowView()
                    .transition(.opacity)
            }
#else
            if app.hasCompletedOnboarding {
                SashankMainView()
                    .transition(.opacity)
            } else {
                OnboardingFlowView()
                    .transition(.opacity)
            }
#endif
            }
        }
        .animation(.easeInOut, value: app.hasCompletedOnboarding)
    }
}

private struct PrototypeStateChooser: View {
    let select: (Bool) -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                Text("Choose a prototype state.")
                    .font(Theme.heading(36))
                    .tracking(-1)
                Text("Explore the complete first-time setup or jump into a populated long-term player account.")
                    .font(Theme.ui(15))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(4)

                VStack(spacing: 12) {
                    prototypeButton(
                        title: "New user",
                        detail: "Complete onboarding with an empty profile, inbox, friend list, challenges, matches, and statistics.",
                        icon: "sparkles",
                        established: false
                    )
                    prototypeButton(
                        title: "Established player",
                        detail: "Open Alex's populated account with three sports, 42 friends, messages, challenges, history, and statistics.",
                        icon: "trophy.fill",
                        established: true
                    )
                }
                Spacer()
                Text("Prototype data is stored only for this app session.")
                    .font(Theme.ui(11))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }

    private func prototypeButton(title: String, detail: String, icon: String, established: Bool) -> some View {
        Button { select(established) } label: {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 48, height: 48)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(Theme.heading(18))
                    Text(detail).font(Theme.ui(11)).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(Theme.ink)
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(SorbetScaleButtonStyle())
    }
}
