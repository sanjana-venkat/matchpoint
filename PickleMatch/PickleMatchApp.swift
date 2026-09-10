import SwiftUI
import Combine

@main
struct PickleMatchApp: App {
    @UIApplicationDelegateAdaptor(MatchPointAppDelegate.self) private var appDelegate
    @StateObject private var app = AppState()
    @StateObject private var session = BackendSessionController()
    @StateObject private var location = LocationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(session)
                .environmentObject(location)
                .tint(app.themeColor)
                .preferredColorScheme(.light)
                .task { session.start() }
                .onOpenURL { session.handleAuthCallback($0) }
                .onReceive(PushNotificationService.shared.$deviceToken.compactMap { $0 }) { token in
                    Task { await app.registerPushToken(token) }
                }
        }
    }
}

/// Top-level router. Shows onboarding until the user has completed setup,
/// then shows the main tabbed experience.
struct RootView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject private var session: BackendSessionController
    @EnvironmentObject private var location: LocationService
    @State private var selectedPrototype = {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-demo-established") || arguments.contains("-demo-new")
    }()

    var body: some View {
        Group {
            if usesDemoLaunchArguments {
                appExperience
            } else {
                switch session.phase {
                case .starting:
                    backendLoadingView
                case .unavailable(let message):
#if DEBUG
                    prototypeRouter
#else
                    backendUnavailableView(message)
#endif
                case .signedOut:
                    BackendAuthView()
                case .signedIn(let activeSession):
                    if session.isPasswordRecovery {
                        PasswordResetView()
                    } else {
                        authenticatedExperience(userID: activeSession.user.id)
                    }
                }
            }
        }
        .animation(.easeInOut, value: app.hasCompletedOnboarding)
        .onReceive(location.$location.compactMap { $0 }) { value in
            Task { await app.syncLocationAndRefresh(value) }
        }
        .onChange(of: app.hasCompletedOnboarding) { _, completed in
            if completed {
                location.requestWhenInUseAccess()
                if !usesDemoLaunchArguments {
                    Task { await PushNotificationService.shared.requestAuthorizationAndRegister() }
                }
            }
        }
    }

    private var usesDemoLaunchArguments: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-demo-established")
            || arguments.contains("-demo-new")
            || arguments.contains("-demo-main")
            || arguments.contains("-demo-chat")
            || arguments.contains("-demo-native-thread")
            || arguments.contains("-onboarding-step")
    }

    @ViewBuilder private var prototypeRouter: some View {
        if !selectedPrototype {
            PrototypeStateChooser { established in
                established ? app.loadEstablishedPrototype() : app.loadNewUserPrototype()
                withAnimation(.easeInOut(duration: 0.25)) { selectedPrototype = true }
            }
        } else {
            appExperience
        }
    }

    @ViewBuilder private var appExperience: some View {
#if DEBUG
            if app.hasCompletedOnboarding {
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

    private func authenticatedExperience(userID: UUID) -> some View {
        Group {
            if app.isHydratingBackend || !app.hasHydratedBackend {
                backendLoadingView
            } else {
                appExperience
            }
        }
        .task(id: userID) {
            await app.hydrateAuthenticatedUser(id: userID)
            if app.hasCompletedOnboarding {
                location.requestWhenInUseAccess()
                await PushNotificationService.shared.requestAuthorizationAndRegister()
            }
        }
    }

    private var backendLoadingView: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ProgressView("Loading Match Point…")
                .font(Theme.ui(14))
                .tint(Theme.ink)
        }
    }

    private func backendUnavailableView(_ message: String) -> some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Backend configuration required").font(Theme.heading(22))
                Text(message).font(Theme.ui(13)).foregroundStyle(Theme.muted)
            }
            .padding(28)
        }
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
        .preferredColorScheme(.light)
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
