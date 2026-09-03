import SwiftUI

/// Feature-parity version of Sashank's player drawer, painted in Rally's visual language.
struct ProfileDetailView: View {
    enum PresentationMode {
        case standard
        case connectionRequest
    }

    let player: Player
    var presentationMode: PresentationMode = .standard
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var openChat = false
    @State private var notice: String?

    private var profile: SportProfile? { player.profile(app.activeSport) }
    private var conversation: Conversation? { app.conversation(with: player.id) }
    private var isBlocked: Bool { conversation?.isBlocked == true }
    private var otherSports: [Sport] {
        player.profiles.keys
            .filter { $0 != app.activeSport && $0.isAvailableInBeta }
            .sorted { $0.title < $1.title }
    }
    private var mutualPlayers: [Player] {
        app.players.filter { app.friendIds.contains($0.id) && $0.id != player.id }.prefix(6).map { $0 }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                drawerHeader
                    .padding(.horizontal, RallyLayout.gutter)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(RallyPalette.cream)
                    .zIndex(10)
                Divider().overlay(RallyPalette.rule)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        aboutSection
                        sportRatingsSection
                        mutualConnectionsSection
                        if presentationMode == .connectionRequest {
                            requestActions
                        } else {
                            connectButton
                            secondaryConnectionButton
                        }
                    }
                    .padding(.horizontal, RallyLayout.gutter)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .background(RallyPalette.cream.ignoresSafeArea())
            .overlay(alignment: .top) {
                if let notice {
                    Text(notice)
                        .font(RallyType.caption)
                        .foregroundStyle(RallyPalette.cream)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(RallyPalette.ink, in: Capsule())
                        .padding(.top, 78)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(4)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $openChat) {
                if let conversation = app.conversation(with: player.id) {
                    ChatView(conversationId: conversation.id)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var drawerHeader: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(RallyPalette.ink.opacity(0.18))
                .frame(width: 42, height: 4)

            HStack(spacing: 12) {
                RallyPhoto(name: player.rallyPhotoName)
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(app.activeSport.rallyAccent, lineWidth: 2))

                VStack(alignment: .leading, spacing: 3) {
                    Text(player.name)
                        .font(RallyType.cardTitle)
                        .foregroundStyle(RallyPalette.ink)
                        .lineLimit(1)
                    Text("@\(displayUsername) · \(player.distanceMiles, specifier: "%.1f") miles away")
                        .font(RallyType.caption)
                        .foregroundStyle(RallyPalette.inkMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(RallyPalette.ink)
                        .frame(width: 44, height: 44)
                        .background(RallyPalette.creamDeep, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close profile")
            }
        }
    }

    private var aboutSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                eyebrow("About")
                Text(player.bio)
                    .font(RallyType.body(16))
                    .foregroundStyle(RallyPalette.ink)
                    .lineSpacing(3)
                Divider().overlay(RallyPalette.rule)
                keyValue("Age", "\(player.age)")
                keyValue("Gender", player.gender.rawValue)
            }
        }
    }

    private var sportRatingsSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                eyebrow("Sport skill ratings")
                HStack(spacing: 9) {
                    SportIcon(sport: app.activeSport, size: 21)
                    Text(app.activeSport.title)
                        .font(RallyType.body(16, weight: .semibold))
                    Spacer()
                    Text(ratingLabel)
                        .font(RallyType.numeral(18))
                }

                if !otherSports.isEmpty {
                    Divider().overlay(RallyPalette.rule)
                    ForEach(otherSports) { sport in
                        HStack(spacing: 9) {
                            SportIcon(sport: sport, size: 19)
                            Text(sport.title)
                                .font(RallyType.body(15, weight: .semibold))
                            Spacer()
                            Text("\(player.rating(sport))")
                                .font(RallyType.numeral(17))
                        }
                    }
                }
            }
        }
    }

    private var mutualConnectionsSection: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 10) {
                    ConnectionsLineIcon()
                        .stroke(RallyPalette.ink, style: .init(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                        .frame(width: 23, height: 23)
                    Text("\(mutualConnectionCount) connections in common")
                        .font(RallyType.body(15, weight: .semibold))
                }

                HStack(spacing: -9) {
                    ForEach(mutualPlayers) { mutual in
                        RallyPhoto(name: mutual.rallyPhotoName)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(RallyPalette.cream, lineWidth: 2))
                    }
                }
            }
        }
    }

    private var connectButton: some View {
        Button(action: handleConnection) {
            HStack(spacing: 10) {
                ConnectLineIcon()
                    .stroke(connectButtonForeground, style: .init(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .frame(width: 20, height: 20)
                Text(connectButtonTitle)
                    .font(RallyType.action)
            }
            .foregroundStyle(connectButtonForeground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(connectButtonBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var requestActions: some View {
        HStack(spacing: 10) {
            Button("Delete") {
                app.declineFriendRequest(from: player.id)
                dismiss()
            }
            .font(RallyType.action)
            .foregroundStyle(RallyPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RallyPalette.creamDeep, in: Capsule())

            Button("Accept") {
                app.acceptFriendRequest(from: player.id)
                dismiss()
            }
            .font(RallyType.action)
            .foregroundStyle(RallyPalette.cream)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RallyPalette.ink, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var secondaryConnectionButton: some View {
        Button {
            if app.friendshipState(with: player.id) == .incoming {
                app.declineFriendRequest(from: player.id)
                dismiss()
            } else {
                app.toggleBlock(player.id)
                showNotice(isBlocked ? "\(player.name) has been unblocked." : "\(player.name) has been blocked.")
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: app.friendshipState(with: player.id) == .incoming ? "xmark" : "nosign")
                    .font(.system(size: 15, weight: .semibold))
                Text(app.friendshipState(with: player.id) == .incoming ? "Ignore" : (isBlocked ? "Unblock \(player.name)" : "Block \(player.name)"))
                    .font(RallyType.body(15, weight: .semibold))
            }
            .foregroundStyle(app.friendshipState(with: player.id) == .incoming ? RallyPalette.ink : RallyPalette.danger)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .center)
            .overlay(
                Capsule()
                    .stroke(app.friendshipState(with: player.id) == .incoming ? RallyPalette.rule : RallyPalette.danger.opacity(0.42), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var ratingLabel: String {
        guard let profile else { return "Not set" }
        if app.activeSport.category == .group { return "Peer rated" }
        return profile.ratingOptOut ? "Unrated" : "\(profile.rating)"
    }

    private var displayUsername: String {
        let trimmed = player.username.replacingOccurrences(of: "@", with: "")
        return trimmed.isEmpty
            ? player.name.lowercased().replacingOccurrences(of: " ", with: "_")
            : trimmed
    }

    private var formattedOtherSports: String {
        let names = otherSports.map(\.title)
        if names.count == 1 { return names[0] }
        if names.count == 2 { return names.joined(separator: " and ") }
        return names.dropLast().joined(separator: ", ") + ", and " + (names.last ?? "")
    }

    private var mutualConnectionCount: Int {
        guard !mutualPlayers.isEmpty else { return min(5, max(0, app.displayedFriendCount)) }
        return min(5, mutualPlayers.count)
    }

    private var connectButtonTitle: String {
        switch app.friendshipState(with: player.id) {
        case .friends: return "Chat"
        case .outgoing: return "Awaiting their reply"
        case .incoming: return "Accept connection"
        case .none: return "Connect"
        }
    }

    private var connectButtonBackground: Color {
        app.friendshipState(with: player.id) == .outgoing ? RallyPalette.creamDeep : RallyPalette.ink
    }

    private var connectButtonForeground: Color {
        app.friendshipState(with: player.id) == .outgoing ? RallyPalette.inkMuted : RallyPalette.cream
    }

    private func handleConnection() {
        switch app.friendshipState(with: player.id) {
        case .friends:
            app.like(player)
            openChat = true
        case .outgoing:
            if conversation != nil { openChat = true }
        case .incoming:
            app.acceptFriendRequest(from: player.id)
            app.like(player)
            openChat = true
        case .none:
            app.sendFriendRequest(to: player.id)
            app.like(player)
        }
    }

    private func showNotice(_ text: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { notice = text }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut(duration: 0.18)) { notice = nil }
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RallyPalette.creamDeep.opacity(0.38), in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous)
                    .stroke(RallyPalette.rule, lineWidth: 1)
            )
    }

    private func eyebrow(_ title: String) -> some View {
        Text(title.uppercased())
            .font(RallyType.eyebrow)
            .tracking(1.5)
            .foregroundStyle(RallyPalette.inkMuted)
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(RallyPalette.inkMuted)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(RallyPalette.ink)
        }
        .font(RallyType.body(15))
    }
}

private struct MediaLineIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect.insetBy(dx: 2, dy: 3), cornerSize: .init(width: 3, height: 3))
        path.addEllipse(in: CGRect(x: rect.width * 0.61, y: rect.height * 0.24, width: rect.width * 0.14, height: rect.height * 0.14))
        path.move(to: .init(x: rect.width * 0.15, y: rect.height * 0.70))
        path.addLine(to: .init(x: rect.width * 0.40, y: rect.height * 0.47))
        path.addLine(to: .init(x: rect.width * 0.56, y: rect.height * 0.61))
        path.addLine(to: .init(x: rect.width * 0.70, y: rect.height * 0.50))
        path.addLine(to: .init(x: rect.width * 0.85, y: rect.height * 0.67))
        return path
    }
}

private struct ConnectionsLineIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.width * 0.10, y: rect.height * 0.12, width: rect.width * 0.30, height: rect.height * 0.30))
        path.addEllipse(in: CGRect(x: rect.width * 0.58, y: rect.height * 0.12, width: rect.width * 0.30, height: rect.height * 0.30))
        path.move(to: .init(x: rect.width * 0.02, y: rect.height * 0.86))
        path.addQuadCurve(to: .init(x: rect.width * 0.48, y: rect.height * 0.86), control: .init(x: rect.width * 0.25, y: rect.height * 0.40))
        path.move(to: .init(x: rect.width * 0.52, y: rect.height * 0.86))
        path.addQuadCurve(to: .init(x: rect.width * 0.98, y: rect.height * 0.86), control: .init(x: rect.width * 0.75, y: rect.height * 0.40))
        return path
    }
}

private struct ConnectLineIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: .init(x: rect.width * 0.40, y: rect.height * 0.66))
        path.addLine(to: .init(x: rect.width * 0.29, y: rect.height * 0.77))
        path.addQuadCurve(to: .init(x: rect.width * 0.12, y: rect.height * 0.60), control: .init(x: rect.width * 0.17, y: rect.height * 0.78))
        path.addLine(to: .init(x: rect.width * 0.34, y: rect.height * 0.38))
        path.addQuadCurve(to: .init(x: rect.width * 0.51, y: rect.height * 0.55), control: .init(x: rect.width * 0.51, y: rect.height * 0.43))
        path.move(to: .init(x: rect.width * 0.60, y: rect.height * 0.34))
        path.addLine(to: .init(x: rect.width * 0.71, y: rect.height * 0.23))
        path.addQuadCurve(to: .init(x: rect.width * 0.88, y: rect.height * 0.40), control: .init(x: rect.width * 0.83, y: rect.height * 0.22))
        path.addLine(to: .init(x: rect.width * 0.66, y: rect.height * 0.62))
        path.addQuadCurve(to: .init(x: rect.width * 0.49, y: rect.height * 0.45), control: .init(x: rect.width * 0.49, y: rect.height * 0.57))
        return path
    }
}
