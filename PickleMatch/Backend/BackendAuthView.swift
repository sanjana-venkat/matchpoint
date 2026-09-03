import SwiftUI

struct BackendAuthView: View {
    @EnvironmentObject private var session: BackendSessionController
    @State private var mode: Mode = .signIn
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""

    private enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign in"
        case createAccount = "Create account"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer(minLength: 54)
                    Text("MATCH POINT")
                        .font(Theme.ui(12, weight: .bold))
                        .tracking(2.2)
                        .foregroundStyle(Theme.muted)
                    Text(mode == .signIn ? "Welcome back." : "Create your player profile.")
                        .font(Theme.display(46))
                        .tracking(-1.5)

                    Picker("Account action", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 12) {
                        if mode == .createAccount {
                            authField("Name", text: $displayName, contentType: .name)
                        }
                        authField("Email", text: $email, contentType: .emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        SecureField("Password", text: $password)
                            .textContentType(mode == .signIn ? .password : .newPassword)
                            .padding(.horizontal, 18)
                            .frame(height: 58)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 1.25))

                        if mode == .signIn {
                            Button("Forgot password?") {
                                Task { await session.requestPasswordReset(email: email) }
                            }
                            .font(Theme.ui(13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .disabled(!email.contains("@") || session.isWorking)
                            .opacity(email.contains("@") ? 1 : 0.4)
                        }
                    }

                    if let message = session.message {
                        Text(message)
                            .font(Theme.ui(13))
                            .foregroundStyle(Theme.muted)
                    }

                    Button(action: submit) {
                        Group {
                            if session.isWorking { ProgressView().tint(Theme.bg) }
                            else { Text(mode.rawValue).font(Theme.heading(17)) }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .foregroundStyle(Theme.bg)
                        .background(Theme.ink, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit || session.isWorking)
                    .opacity(canSubmit ? 1 : 0.45)

                    Text("By continuing, you agree to the Terms and acknowledge the Privacy Policy. These links will be connected before TestFlight.")
                        .font(Theme.ui(11))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(3)
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 8 && (mode == .signIn || !displayName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func authField(_ placeholder: String, text: Binding<String>, contentType: UITextContentType) -> some View {
        TextField(placeholder, text: text)
            .textContentType(contentType)
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 1.25))
    }

    private func submit() {
        Task {
            if mode == .signIn {
                await session.signIn(email: email, password: password)
            } else {
                await session.createAccount(email: email, password: password, displayName: displayName)
            }
        }
    }
}

struct PasswordResetView: View {
    @EnvironmentObject private var session: BackendSessionController
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                Spacer()
                Text("MATCH POINT")
                    .font(Theme.ui(12, weight: .bold))
                    .tracking(2.2)
                    .foregroundStyle(Theme.muted)
                Text("Choose a new password.")
                    .font(Theme.display(42))
                    .tracking(-1.2)

                SecureField("New password", text: $password)
                    .textContentType(.newPassword)
                    .authResetField()
                SecureField("Confirm password", text: $confirmation)
                    .textContentType(.newPassword)
                    .authResetField()

                if let message = session.message {
                    Text(message)
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.muted)
                }

                Button {
                    Task { await session.updatePassword(password) }
                } label: {
                    Group {
                        if session.isWorking { ProgressView().tint(Theme.bg) }
                        else { Text("Save new password").font(Theme.heading(17)) }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .foregroundStyle(Theme.bg)
                    .background(Theme.ink, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!isValid || session.isWorking)
                .opacity(isValid ? 1 : 0.45)
                Spacer()
            }
            .padding(24)
        }
    }

    private var isValid: Bool {
        password.count >= 8 && password == confirmation
    }
}

private extension View {
    func authResetField() -> some View {
        padding(.horizontal, 18)
            .frame(height: 58)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 1.25))
    }
}
