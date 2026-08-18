import SwiftUI

/// Inbox presented as a stack of lively conversation stickers.
struct ConversationsView: View {
    @EnvironmentObject var app: AppState
    @State private var showGroupComposer = false
    @State private var section: InboxSection = .inbox
    @State private var friendSearch = ""
    @State private var selectedProfile: Player?

    private var conversations: [Conversation] {
        app.conversations.filter {
            $0.sport == app.activeSport &&
            (section == .requests ? $0.isMessageRequest : !$0.isMessageRequest)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SorbetSectionTitle(title: "Messages", kicker: "Friends & requests", color: app.themeColor)

                    MinimalChoiceBar(
                        options: InboxSection.allCases.map(\.title),
                        selection: Binding(
                            get: { section.title },
                            set: { title in
                                section = InboxSection.allCases.first { $0.title == title } ?? .inbox
                            }
                        )
                    )
                    .accessibilityLabel("Inbox, requests, or friends")

                    if section == .friends {
                        friendsList
                    } else if conversations.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(conversations.enumerated()), id: \.element.id) { index, conversation in
                            if let player = app.player(conversation.partnerId) {
                                NavigationLink {
                                    ChatView(conversationId: conversation.id)
                                } label: {
                                    ConversationSticker(
                                        conversation: conversation,
                                        player: player,
                                        color: [Theme.pink, Theme.blue, Theme.lime, Theme.grape][index % 4],
                                        showProfile: { selectedProfile = player }
                                    )
                                }
                                .buttonStyle(SorbetScaleButtonStyle())
                            }
                        }
                    }
                }
                .padding(18)
                .padding(.bottom, 12)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SportModeToggle() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showGroupComposer = true
                    } label: {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.bg)
                            .frame(width: 34, height: 34)
                            .background(app.themeColor, in: RoundedRectangle(cornerRadius: 11))
                    }
                    .accessibilityLabel("Create group chat")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sorbetScreen()
            .sheet(isPresented: $showGroupComposer) {
                GroupChatComposer()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(Theme.bg)
            }
            .sheet(item: $selectedProfile) { player in
                ProfileDetailView(player: player)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
            }
        }
    }

    private var friendsList: some View {
        VStack(spacing: 12) {
            TextField("Search friends", text: $friendSearch)
                .font(Theme.ui(14))
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))

            ForEach(app.players.filter {
                app.friendIds.contains($0.id) &&
                (friendSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(friendSearch))
            }) { player in
                NavigationLink {
                    FriendChatDestination(playerId: player.id)
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(avatar: player.avatar, size: 50)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(player.name).font(Theme.heading(16))
                            Text("\(player.distanceMiles, specifier: "%.1f") mi · \(player.city)")
                                .font(Theme.ui(11))
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        Image(systemName: "bubble.left.fill")
                            .foregroundStyle(Theme.bg)
                            .frame(width: 38, height: 38)
                            .background(app.themeColor, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .foregroundStyle(Theme.ink)
                    .card(padding: 13)
                }
                .buttonStyle(SorbetScaleButtonStyle())
            }

            if !app.incomingFriendRequestIds.isEmpty {
                Text("FRIEND REQUESTS")
                    .font(Theme.ui(10, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(app.players.filter { app.incomingFriendRequestIds.contains($0.id) }) { player in
                    HStack(spacing: 10) {
                        AvatarView(avatar: player.avatar, size: 42)
                        Text(player.name).font(Theme.ui(13, weight: .bold))
                        Spacer()
                        CompactActionButton(title: "Decline") {
                            app.declineFriendRequest(from: player.id)
                        }
                        CompactActionButton(title: "Accept", primary: true) {
                            app.acceptFriendRequest(from: player.id)
                        }
                    }
                    .padding(12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            AppNavigationIcon(item: .chat, size: 44, color: Theme.ink)
                .frame(width: 70, height: 70)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.hairline, lineWidth: 1))
            Text("Quiet in here")
                .font(Theme.heading(22))
            Text(section == .requests
                 ? "Messages and challenges from people outside your friends list appear here."
                 : "Open Friends or meet someone nearby to start a conversation.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .card()
    }
}

private enum InboxSection: String, CaseIterable, Identifiable {
    case inbox, requests, friends
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private struct FriendChatDestination: View {
    let playerId: UUID
    @EnvironmentObject private var app: AppState

    var body: some View {
        Group {
            if let conversation = app.conversation(with: playerId) {
                ChatView(conversationId: conversation.id)
            } else {
                ProgressView("Opening chat…")
                    .task { app.like(app.player(playerId)!) }
            }
        }
    }
}

private struct ConversationSticker: View {
    let conversation: Conversation
    let player: Player
    let color: Color
    let showProfile: () -> Void
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack(spacing: 13) {
            AvatarView(avatar: player.avatar, size: 56)
                .contentShape(Circle())
                .onTapGesture(perform: showProfile)
                .accessibilityAction(named: "Open profile", showProfile)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(conversation.groupName ?? player.name)
                        .font(Theme.heading(17))
                        .foregroundStyle(Theme.ink)
                    if conversation.isBlocked {
                        Tag(text: "Blocked", systemImage: "hand.raised.fill", color: Theme.pink)
                    }
                }

                Text(preview)
                    .font(Theme.ui(13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 4)

            VStack(spacing: 8) {
                if let profile = player.profile(app.activeSport), profile.usesElo {
                    RatingBadge(rating: profile.rating, sport: app.activeSport)
                } else if app.activeSport.category == .group {
                    Image(systemName: "star.fill").foregroundStyle(app.themeColor)
                } else {
                    Text(player.profile(app.activeSport)?.socialSkillLabel?.rawValue ?? "Social")
                        .font(Theme.ui(9, weight: .bold)).foregroundStyle(app.themeColor)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.ink.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity)
        .card(padding: 14)
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(color == Theme.faint ? Theme.hairline : color)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                .offset(x: -12, y: 12)
        }
    }

    private var preview: String {
        guard let last = conversation.lastMessage else { return "" }
        switch last.kind {
        case .text(let text): return (last.fromMe ? "You: " : "") + text
        case .challenge(let challenge): return "🏁 Challenge · \(challenge.wager)"
        case .faceOff: return "📅 Face-off scheduled"
        case .image: return "📷 Photo"
        case .location(let location): return "📍 \(location)"
        case .system(let text): return text
        }
    }
}

struct GroupChatComposer: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selected: Set<UUID> = []

    private var candidates: [Player] {
        app.players.filter { app.friendIds.contains($0.id) && $0.profile(app.activeSport) != nil }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RallyPalette.cream.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Build a court crew")
                        .font(RallyType.hero)
                        .rallyDisplayLeading()
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Choose at least two players. The chat will automatically look for your next shared opening.")
                        .font(RallyType.body())
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.trailing, 48)

                TextField("Group name", text: $name)
                    .font(RallyType.body())
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(Theme.surface2, in: Capsule())

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(candidates) { player in
                            Button {
                                if selected.contains(player.id) {
                                    selected.remove(player.id)
                                } else {
                                    selected.insert(player.id)
                                }
                            } label: {
                                HStack(spacing: 11) {
                                    RallyPlayerAvatar(player: player, size: 52)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(player.name)
                                            .font(RallyType.action)
                                        Text("\(player.rating(app.activeSport)) rating · \(player.distanceMiles, specifier: "%.1f") mi")
                                            .font(RallyType.caption)
                                            .foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(selected.contains(player.id) ? RallyPalette.sun : .clear)
                                        Circle()
                                            .stroke(RallyPalette.ink.opacity(selected.contains(player.id) ? 1 : 0.45), lineWidth: 2)
                                        if selected.contains(player.id) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(RallyPalette.ink)
                                        }
                                    }
                                    .frame(width: 28, height: 28)
                                }
                                .foregroundStyle(Theme.ink)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(RallyPressStyle())
                            .accessibilityAddTraits(selected.contains(player.id) ? .isSelected : [])
                        }
                    }
                }

                Button {
                    _ = app.createGroupConversation(name: name, participantIds: Array(selected))
                    dismiss()
                } label: {
                    HStack {
                        Text("Create group")
                        Spacer()
                        Text("\(selected.count) players")
                        Image(systemName: "arrow.right")
                    }
                    .font(RallyType.action)
                    .foregroundStyle(selected.count >= 2 ? Theme.bg : Theme.ink.opacity(0.48))
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(selected.count >= 2 ? Theme.ink : Theme.surface2, in: Capsule())
                }
                .buttonStyle(RallyPressStyle())
                .disabled(selected.count < 2)
            }
            .padding(.horizontal, RallyLayout.gutter)
            .padding(.top, 30)
            .padding(.bottom, 20)
            .background(Theme.bg)

            CloseIconButton { dismiss() }
                .padding(.top, 24)
                .padding(.trailing, RallyLayout.gutter)
        }
        .preferredColorScheme(.light)
    }
}
