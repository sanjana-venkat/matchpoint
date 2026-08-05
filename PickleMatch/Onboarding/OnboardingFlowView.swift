import SwiftUI
import PhotosUI

/// Social story → up to four sports → per-sport setup → availability → identity.
struct OnboardingFlowView: View {
    @EnvironmentObject private var app: AppState

    @State private var me = MockData.emptyMe()
    @State private var selectedSports: [Sport] = []
    @State private var profiles: [Sport: SportProfile] = [:]
    @State private var availability: [AvailabilitySlot] = []
    @State private var step: Int

    private let sportsSetupStep = 4
    private let availabilityStep = 5
    private let detailsStep = 6
    private let welcomeStep = 7
    private let totalSteps = 8

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-onboarding-step"),
           arguments.indices.contains(flag + 1),
           let requested = Int(arguments[flag + 1]) {
            _step = State(initialValue: max(0, requested))
        } else {
            _step = State(initialValue: 0)
        }
#else
        _step = State(initialValue: 0)
#endif
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            Group {
                switch step {
                case 0, 1, 2:
                    WelcomeStory(page: step, onContinue: next)
                case 3:
                    SportSelectionStep(selected: $selectedSports) {
                        seedProfiles()
                        next()
                    }
                case sportsSetupStep:
                    ConsolidatedSportsSetupStep(
                        sports: selectedSports,
                        profiles: $profiles,
                        onContinue: next
                    )
                case availabilityStep:
                    AvailabilitySetupStep(availability: $availability, onContinue: next)
                case detailsStep:
                    IdentitySetupStep(me: $me, onFinish: finish)
                default:
                    WelcomeLoadingView(name: me.name)
                }
            }
            .transition(.opacity)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingNavigation(
                canGoBack: step > 0,
                progress: Double(step + 1) / Double(max(1, totalSteps)),
                accent: currentAccent,
                back: back
            )
        }
        .animation(.easeInOut(duration: 0.18), value: step)
        .preferredColorScheme(.dark)
    }

    private var currentAccent: Color {
        Theme.accent
    }

    private func profileBinding(for sport: Sport) -> Binding<SportProfile> {
        Binding(
            get: { profiles[sport] ?? SportProfile(sport: sport) },
            set: { profiles[sport] = $0 }
        )
    }

    private func seedProfiles() {
        for sport in selectedSports where profiles[sport] == nil {
            profiles[sport] = SportProfile(
                sport: sport,
                rating: EloRating.start,
                ratingOptOut: false,
                peerSkillRatings: sport.skillCategories.map {
                    PeerSkillRating(category: $0, average: 0, count: 0)
                }
            )
        }
        profiles = profiles.filter { selectedSports.contains($0.key) }
    }

    private func next() {
        withAnimation { step = min(welcomeStep, step + 1) }
    }

    private func back() {
        guard step > 0 else { return }
        withAnimation { step -= 1 }
    }

    private func finish() {
        me.availability = availability
        me.profiles = profiles
        app.me = me
        app.mySports = selectedSports
        withAnimation { step = welcomeStep }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            app.completeOnboarding()
        }
    }
}

// MARK: - Navigation and shared controls

private struct OnboardingNavigation: View {
    let canGoBack: Bool
    let progress: Double
    let accent: Color
    let back: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canGoBack ? Theme.ink : Theme.muted.opacity(0.45))
                    .frame(width: 38, height: 38)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule().fill(accent).frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Theme.bg.opacity(0.91))
    }
}

// MARK: - Consolidated sports setup

private struct ConsolidatedSportsSetupStep: View {
    let sports: [Sport]
    @Binding var profiles: [Sport: SportProfile]
    let onContinue: () -> Void
    @State private var infoSport: Sport?

    var body: some View {
        VStack(spacing: 0) {
            FlowHeader(
                kicker: "Sports setup",
                title: "Set up all your sports.",
                detail: "Choose whether rated individual play is right for you. Team-sport skills are rated by verified peers after play."
            )
            .padding(20)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sports) { sport in
                        sportCard(sport)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            FlowCTA(title: "Set availability", action: onContinue)
                .padding(20)
                .background(Theme.bg)
        }
        .sheet(item: $infoSport) { sport in
            PeerRatingInfoSheet(sport: sport)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.bg)
        }
    }

    @ViewBuilder private func sportCard(_ sport: Sport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                SportIcon(sport: sport, size: 30)
                Text(sport.title).font(Theme.heading(19))
                Spacer()
                Text(sport.category == .individual ? "INDIVIDUAL" : "GROUP")
                    .font(Theme.ui(9, weight: .bold)).tracking(1).foregroundStyle(Theme.muted)
            }

            if sport.category == .individual {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Starting rating").font(Theme.ui(11)).foregroundStyle(Theme.muted)
                        Text("80").font(Theme.display(44).monospacedDigit())
                    }
                    Spacer()
                }

                Toggle("I want to opt out of the rating system", isOn: binding(for: sport).ratingOptOut)
                    .font(Theme.ui(13, weight: .bold))
                    .tint(Theme.signal)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Only verified rated matches change your starting rating.")
                    Text("Games with unrated opponents remain unrated for everyone.")
                }
                .font(Theme.ui(11))
                .foregroundStyle(Theme.muted)
            } else {
                Text("Group sports do not use a numerical rating. After verified games, peers can rate the skills that matter in \(sport.title).")
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                Button("Read more") { infoSport = sport }
                    .font(Theme.ui(12, weight: .bold))
                    .foregroundStyle(Theme.signal)
            }
        }
        .padding(17)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.hairline, lineWidth: 1))
    }

    private func binding(for sport: Sport) -> Binding<SportProfile> {
        Binding(
            get: { profiles[sport] ?? SportProfile(sport: sport) },
            set: { profiles[sport] = $0 }
        )
    }
}

private struct PeerRatingInfoSheet: View {
    let sport: Sport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    SportIcon(sport: sport, size: 38)
                    Text("\(sport.title) peer ratings").font(Theme.heading(25))
                }
                Text("After a verified \(sport.title) game, teammates and opponents can score your sport-specific skills from one to five. Match Point shows each category's average and verified reviewer count; a single review never creates a public numerical player rating.")
                    .font(Theme.ui(13)).foregroundStyle(Theme.muted).lineSpacing(4)
                ForEach(sport.skillCategories, id: \.self) { category in
                    Label(category, systemImage: "star.fill")
                        .font(Theme.ui(15, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.bg)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

private struct FlowHeader: View {
    let kicker: String
    let title: String
    var detail: String? = nil
    var accent = Theme.neonGreen
    var sport: Sport? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(kicker.uppercased())
                .font(Theme.ui(11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                if let sport { SportIcon(sport: sport, size: 34) }
                Text(title)
                    .font(Theme.heading(31))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.ink)
            }
            if let detail {
                Text(detail)
                    .font(Theme.ui(13))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FlowCTA: View {
    let title: String
    var enabled = true
    var accent = Theme.neonGreen
    let action: () -> Void

    var body: some View {
        BottomCTA(title: title, enabled: enabled, accent: accent, action: action)
    }
}

// MARK: - Welcome

private struct WelcomePage {
    let title: String
    let body: String
    let kicker: String
}

private struct WelcomeStory: View {
    let page: Int
    let onContinue: () -> Void

    private let pages = [
        WelcomePage(
            title: "Find people\nto play with.",
            body: "Meet nearby players and make the group chat real.",
            kicker: "Play together"
        ),
        WelcomePage(
            title: "Make a plan.\nMeet on court.",
            body: "See when everyone is free and lock in a game.",
            kicker: "Easy scheduling"
        ),
        WelcomePage(
            title: "Play. Track.\nGo again.",
            body: "Choose casual play or count the result toward your rating.",
            kicker: "Your game, your call"
        )
    ]

    var body: some View {
        GeometryReader { proxy in
            let item = pages[page]
            VStack(alignment: .leading, spacing: 0) {
                MultiSportSocialHero(variant: page)
                    .frame(height: min(390, proxy.size.height * 0.43))
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    Text(item.kicker.uppercased())
                        .font(Theme.ui(11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.muted)
                    Text(item.title)
                        .font(Theme.heading(31))
                        .tracking(-0.7)
                        .lineSpacing(-1)
                    Text(item.body)
                        .font(Theme.ui(14))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(3)

                    Spacer(minLength: 10)

                    FlowCTA(
                        title: page == 2 ? "Choose my sports" : "Next",
                        action: onContinue
                    )
                }
                .padding(20)
                .padding(.bottom, 8)
            }
        }
    }
}

private struct MultiSportSocialHero: View {
    let variant: Int

    private var imageName: String {
        switch variant {
        case 0: return "OnboardingTournament"
        case 1: return "OnboardingCourt"
        default: return "OnboardingCommunity"
        }
    }

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .saturation(0.78)
            .contrast(1.04)
            .overlay(
                LinearGradient(
                    colors: [.clear, Theme.bg.opacity(0.18)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.hairline, lineWidth: 1))
    }
}

// MARK: - Sport selection

private struct SportSelectionStep: View {
    @Binding var selected: [Sport]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            FlowHeader(
                kicker: "Your sports",
                title: "Choose up to four."
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)

            HStack {
                Text("\(selected.count) of 4 sports selected")
                    .font(Theme.ui(12, weight: .bold))
                Spacer()
                if selected.count == 4 {
                    Text("LIMIT REACHED")
                        .font(Theme.ui(9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.neonOrange)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView {
                VStack(spacing: 18) {
                    category(.individual)
                    category(.group)
                }
                .padding(20)
            }

            FlowCTA(title: "Set up selected sports", enabled: !selected.isEmpty, action: onContinue)
                .padding(20)
                .background(Theme.bg)
        }
    }

    private func category(_ category: SportCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category.rawValue.uppercased())
                .font(Theme.ui(10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Sport.allCases.filter { $0.category == category }) { sport in
                    sportCard(sport)
                }
            }
        }
    }

    private func sportCard(_ sport: Sport) -> some View {
        let isSelected = selected.contains(sport)
        let disabled = selected.count >= 4 && !isSelected
        return SelectableCard(title: sport.title, sport: sport,
                              isSelected: isSelected, isDisabled: disabled) {
            if isSelected {
                selected.removeAll { $0 == sport }
            } else if selected.count < 4 {
                selected.append(sport)
            }
        }
    }
}

// MARK: - Per-sport setup

private struct PerSportSetupStep: View {
    let sport: Sport
    @Binding var profile: SportProfile
    let position: Int
    let total: Int
    let onContinue: () -> Void

    private var accent: Color { Theme.accent }

    var body: some View {
        VStack(spacing: 0) {
            FlowHeader(
                kicker: "Sport \(position) of \(total)",
                title: "Set up \(sport.title).",
                accent: accent,
                sport: sport
            )
            .padding(20)

            ScrollView {
                if sport.category == .individual {
                    individualSetup
                } else {
                    groupSetup
                }
            }

            FlowCTA(title: position == total ? "Set availability" : "Next sport", accent: accent, action: onContinue)
                .padding(20)
                .background(Theme.bg)
        }
        .onAppear { profile.sport = sport }
    }

    private var individualSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Starting rating")
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.muted)
                    Text("80")
                        .font(Theme.display(64).monospacedDigit())
                }
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(accent)
            }
            Divider().overlay(Theme.hairline)
            Text("Rated games move your score a little. Casual games never affect it.")
                .font(Theme.ui(13))
                .foregroundStyle(Theme.muted)
        }
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.hairline, lineWidth: 1))
        .padding(.horizontal, 20)
        .onAppear {
            profile.ratingOptOut = false
            profile.socialSkillLabel = nil
        }
    }

    private var groupSetup: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(sport.skillCategories, id: \.self) { category in
                HStack(spacing: 14) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(accent)
                        .frame(width: 44, height: 44)
                        .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category).font(Theme.heading(16))
                        Text("No ratings yet · appears after verified games")
                            .font(Theme.ui(11))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text("— / 5")
                        .font(Theme.ui(13, weight: .bold))
                }
                .padding(15)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 1))
            }

            Label(
                "Only people with a verified game can rate these skills. Ratings show the average and total reviewer count.",
                systemImage: "checkmark.shield.fill"
            )
            .font(Theme.ui(12))
            .foregroundStyle(Theme.muted)
            .padding(15)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Availability and identity

private struct AvailabilitySetupStep: View {
    @Binding var availability: [AvailabilitySlot]
    let onContinue: () -> Void
    @State private var mode: AvailabilityEditorMode = .everyWeek

    private var activeWindows: [AvailabilitySlot] {
        availability.filter { mode == .everyWeek ? $0.isWeekly : !$0.isWeekly }
    }

    var body: some View {
        VStack(spacing: 0) {
            FlowHeader(
                kicker: "Shared availability",
                title: "When can you play?"
            )
            .padding(20)

            ScrollView {
                AvailabilityScheduleEditor(slots: $availability, mode: $mode)
                    .padding(.horizontal, 20)
            }

            FlowCTA(
                title: activeWindows.isEmpty ? "Choose at least one window" : "Save \(activeWindows.count) windows",
                enabled: !activeWindows.isEmpty,
                action: onContinue
            )
            .padding(20)
            .background(Theme.bg)
        }
    }
}

private struct IdentitySetupStep: View {
    @Binding var me: Player
    let onFinish: () -> Void
    @FocusState private var focus: Field?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCameraNote = false
    private enum Field { case name, username, age }

    private var canFinish: Bool {
        !me.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        me.username.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 &&
        (13...99).contains(me.age)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FlowHeader(
                    kicker: "Your identity",
                    title: "Create your profile."
                )

                HStack(spacing: 10) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Photo library", systemImage: "photo.on.rectangle")
                            .font(Theme.ui(12, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button { showCameraNote = true } label: {
                        Label("Camera", systemImage: "camera.fill")
                            .font(Theme.ui(12, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .foregroundStyle(Theme.ink)

                Text("Or choose from (Avatar.all.count) avatars")
                    .font(Theme.ui(11, weight: .bold))
                    .foregroundStyle(Theme.muted)
                AvatarChoiceStrip(selection: $me.avatar, size: 62)

                VStack(spacing: 12) {
                    TextField("Full name", text: $me.name)
                        .textInputAutocapitalization(.words)
                        .focused($focus, equals: .name)

                    Divider().overlay(Theme.hairline)

                    TextField("Unique username", text: $me.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .username)

                    Divider().overlay(Theme.hairline)

                    HStack {
                        TextField("Age", value: $me.age, format: .number)
                            .keyboardType(.numberPad)
                            .focused($focus, equals: .age)
                    }
                }
                .font(Theme.ui(16, weight: .medium))
                .padding(16)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 1))

                VerticalChoiceList(
                    options: Gender.allCases.map(\.rawValue),
                    selection: Binding(
                        get: { me.gender.rawValue },
                        set: { me.gender = Gender(rawValue: $0) ?? me.gender }
                    )
                )

                FlowCTA(title: "Create profile", enabled: canFinish, action: onFinish)
            }
            .padding(20)
        }
        .onAppear { focus = .name }
        .alert("Camera prototype", isPresented: $showCameraNote) {
            Button("Continue", role: .cancel) {}
        } message: {
            Text("On a physical device, this action opens the camera so you can take a profile photo.")
        }
    }

}

private struct WelcomeLoadingView: View {
    let name: String
    @State private var animate = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().stroke(Theme.hairline, lineWidth: 5).frame(width: 74, height: 74)
                Circle().trim(from: 0, to: 0.72)
                    .stroke(Theme.signal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 74, height: 74)
                    .rotationEffect(.degrees(animate ? 360 : 0))
            }
            Text("Welcome to Match Point, \(name.split(separator: " ").first.map(String.init) ?? "Player")!")
                .font(Theme.heading(25))
                .multilineTextAlignment(.center)
            Text("Preparing your home court…")
                .font(Theme.ui(13))
                .foregroundStyle(Theme.muted)
            Spacer()
        }
        .padding(24)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { animate = true }
        }
    }
}
