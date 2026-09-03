import Foundation
import Supabase

@MainActor
final class BackendSessionController: ObservableObject {
    enum Phase {
        case starting
        case unavailable(String)
        case signedOut
        case signedIn(Session)
    }

    @Published private(set) var phase: Phase = .starting
    @Published private(set) var isWorking = false
    @Published private(set) var isPasswordRecovery = false
    @Published var message: String?

    private let dependencies: BackendDependencies
    private var authTask: Task<Void, Never>?

    init(dependencies: BackendDependencies = .shared) {
        self.dependencies = dependencies
    }

    deinit {
        authTask?.cancel()
    }

    func start() {
        guard authTask == nil else { return }
        guard let client = dependencies.client else {
            phase = .unavailable(dependencies.configurationError?.localizedDescription ?? "Backend unavailable")
            return
        }

        authTask = Task { [weak self] in
            for await (event, session) in client.auth.authStateChanges {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if event == .passwordRecovery {
                        self?.isPasswordRecovery = true
                    } else if event == .signedOut || event == .userDeleted {
                        self?.isPasswordRecovery = false
                    }
                    self?.phase = session.map(Phase.signedIn) ?? .signedOut
                }
            }
        }
    }

    func signIn(email: String, password: String) async {
        guard let client = dependencies.client else { return }
        await perform {
            _ = try await client.auth.signIn(email: email, password: password)
        }
    }

    func createAccount(email: String, password: String, displayName: String) async {
        guard let client = dependencies.client else { return }
        await perform(successMessage: "Check your email to confirm your account, then sign in.") {
            _ = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(displayName)],
                redirectTo: BackendConfiguration.authCallbackURL
            )
        }
    }

    func handleAuthCallback(_ url: URL) {
        guard url.scheme == BackendConfiguration.authCallbackURL.scheme,
              url.host == BackendConfiguration.authCallbackURL.host,
              let client = dependencies.client else { return }
        Task {
            do {
                _ = try await client.auth.session(from: url)
            } catch {
                message = "That sign-in link is invalid or has expired. Request a new one and try again."
            }
        }
    }

    func requestPasswordReset(email: String) async {
        guard let client = dependencies.client else { return }
        await perform(successMessage: "Check your email for a password reset link.") {
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: BackendConfiguration.authCallbackURL
            )
        }
    }

    func updatePassword(_ password: String) async {
        guard let client = dependencies.client else { return }
        await perform(successMessage: "Your password has been updated.") {
            _ = try await client.auth.update(user: UserAttributes(password: password))
            isPasswordRecovery = false
        }
    }

    func signOut() async {
        guard let client = dependencies.client else { return }
        await perform {
            try await client.auth.signOut()
        }
    }

    private func perform(successMessage: String? = nil, operation: () async throws -> Void) async {
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            try await operation()
            message = successMessage
        } catch {
            message = error.localizedDescription
        }
    }
}
