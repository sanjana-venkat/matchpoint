import SwiftUI
import PhotosUI
import UIKit

/// Social story → up to four sports → per-sport setup → identity.
struct OnboardingFlowView: View {
    @EnvironmentObject private var app: AppState

    @State private var me = MockData.emptyMe()
    @State private var selectedSports: [Sport] = []
    @State private var profiles: [Sport: SportProfile] = [:]
    @State private var step: Int

    private let detailsStep = 3
    private let sportsStep = 4
    private let sportsSetupStep = 5
    private let welcomeStep = 6
    private let totalSteps = 7

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-onboarding-step"),
           arguments.indices.contains(flag + 1),
           let requested = Int(arguments[flag + 1]) {
            _step = State(initialValue: max(0, requested))
            if requested >= 5 {
                let previewSports: [Sport] = [.pickleball, .badminton, .soccer]
                _selectedSports = State(initialValue: previewSports)
                _profiles = State(initialValue: Dictionary(uniqueKeysWithValues: previewSports.map { sport in
                    (sport, SportProfile(sport: sport))
                }))
            }
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
                case detailsStep:
                    IdentitySetupStep(me: $me, onFinish: next)
                case sportsStep:
                    SportSelectionStep(selected: $selectedSports) {
                        seedProfiles()
                        next()
                    }
                case sportsSetupStep:
                    ConsolidatedSportsSetupStep(
                        sports: selectedSports,
                        profiles: $profiles,
                        onContinue: finish
                    )
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
        .preferredColorScheme(.light)
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
                    .frame(width: 42, height: 42)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
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
                kicker: "Set up your sports",
                title: "Configure each sport.",
                detail: "Individual sports use the MP Rating. Group sports run on a shared calendar and are evaluated by the people who play alongside you."
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

            FlowCTA(title: "Finish setup", action: onContinue)
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

                RallyCheckbox(
                    title: "I want to opt out of the rating system",
                    isOn: binding(for: sport).ratingOptOut
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Everyone starts at 80, and the rating moves in small, honest steps after verified rated matches.")
                    Text("Only verified rated matches change your starting rating.")
                    Text("Games with unrated opponents remain unrated for everyone.")
                }
                .font(Theme.ui(11))
                .foregroundStyle(Theme.muted)
            } else {
                Text("Group sports do not use a numerical player rating. Fixtures live on a shared calendar, and verified teammates and opponents can evaluate the skills that matter in \(sport.title) after play.")
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
            title: "Discover local\nsports partners.",
            body: "Match Point connects you with players a few streets away who play the sports you play. Browse the neighbourhood, meet people on court, and build a regular group you look forward to seeing every week.",
            kicker: "Find your people"
        ),
        WelcomePage(
            title: "Play people\nat your level.",
            body: "Individual sports use the MP Rating, a single number that moves in small, honest steps. Beat someone stronger and you climb faster. Group sports skip the number entirely and rely on peer skill evaluations from the people who played beside you.",
            kicker: "Fair matchmaking"
        ),
        WelcomePage(
            title: "Challenge, play,\nlog the score.",
            body: "In individual sports you send a challenge, play the match, and upload the score for your opponent to verify. In group sports you keep a shared calendar of fixtures and rate each other afterwards, because a squad needs a schedule far more than it needs a ladder.",
            kicker: "Stay organised"
        )
    ]

    var body: some View {
        GeometryReader { proxy in
            let item = pages[page]
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        MultiSportSocialHero(variant: page)
                            .frame(height: min(330, proxy.size.height * 0.36))
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))

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
                                .font(Theme.ui(15))
                                .foregroundStyle(Theme.muted)
                                .lineSpacing(4)
                            supportingContent
                        }
                        .padding(.top, 18)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                }

                FlowCTA(
                    title: page == 2 ? "Choose my sports" : "Continue",
                    action: onContinue
                )
                .padding(20)
                .background(Theme.bg)
            }
        }
    }

    @ViewBuilder private var supportingContent: some View {
        if page == 0 {
            VStack(alignment: .leading, spacing: 0) {
                storyRow("01", "Players near you", "See who is playing inside your radius.")
                Divider().overlay(Theme.hairline)
                storyRow("02", "Local communities", "Join groups that already play your sports.")
                Divider().overlay(Theme.hairline)
                storyRow("03", "Friendly competition", "Track progress without losing the fun.")
            }
            .padding(.top, 12)
        } else if page == 1 {
            VStack(spacing: 0) {
                ratingRow("Even opponent", "+1 to +2 points")
                Divider().overlay(Theme.hairline)
                ratingRow("Stronger opponent", "+3 points")
                Divider().overlay(Theme.hairline)
                ratingRow("Significant upset", "+4 to +5 points")
            }
            .padding(.top, 8)
        }
    }

    private func storyRow(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Text(number)
                .font(RallyType.numeral(14))
                .foregroundStyle(RallyPalette.ink)
                .frame(width: 38, height: 38)
                .background(RallyPalette.sun, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(RallyType.body(15, weight: .bold))
                Text(detail).font(RallyType.caption).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 13)
    }

    private func ratingRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .fontWeight(.bold)
                .foregroundStyle(RallyPalette.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(RallyPalette.sun, in: Capsule())
        }
        .font(RallyType.body(14))
        .padding(.vertical, 13)
    }
}

private struct MultiSportSocialHero: View {
    let variant: Int

    private var imageName: String {
        switch variant {
        case 0: return "Rally-scene-court"
        case 1: return "Rally-scene-paddles"
        default: return "Rally-hero-serve"
        }
    }

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.hairline, lineWidth: 1))
            .accessibilityHidden(true)
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
                title: "Pick up to four sports.",
                detail: "Every sport has its own mode, match history, and player community. You can change your active sport at any time."
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

            FlowCTA(title: position == total ? "Continue to profile" : "Next sport", accent: accent, action: onContinue)
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

// MARK: - Identity

private struct IdentitySetupStep: View {
    @Binding var me: Player
    let onFinish: () -> Void
    @FocusState private var focus: Field?
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
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

                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Theme.surface2)
                        if let selectedPhotoData,
                           let image = UIImage(data: selectedPhotoData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        } else {
                            VStack(spacing: 7) {
                                Image(systemName: "camera")
                                    .font(.system(size: 28, weight: .medium))
                                Text("Add photo")
                                    .font(RallyType.caption)
                            }
                            .foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(width: 126, height: 126)
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(RallyPalette.sun)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundStyle(RallyPalette.ink)
                            )
                            .overlay(Circle().stroke(Theme.bg, lineWidth: 3))
                    }

                    HStack(spacing: 10) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            photoActionLabel("Photo library", icon: "photo.on.rectangle", primary: true)
                        }
                        .buttonStyle(.plain)

                        Button { showCameraNote = true } label: {
                            photoActionLabel("Camera", icon: "camera", primary: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)

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

                FlowCTA(title: "Continue to sports", enabled: canFinish, action: onFinish)
            }
            .padding(20)
        }
        .onAppear { focus = .name }
        .onChange(of: photoItem) { _, item in
            Task { selectedPhotoData = try? await item?.loadTransferable(type: Data.self) }
        }
        .overlay {
            if showCameraNote {
                ZStack {
                    RallyPalette.ink.opacity(0.32).ignoresSafeArea()
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Take a profile photo")
                                .font(RallyType.cardTitle)
                            Spacer()
                            Button { showCameraNote = false } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .black))
                                    .frame(width: 42, height: 42)
                                    .background(RallyPalette.creamDeep, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Camera capture opens on a physical device. In the simulator, choose an image from the photo library to preview the finished profile.")
                            .font(RallyType.body(15))
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(3)
                        Button { showCameraNote = false } label: {
                            Text("Got it")
                                .font(RallyType.action)
                                .foregroundStyle(RallyPalette.cream)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(RallyPalette.ink, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(22)
                    .background(RallyPalette.cream, in: RoundedRectangle(cornerRadius: RallyLayout.cardRadius, style: .continuous))
                    .padding(24)
                }
                .transition(.opacity)
            }
        }
    }

    private func photoActionLabel(_ title: String, icon: String, primary: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold))
            Text(title).font(RallyType.action)
        }
        .foregroundStyle(primary ? RallyPalette.cream : RallyPalette.ink)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(primary ? RallyPalette.ink : RallyPalette.sun, in: Capsule())
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
