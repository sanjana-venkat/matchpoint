import SwiftUI

/// Five-part product flow with a persistent creation launcher.
struct MainTabView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedTab: Int
    @State private var showLogGame = false
    @State private var showChallenge = false
    @State private var fabExpanded = false
    private let initialTab: Int

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-demo-tab"),
           arguments.indices.contains(flag + 1),
           let tab = Int(arguments[flag + 1]) {
            let safeTab = min(4, max(0, tab))
            initialTab = safeTab
            _selectedTab = State(initialValue: safeTab)
        } else {
            initialTab = 0
            _selectedTab = State(initialValue: 0)
        }
#else
        initialTab = 0
        _selectedTab = State(initialValue: 0)
#endif
    }

    var body: some View {
        Group {
            switch selectedTab {
            case 1: PlayersMapView()
            case 2: MatchesView(selectedMainTab: $selectedTab)
            case 3: ConversationsView()
            case 4: ProfileView()
            default: HomeView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { customTabBar }
        .onAppear {
            selectedTab = initialTab
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demo-log-game") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { showLogGame = true }
            }
#endif
        }
        .overlay(alignment: .bottomTrailing) {
            fab
        }
        .sheet(isPresented: $showLogGame) {
            LogGameSheet {
                showLogGame = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Theme.bg)
        }
        .sheet(isPresented: $showChallenge) {
            QuickChallengeSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 2) {
            tabButton(1, title: "Map", item: .map)
            tabButton(2, title: "Matches", item: .matches)
            tabButton(0, title: "Home", item: .home)
            tabButton(3, title: "Chats", item: .chat)
            tabButton(4, title: "Profile", item: .profile)
        }
        .padding(.horizontal, 8)
        .frame(height: 82)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(Color.white.opacity(0.8), lineWidth: 1))
        .shadow(color: Color(hex: "141A2C").opacity(0.13), radius: 24, y: 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private func tabButton(_ index: Int, title: String, item: AppNavigationItem) -> some View {
        let isSelected = selectedTab == index
        return Button { selectedTab = index } label: {
            VStack(spacing: 3) {
                AppNavigationIcon(item: item, size: isSelected ? 24 : 21, color: isSelected ? .white : Color(hex: "A9B0BF"))
                    .frame(width: isSelected ? 54 : 34, height: isSelected ? 54 : 34)
                    .background(isSelected ? app.themeColor.opacity(0.96) : Color.clear, in: Circle())
                    .shadow(color: isSelected ? app.themeColor.opacity(0.22) : .clear, radius: 10, y: 4)
                Text(title).font(Theme.ui(10.5, weight: isSelected ? .bold : .semibold))
            }
            .foregroundStyle(isSelected ? app.themeColor : Color(hex: "A9B0BF"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: isSelected ? -13 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fab: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if fabExpanded {
                fabOption("Add a challenge", icon: "plus") {
                    fabExpanded = false
                    showChallenge = true
                }
                fabOption("Upload scores", icon: "square.and.arrow.up") {
                    fabExpanded = false
                    showLogGame = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { fabExpanded.toggle() }
            } label: {
                Image(systemName: fabExpanded ? "xmark" : "plus")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color(hex: "14161C"), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .shadow(color: Color.black.opacity(0.22), radius: 18, y: 8)
            }
            .buttonStyle(SorbetScaleButtonStyle())
            .accessibilityLabel(fabExpanded ? "Close actions" : "Open quick actions")
        }
        .padding(.trailing, DesignSystem.Metrics.screenPadding)
        .padding(.bottom, 96)
    }

    private func fabOption(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Theme.ui(12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .frame(height: 44)
                .background(Color(hex: "14161C"), in: Capsule())
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 5)
        }
        .buttonStyle(SorbetScaleButtonStyle())
    }
}

/// Tap once to advance to the next sport. This intentionally mirrors the
/// compact switcher from the baseline branch.
struct SportModeToggle: View {
    @EnvironmentObject var app: AppState
    @State private var pendingSport: Sport?
    @State private var showExitWarning = false

    var body: some View {
        Group {
            if app.hasMultipleSports {
                Button { selectNextSport() } label: {
                    HStack(spacing: 6) {
                        SportIcon(sport: app.activeSport, size: 27)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 11)
                    .frame(height: 44)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
                    .shadow(color: Color(hex: "141A2C").opacity(0.08), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Switch sport. Current sport \(app.activeSport.title)")
            } else {
                HStack(spacing: 7) {
                    SportIcon(sport: app.activeSport, size: 20)
                    Text(app.activeSport.title).font(Theme.ui(16, weight: .bold))
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.faint, in: RoundedRectangle(cornerRadius: 13))
            }
        }
        .alert("Discard unsaved changes?", isPresented: $showExitWarning) {
            Button("Keep editing", role: .cancel) { pendingSport = nil }
            Button("Discard and switch", role: .destructive) {
                app.hasUnsavedDraft = false
                if let pendingSport { select(pendingSport) }
                pendingSport = nil
            }
        } message: {
            Text("Your unfinished challenge, score upload, or form changes will be lost if you switch sports.")
        }
    }

    private func select(_ sport: Sport) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
            app.activeSport = sport
            app.resetDeck()
        }
    }

    private func selectNextSport() {
        guard let index = app.mySports.firstIndex(of: app.activeSport), !app.mySports.isEmpty else { return }
        let nextSport = app.mySports[(index + 1) % app.mySports.count]
        if app.hasUnsavedDraft {
            pendingSport = nextSport
            showExitWarning = true
        } else {
            select(nextSport)
        }
    }
}

private struct QuickChallengeSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlayerId: UUID?
    @State private var note = ""
    @State private var wager = "No wager"

    private var candidates: [Player] { app.players.filter { $0.profile(app.activeSport) != nil } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                MatchPointLogo()
                Text("Add a challenge").font(Theme.heading(29))
                Text("Choose a player, add the format, and send the invitation in one step.")
                    .font(Theme.ui(13)).foregroundStyle(Theme.muted)
                Picker("Player", selection: $selectedPlayerId) {
                    Text("Select a player").tag(UUID?.none)
                    ForEach(candidates) { Text($0.name).tag(Optional($0.id)) }
                }
                .pickerStyle(.menu)
                .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                TextField("Challenge details", text: $note, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                TextField("Wager or “No wager”", text: $wager)
                    .padding(14).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                Spacer()
                BottomCTA(title: "Send challenge", enabled: selectedPlayerId != nil) {
                    guard let selectedPlayerId else { return }
                    app.send(.challenge(Challenge(wager: wager, note: note)), to: selectedPlayerId)
                    app.hasUnsavedDraft = false
                    dismiss()
                }
            }
            .padding(20)
            .background(Theme.bg)
            .onChange(of: note) { _, _ in app.hasUnsavedDraft = true }
            .onChange(of: selectedPlayerId) { _, _ in app.hasUnsavedDraft = true }
            .onDisappear { app.hasUnsavedDraft = false }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { CloseIconButton { dismiss() } } }
        }
    }
}
