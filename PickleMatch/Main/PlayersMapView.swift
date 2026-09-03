import SwiftUI
import MapKit
import Combine

/// Zoomable live-player map with gender/rating chips and profile bottom sheets.
struct PlayersMapView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var location: LocationService

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431),
            span: MKCoordinateSpan(latitudeDelta: 0.20, longitudeDelta: 0.20)
        )
    )
    @State private var genderFilter: Gender?
    @State private var ratingFilter: MapRatingFilter = .all
    @State private var radiusMiles = 8
    @State private var selectedPlayer: Player?
    @State private var chatConversationId: UUID?
    @State private var openFilter: MapFilterPanel?
    @State private var challengePlayer: Player?

    private var center: CLLocationCoordinate2D {
        location.location?.coordinate ?? CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431)
    }

    private var visiblePlayers: [Player] {
        app.players.filter { player in
            guard genderFilter == nil || player.gender == genderFilter else { return false }
            if app.activeSport.category == .individual {
                let profile = player.profile(app.activeSport)
                if ratingFilter == .unrated {
                    guard profile == nil || profile?.usesElo == false else { return false }
                } else {
                    guard let profile, profile.usesElo else { return false }
                    guard ratingFilter.range.contains(profile.rating) else { return false }
                }
            } else {
                guard player.profile(app.activeSport) != nil else { return false }
            }
            return player.distanceMiles <= Double(radiusMiles) * 1.6
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition, interactionModes: .all) {
                    if location.location != nil {
                    Annotation("You", coordinate: center, anchor: .center) {
                        ZStack {
                            Circle().fill(Theme.signal.opacity(0.22)).frame(width: 38, height: 38)
                            Circle().fill(Theme.signal).frame(width: 22, height: 22)
                            Circle().stroke(Theme.bg, lineWidth: 3).frame(width: 22, height: 22)
                            Image(systemName: "location.fill")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Theme.bg)
                        }
                    }
                    }

                    ForEach(visiblePlayers) { player in
                        Annotation(
                            player.name,
                            coordinate: coordinate(for: player),
                            anchor: .bottom
                        ) {
                            PlayerMapPin(
                                player: player,
                                sport: app.activeSport,
                                isSelected: selectedPlayer?.id == player.id,
                                friendshipState: app.friendshipState(with: player.id)
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedPlayer = selectedPlayer?.id == player.id ? nil : player
                                }
                            } addFriend: {
                                app.sendFriendRequest(to: player.id)
                            } createChallenge: {
                                challengePlayer = player
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                .environment(\.colorScheme, .light)
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    let estimated = Int((context.region.span.latitudeDelta * 69) / 2)
                    radiusMiles = min(50, max(1, estimated))
                }
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 12) {
                    mapHeader
                    Spacer()

                    HStack {
                        Spacer()
                        Button {
                            if location.location == nil {
                                location.requestWhenInUseAccess()
                            }
                            withAnimation {
                                cameraPosition = .region(
                                    MKCoordinateRegion(
                                        center: center,
                                        span: MKCoordinateSpan(latitudeDelta: 0.20, longitudeDelta: 0.20)
                                    )
                                )
                            }
                        } label: {
                            Image(systemName: "location.north.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.bg)
                                .frame(width: 50, height: 50)
                                .background(Theme.ink, in: Circle())
                                .overlay(Circle().stroke(Theme.bg.opacity(0.18), lineWidth: 1))
                        }
                        .buttonStyle(SorbetScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 88)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SportModeToggle() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(location.$location.compactMap { $0 }) { value in
                cameraPosition = .region(MKCoordinateRegion(
                    center: value.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.20, longitudeDelta: 0.20)
                ))
            }
            .toolbarBackground(Theme.bg.opacity(0.92), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $challengePlayer) { player in
                ChallengeComposerView(player: player)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.bg)
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { chatConversationId != nil },
                    set: { if !$0 { chatConversationId = nil } }
                )
            ) {
                if let chatConversationId {
                    ChatView(conversationId: chatConversationId)
                }
            }
        }
    }

    private var mapHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Players nearby")
                        .font(Theme.heading(20))
                        .foregroundStyle(Theme.ink)
                    Text("\(visiblePlayers.count) active · \(radiusMiles) mile radius")
                        .font(Theme.ui(11, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.signal)
                        .frame(width: 7, height: 7)
                    Text("LIVE")
                        .font(Theme.ui(9, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(Theme.signal)
                }
            }

            filters
            if let openFilter { filterOptions(for: openFilter) }
        }
        .padding(14)
        .background(Theme.bg.opacity(0.90), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { toggleFilter(.gender) } label: {
                    filterChip(
                        genderFilter?.rawValue ?? "Gender",
                        icon: "person.2.fill",
                        active: genderFilter != nil
                    )
                    }
                    .buttonStyle(.plain)

                Button { toggleFilter(.rating) } label: {
                    filterChip(
                        ratingFilter == .all ? "Rating" : ratingFilter.title,
                        icon: "bolt.fill",
                        active: ratingFilter != .all
                    )
                }
                .buttonStyle(.plain)

                Button {
                    genderFilter = nil
                    ratingFilter = .all
                } label: {
                    filterChip("Clear filters", icon: "xmark", active: false, dropdown: false)
                }
            }
        }
    }

    private func toggleFilter(_ filter: MapFilterPanel) {
        withAnimation(.easeOut(duration: 0.15)) {
            openFilter = openFilter == filter ? nil : filter
        }
    }

    @ViewBuilder private func filterOptions(for panel: MapFilterPanel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                switch panel {
                case .gender:
                    optionButton("All", selected: genderFilter == nil) { genderFilter = nil }
                    ForEach(Gender.allCases) { gender in
                        optionButton(gender.rawValue, selected: genderFilter == gender) { genderFilter = gender }
                    }
                case .rating:
                    ForEach(MapRatingFilter.allCases) { filter in
                        optionButton(filter.title, selected: ratingFilter == filter) { ratingFilter = filter }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func optionButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            withAnimation(.easeOut(duration: 0.12)) { openFilter = nil }
        } label: {
            Text(title)
                .font(Theme.ui(10, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? Theme.bg : Theme.ink)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(selected ? app.themeColor : Theme.faint,
                            in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    private func filterChip(
        _ text: String,
        icon: String,
        active: Bool,
        dropdown: Bool = true
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
            if dropdown {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .black))
                    .accessibilityHidden(true)
            }
        }
            .font(Theme.ui(12, weight: .bold))
            .foregroundStyle(active ? Theme.bg : Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(active ? app.themeColor : Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(active ? app.themeColor : Theme.hairline, lineWidth: 1))
    }

    private func coordinate(for player: Player) -> CLLocationCoordinate2D {
        if let latitude = player.approximateLatitude,
           let longitude = player.approximateLongitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        let offsets: [(Double, Double)] = [
            (0.015, -0.020), (-0.025, 0.012), (0.032, 0.026),
            (-0.040, -0.030), (0.055, -0.014), (-0.012, 0.054),
            (0.070, 0.038), (-0.064, 0.021), (0.024, -0.072),
            (-0.078, -0.055), (0.091, 0.010), (-0.018, -0.095)
        ]
        let index = app.players.firstIndex(where: { $0.id == player.id }) ?? 0
        let offset = offsets[index % offsets.count]
        return CLLocationCoordinate2D(
            latitude: center.latitude + offset.0,
            longitude: center.longitude + offset.1
        )
    }
}

private enum MapFilterPanel: Hashable {
    case gender, rating
}

private struct PlayerMapPin: View {
    let player: Player
    let sport: Sport
    let isSelected: Bool
    let friendshipState: FriendshipState
    let action: () -> Void
    let addFriend: () -> Void
    let createChallenge: () -> Void

    var body: some View {
        VStack(spacing: isSelected ? 8 : -3) {
            Button(action: action) {
                VStack(spacing: -3) {
                ZStack {
                    Circle().fill(Theme.surface)
                    Circle().stroke(isSelected ? Theme.color(for: sport) : Theme.hairline, lineWidth: isSelected ? 2 : 1)
                    AvatarView(avatar: player.avatar, size: isSelected ? 48 : 41)
                        .scaleEffect(0.78)
                }
                .frame(width: isSelected ? 56 : 49, height: isSelected ? 56 : 49)

                Text(player.profile(sport)?.usesElo == true ? "\(player.rating(sport))" : "Unrated")
                    .font(Theme.display(10))
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.color(for: sport), in: Capsule())
                }
            }
            .buttonStyle(SorbetScaleButtonStyle())
            .accessibilityLabel(player.profile(sport)?.usesElo == true
                                ? "\(player.name), rating \(player.rating(sport))"
                                : "\(player.name), unrated")
            .accessibilityHint("Show profile")

            if isSelected {
                VStack(alignment: .leading, spacing: 9) {
                        Text(player.name).font(Theme.heading(16))
                        HStack(spacing: 7) {
                            Label("\(player.distanceMiles, specifier: "%.1f") mi", systemImage: "location.fill")
                            Label(player.profile(sport)?.usesElo == true ? "Rating \(player.rating(sport))" : "Unrated", systemImage: "bolt.fill")
                        }
                        .font(Theme.ui(9, weight: .bold)).foregroundStyle(Theme.muted)
                        Text("Available \(player.availability.first?.period.hours ?? "this week")")
                            .font(Theme.ui(10)).foregroundStyle(Theme.muted)
                        Text(player.profiles.keys.map(\.title).sorted().joined(separator: " · "))
                            .font(Theme.ui(10, weight: .bold)).lineLimit(1)
                        HStack(spacing: 7) {
                            Button(action: addFriend) {
                                Text(friendshipState == .none ? "Add as friend" : "Request sent")
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(friendshipState != .none)
                            Button(action: createChallenge) {
                                Text("Create a challenge").frame(maxWidth: .infinity)
                            }
                        }
                        .font(Theme.ui(9, weight: .bold))
                        .foregroundStyle(Theme.bg)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.ink)
                }
                .foregroundStyle(Theme.ink)
                .padding(12)
                .frame(width: 260)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(Theme.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
            }
        }
    }
}

private enum MapRatingFilter: String, CaseIterable, Identifiable {
    case all
    case beginner
    case intermediate
    case advanced
    case unrated

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All ratings"
        case .beginner: return "Under 80"
        case .intermediate: return "80–99"
        case .advanced: return "100+"
        case .unrated: return "Unrated"
        }
    }

    var range: ClosedRange<Int> {
        switch self {
        case .all: return 0...10_000
        case .beginner: return 0...79
        case .intermediate: return 80...99
        case .advanced: return 100...10_000
        case .unrated: return 0...10_000
        }
    }
}
