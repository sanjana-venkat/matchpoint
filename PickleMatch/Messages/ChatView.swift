import SwiftUI

/// One-to-one chat with attachments, challenge/face-off actions, and
/// block/report — the "dating app amenities."
struct ChatView: View {
    let conversationId: UUID
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @State private var showChallenge = false
    @State private var showFaceOff = false
    @State private var showReport: FaceOff?
    @State private var showReportSheet = false
    @State private var reportAlert = false
    @State private var showAvailability = false
    @State private var showWagerAgreement = false
    @State private var selectedAvailability: AvailabilitySlot?
    @State private var showEditChallenges = false
    @State private var showMatchHistory = false
    @State private var showChatMenu = false
    @State private var showAttachmentMenu = false
    @State private var showPlayerProfile = false

    private var convo: Conversation? { app.conversations.first { $0.id == conversationId } }
    private var player: Player? { convo.flatMap { app.player($0.partnerId) } }
    private var participantIds: [UUID] {
        convo.map(app.participantIds(for:)) ?? []
    }
    private var alignedAvailabilities: [AvailabilitySlot] {
        app.alignedAvailabilities(with: participantIds, limit: 4)
    }
    private var chatTitle: String {
        convo?.groupName ?? player?.name ?? "Chat"
    }

    var body: some View {
        VStack(spacing: 0) {
            if convo?.isMessageRequest == true { messageRequestBanner }
            if let fo = activeChallenge { faceOffBanner(fo) }
            if showChatMenu { chatMenuPanel }

            MatchingAvailabilityStrip(slots: alignedAvailabilities) { slot in
                if let slot {
                    selectedAvailability = slot
                } else {
                    showAvailability = true
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            wagerAgreementCard
                .padding(.horizontal, 14)
                .padding(.top, 8)

            Button { showMatchHistory = true } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("View match history")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(Theme.ui(12, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .frame(height: 44)
            }
            .buttonStyle(.plain)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(convo?.messages ?? []) { msg in
                            MessageBubble(message: msg, player: player, sport: convo?.sport ?? app.activeSport)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: convo?.messages.count ?? 0) { _, _ in
                    if let last = convo?.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if convo?.isBlocked == true {
                blockedBar
            } else {
                inputBar
            }
        }
        .background(Theme.bg)
        .foregroundStyle(Theme.ink)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 38, height: 38)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .principal) {
                Button { showPlayerProfile = true } label: {
                    HStack(spacing: 8) {
                        if let player { AvatarView(avatar: player.avatar, size: 32) }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(chatTitle).font(Theme.ui(13, weight: .bold))
                            Text("View profile").font(Theme.ui(9)).foregroundStyle(Theme.muted)
                        }
                    }
                    .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .topBarTrailing) { menu }
        }
        .sheet(isPresented: $showPlayerProfile) {
            if let player {
                ProfileDetailView(player: player)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
            }
        }
        .sheet(isPresented: $showChallenge) {
            if let player { ChallengeComposerView(player: player) }
        }
        .sheet(isPresented: $showFaceOff) {
            if let player { FaceOffComposerView(player: player) }
        }
        .sheet(isPresented: $showReportSheet) {
            if let fo = showReport { ReportResultView(faceOff: fo) }
        }
        .sheet(isPresented: $showAvailability) {
            AvailabilityCoordinationSheet(participantIds: participantIds)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
        .sheet(isPresented: $showWagerAgreement) {
            WagerAgreementSheet(
                conversationId: conversationId,
                playerName: player?.name ?? "the other player",
                currentProposal: convo?.wagerProposal
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.bg)
        }
        .sheet(item: $selectedAvailability) { slot in
            MatchTimeProposalSheet(
                participantIds: participantIds,
                slot: slot,
                playerName: player?.name ?? "your match"
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.bg)
        }
        .sheet(isPresented: $showEditChallenges) {
            if let player { EditChallengesSheet(player: player) }
        }
        .sheet(isPresented: $showMatchHistory) {
            if let player { HeadToHeadHistoryView(player: player) }
        }
        .alert("Report submitted", isPresented: $reportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Thanks — our team will review this conversation. You can also block this player.")
        }
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demo-availability") {
                showAvailability = true
            } else if ProcessInfo.processInfo.arguments.contains("-demo-wager") {
                showWagerAgreement = true
            } else if ProcessInfo.processInfo.arguments.contains("-demo-time-confirm") {
                selectedAvailability = alignedAvailabilities.first
            }
#endif
        }
    }

    private var messageRequestBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("MESSAGE REQUEST", systemImage: "tray.full.fill")
                .font(Theme.ui(10, weight: .bold))
                .tracking(1)
                .foregroundStyle(app.themeColor)
            Text("Accept this request to move the conversation into your friends inbox.")
                .font(Theme.ui(12))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                CompactActionButton(title: "Decline") {
                    if let id = convo?.id, let index = app.conversations.firstIndex(where: { $0.id == id }) {
                        app.conversations.remove(at: index)
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
                CompactActionButton(title: "Accept", primary: true) {
                    app.acceptMessageRequest(conversationId)
                }
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(app.themeColor).frame(height: 2) }
    }

    @ViewBuilder
    private var wagerAgreementCard: some View {
        let proposal = convo?.wagerProposal
        HStack(spacing: 11) {
            Image(systemName: proposal?.state == .agreed ? "checkmark.seal.fill" : "gift")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(proposal?.state == .agreed ? Theme.bg : Theme.blue)
                .frame(width: 38, height: 38)
                .background(
                    proposal?.state == .agreed ? app.themeColor : Theme.blue.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(wagerStatusTitle(proposal))
                    .font(Theme.ui(10, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.7)
                    .foregroundStyle(Theme.ink)
                Text(proposal?.value ?? "Agree together, or play without one")
                    .font(Theme.ui(11))
                    .foregroundStyle(Theme.ink.opacity(0.76))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if proposal?.state == .proposedByThem {
                Button("Accept") { app.acceptWager(in: conversationId) }
                    .font(Theme.ui(10, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(app.themeColor, in: RoundedRectangle(cornerRadius: 14))
            } else {
                Button(proposal == nil ? "Decide" : "Edit") {
                    showWagerAgreement = true
                }
                .font(Theme.ui(10, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 56, minHeight: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func wagerStatusTitle(_ proposal: WagerProposal?) -> String {
        guard let proposal else { return "Wager not decided" }
        switch proposal.state {
        case .proposedByMe:
            return "Waiting for \(player?.name.split(separator: " ").first.map(String.init) ?? "them")"
        case .proposedByThem:
            return "\(player?.name.split(separator: " ").first.map(String.init) ?? "They") proposed"
        case .agreed: return "Wager agreed"
        case .noWager: return "Playing without a wager"
        }
    }

    // MARK: Face-off banner (report result / confirm)

    private var activeChallenge: FaceOff? {
        guard let pid = player?.id else { return nil }
        return app.activeChallenges(with: pid).first
    }

    private func faceOffBanner(_ fo: FaceOff) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "flag.checkered")
                VStack(alignment: .leading) {
                    Text("Face-off · \(fo.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline.weight(.semibold))
                    Text(fo.venue).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            switch fo.state {
            case .proposed:
                if fo.proposedByMe {
                    Label("Waiting for confirmation", systemImage: "paperplane.fill")
                        .font(Theme.ui(11, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.82))
                } else {
                    HStack {
                        CompactActionButton(title: "Decline") { app.declineChallenge(fo.id) }
                        CompactActionButton(title: "Accept challenge", primary: true) { app.acceptChallenge(fo.id) }
                    }
                }
            case .confirmed:
                if fo.date <= .now {
                    Button {
                        showReport = fo; showReportSheet = true
                    } label: {
                        Label("Report result", systemImage: "checkmark.circle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(app.themeColor)
                    .foregroundStyle(Theme.bg)
                    .controlSize(.small)
                } else {
                    Label(
                        "Scheduled for \(fo.date.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "clock.badge.checkmark"
                    )
                    .font(Theme.ui(11, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .awaitingResult:
                if fo.reportedWinnerByThem != nil && fo.reportedWinnerByMe == nil {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Verify the submitted scores", systemImage: "checkmark.shield.fill")
                            .font(Theme.ui(11, weight: .bold))
                        HStack {
                            CompactActionButton(title: "Dispute") {
                                app.verifyIncomingResult(faceOffId: fo.id, agrees: false)
                            }
                            CompactActionButton(title: "Scores are correct", primary: true) {
                                app.verifyIncomingResult(faceOffId: fo.id, agrees: true)
                            }
                        }
                    }
                } else {
                    Label("Waiting for \(fo.opponentName) to confirm the result…", systemImage: "hourglass")
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .resultDisputed:
                Label("Results didn't match. Re-report to settle.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            default: EmptyView()
            }

            HStack(spacing: 20) {
                Button("+ Add another challenge") { showChallenge = true }
                Button("✏️ Edit challenges") { showEditChallenges = true }
            }
            .font(Theme.ui(10, weight: .bold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(app.themeColor.opacity(0.24))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.ink).frame(height: 2.5)
        }
    }

    // MARK: Menu

    private var menu: some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { showChatMenu.toggle() } } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 38, height: 38)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var chatMenuPanel: some View {
        HStack(spacing: 8) {
            appMenuButton("Challenge", icon: "flag.checkered") { showChallenge = true }
            appMenuButton(convo?.isBlocked == true ? "Unblock" : "Block", icon: "hand.raised") {
                if let pid = player?.id { app.toggleBlock(pid) }
            }
            appMenuButton("Report", icon: "exclamationmark.bubble") { reportAlert = true }
        }
        .padding(10)
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    // MARK: Input bar

    private var inputBar: some View {
        VStack(spacing: 8) {
            if showAttachmentMenu {
                HStack(spacing: 8) {
                    appMenuButton("Photo", icon: "photo") { send(.image) }
                    appMenuButton("Location", icon: "mappin.and.ellipse") { send(.location("Zilker Park Courts")) }
                    appMenuButton("Challenge", icon: "flag.checkered") { showChallenge = true }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 10) {
            Button { withAnimation(.easeOut(duration: 0.15)) { showAttachmentMenu.toggle() } } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(app.themeColor, in: RoundedRectangle(cornerRadius: 14))
                    .rotationEffect(.degrees(showAttachmentMenu ? 45 : 0))
            }
            .buttonStyle(.plain)

            TextField(
                "",
                text: $draft,
                prompt: Text("Message…").foregroundStyle(Theme.muted),
                axis: .vertical
            )
                .padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(Theme.ink)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))

            Button {
                let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                send(.text(text)); draft = ""
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Theme.ink.opacity(draft.isEmpty ? 0.35 : 1))
                    .frame(width: 44, height: 44)
                    .background(draft.isEmpty ? Theme.ink.opacity(0.08) : app.themeColor, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(Circle().stroke(Theme.ink.opacity(draft.isEmpty ? 0.18 : 1), lineWidth: 2.5))
            }
            .buttonStyle(SorbetScaleButtonStyle())
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(Theme.surface)
        .overlay(alignment: .top) { Rectangle().fill(Theme.ink.opacity(0.15)).frame(height: 1) }
    }

    private func appMenuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            showChatMenu = false
            showAttachmentMenu = false
        } label: {
            Label(title, systemImage: icon)
                .font(Theme.ui(11, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Theme.faint, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var blockedBar: some View {
        HStack {
            Image(systemName: "hand.raised.fill")
            Text("You've blocked this player.")
            Spacer()
            Button("Unblock") { if let pid = player?.id { app.toggleBlock(pid) } }
        }
        .font(.subheadline)
        .padding()
        .background(Theme.pink.opacity(0.22))
    }

    private func send(_ kind: MessageKind) {
        guard let pid = player?.id else { return }
        app.send(kind, to: pid)
    }
}

private struct HeadToHeadHistoryView: View {
    let player: Player
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSport: Sport?

    private var records: [MatchRecord] { app.headToHead(with: player, sport: selectedSport) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Head-to-head")
                        .font(Theme.heading(29))
                    Text("Every verified match with \(player.name), across every sport you share.")
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.muted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            historyFilter("All sports", sport: nil)
                            ForEach(Sport.allCases.filter { player.profile($0) != nil }) { sport in
                                historyFilter(sport.title, sport: sport)
                            }
                        }
                    }

                    if records.isEmpty {
                        ContentUnavailableView(
                            "No verified matches",
                            systemImage: "sportscourt",
                            description: Text("Completed and confirmed results will appear here.")
                        )
                        .foregroundStyle(Theme.muted)
                    } else {
                        ForEach(records) { record in
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    HStack(spacing: 6) {
                                        SportIcon(sport: record.sport, size: 22)
                                        Text(record.sport.title).font(Theme.ui(12, weight: .bold))
                                    }
                                    Spacer()
                                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(Theme.ui(10))
                                        .foregroundStyle(Theme.muted)
                                }
                                HStack {
                                    Text(record.didWin ? "WIN" : "LOSS")
                                        .font(Theme.ui(11, weight: .bold))
                                        .foregroundStyle(record.didWin ? Theme.color(for: record.sport) : Theme.neonRed)
                                    Spacer()
                                    Text(record.gameScores.isEmpty
                                         ? "Result verified"
                                         : record.gameScores.map { "\($0.myScore)–\($0.opponentScore)" }.joined(separator: " · "))
                                        .font(Theme.ui(12, weight: .bold).monospacedDigit())
                                }
                                Label(record.venue, systemImage: "mappin.and.ellipse")
                                    .font(Theme.ui(11))
                                    .foregroundStyle(Theme.muted)
                            }
                            .padding(15)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 1))
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.bg)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func historyFilter(_ title: String, sport: Sport?) -> some View {
        Button { selectedSport = sport } label: {
            Text(title)
                .font(Theme.ui(11, weight: .bold))
                .foregroundStyle(selectedSport == sport ? Theme.bg : Theme.ink)
                .padding(.horizontal, 13)
                .frame(height: 38)
                .background(
                    selectedSport == sport ? (sport.map(Theme.color(for:)) ?? Theme.neonGreen) : Theme.surface,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

private struct WagerAgreementSheet: View {
    let conversationId: UUID
    let playerName: String
    let currentProposal: WagerProposal?
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selection = "bragging rights 🏆"
    @State private var custom = ""

    private var proposedValue: String {
        custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selection : custom
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Decide together")
                            .font(Theme.heading(26))
                        Text("This sends a proposal to \(playerName). It only appears in the match after they accept.")
                            .font(Theme.ui(13))
                            .foregroundStyle(Theme.ink.opacity(0.76))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 9) {
                        ForEach(WagerHint.all, id: \.self) { hint in
                            Button {
                                selection = hint
                                custom = ""
                            } label: {
                                HStack {
                                    Text(hint)
                                        .font(Theme.ui(13, weight: .bold))
                                    Spacer()
                                    Image(systemName: selection == hint && custom.isEmpty ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selection == hint && custom.isEmpty ? Theme.accent : Theme.muted)
                                }
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 15)
                                .frame(minHeight: 48)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selection == hint && custom.isEmpty ? Theme.accent : Theme.hairline, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selection == hint && custom.isEmpty ? .isSelected : [])
                        }
                    }

                    TextField("Or suggest something else", text: $custom)
                        .font(Theme.ui(14))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 50)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.hairline, lineWidth: 1))
                        .accessibilityLabel("Custom proposed wager")

                    Button {
                        app.proposeWager(proposedValue, in: conversationId)
                        dismiss()
                    } label: {
                        HStack {
                            Text("Propose to \(playerName.split(separator: " ").first.map(String.init) ?? playerName)")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(Theme.ui(15, weight: .bold))
                        .foregroundStyle(Theme.bg)
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .background(Theme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button("Play without a wager") {
                        app.chooseNoWager(in: conversationId)
                        dismiss()
                    }
                    .font(Theme.ui(13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Wager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseIconButton { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let currentProposal, currentProposal.state != .noWager {
                if WagerHint.all.contains(currentProposal.value) {
                    selection = currentProposal.value
                } else {
                    custom = currentProposal.value
                }
            }
        }
    }
}
