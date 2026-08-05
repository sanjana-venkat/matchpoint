import SwiftUI

/// Dating-app style swipe deck. Swipe right / tap ♥ to start a conversation,
/// swipe left / tap ✕ to pass. Tap a card for the full profile.
struct DiscoverView: View {
    @EnvironmentObject var app: AppState
    @State private var showFilters = false
    @State private var detailPlayer: Player?
    @State private var dragOffset: CGSize = .zero
    @State private var matchToast: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                if app.discoverDeck.isEmpty {
                    emptyState
                } else {
                    deck
                }

                if let matchToast {
                    toast(matchToast)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { SportModeToggle() }
                ToolbarItem(placement: .topBarTrailing) {
                    StickerIconButton(
                        systemImage: app.filters.isActive
                            ? "line.3.horizontal.decrease"
                            : "slider.horizontal.3",
                        color: app.filters.isActive ? Theme.pink : Theme.surface,
                        size: 42
                    ) { showFilters = true }
                }
            }
            .sheet(isPresented: $showFilters) { FiltersView() }
            .sheet(item: $detailPlayer) { player in
                ProfileDetailView(player: player)
            }
            .sorbetScreen()
        }
    }

    // MARK: Deck

    private var deck: some View {
        VStack {
            ZStack {
                ForEach(Array(app.discoverDeck.prefix(3).enumerated()).reversed(), id: \.element.id) { index, player in
                    ProfileCardView(player: player, sport: app.activeSport)
                        .offset(index == 0 ? dragOffset : .zero)
                        .rotationEffect(.degrees(index == 0 ? Double(dragOffset.width / 18) : 0))
                        .scaleEffect(index == 0 ? 1 : 1 - CGFloat(index) * 0.04)
                        .offset(y: CGFloat(index) * 10)
                        .overlay(alignment: .top) {
                            if index == 0 { swipeStamp }
                        }
                        .gesture(index == 0 ? dragGesture(for: player) : nil)
                        .onTapGesture { if index == 0 { detailPlayer = player } }
                        .animation(.spring(response: 0.35), value: dragOffset)
                        .allowsHitTesting(index == 0)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)

            actionButtons
                .padding(.top, 8)
        }
    }

    private var swipeStamp: some View {
        HStack {
            stamp("PLAY", Theme.lime, opacity: Double(max(0, dragOffset.width) / 120))
                .rotationEffect(.degrees(-18))
            Spacer()
            stamp("PASS", Theme.pink, opacity: Double(max(0, -dragOffset.width) / 120))
                .rotationEffect(.degrees(18))
        }
        .padding(28)
    }

    private func stamp(_ text: String, _ color: Color, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .black, design: .rounded))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color, in: Capsule())
            .overlay(Capsule().stroke(Theme.ink, lineWidth: 4))
            .opacity(min(1, opacity))
    }

    private var actionButtons: some View {
        HStack(spacing: 34) {
            circleButton("xmark", Theme.pink) {
                if let p = app.discoverDeck.first { swipe(p, like: false) }
            }
            circleButton("bubble.left.fill", Theme.blue, small: true) {
                if let p = app.discoverDeck.first { detailPlayer = p }
            }
            circleButton("heart.fill", Theme.lime) {
                if let p = app.discoverDeck.first { swipe(p, like: true) }
            }
        }
        .padding(.bottom, 8)
    }

    private func circleButton(_ icon: String, _ color: Color, small: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.ink).offset(x: 4, y: 5)
                Circle().fill(Theme.surface)
                Circle().stroke(Theme.ink, lineWidth: 3)
                Circle().fill(color.opacity(0.18)).padding(7)
                Image(systemName: icon)
                    .font(.system(size: small ? 19 : 25, weight: .black))
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: small ? 54 : 66, height: small ? 54 : 66)
        }
        .buttonStyle(SorbetScaleButtonStyle())
    }

    // MARK: Gestures / actions

    private func dragGesture(for player: Player) -> some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                if abs(value.translation.width) > 120 {
                    swipe(player, like: value.translation.width > 0)
                } else {
                    withAnimation(.spring()) { dragOffset = .zero }
                }
            }
    }

    private func swipe(_ player: Player, like: Bool) {
        withAnimation(.spring(response: 0.3)) {
            dragOffset = CGSize(width: like ? 600 : -600, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if like {
                app.like(player)
                showToast("You liked \(player.name.components(separatedBy: " ").first ?? player.name)! Say hi in Messages 💬")
            } else {
                app.pass(player)
            }
            dragOffset = .zero
        }
    }

    private func showToast(_ text: String) {
        withAnimation { matchToast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { matchToast = nil }
        }
    }

    private func toast(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .padding()
                .background(Theme.lime, in: Capsule())
                .overlay(Capsule().stroke(Theme.ink, lineWidth: 2.5))
                .padding(.bottom, 90)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 56)).foregroundStyle(Theme.grape)
            Text("You're all caught up")
                .font(.system(size: 25, weight: .black, design: .rounded))
            Text("No more \(app.activeSport.title.lowercased()) players match your filters right now.")
                .multilineTextAlignment(.center).foregroundStyle(Theme.muted)
            Button("Reset deck") { withAnimation { app.resetDeck() } }
                .buttonStyle(.borderedProminent)
                .tint(Theme.grape)
            if app.filters.isActive {
                Button("Clear filters") { app.filters.reset() }
                    .font(.footnote)
            }
        }
        .padding(40)
        .card()
        .padding(24)
    }
}
