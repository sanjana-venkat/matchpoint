import SwiftUI

struct SashankQuickChallengeSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var opponentId: UUID?
    @State private var opponentQuery = ""
    @State private var venue = "Riverside Courts"
    @State private var proposedDates = [Date().addingTimeInterval(86_400)]
    @State private var dateEditor: ChallengeDateEditor?
    @FocusState private var opponentSearchFocused: Bool

    private var candidates: [Player] {
        let connected = app.players.filter {
            app.friendIds.contains($0.id) && $0.profile(app.activeSport) != nil
        }
        return connected.isEmpty ? app.players.filter { $0.profile(app.activeSport) != nil } : connected
    }

    private var filteredCandidates: [Player] {
        let query = opponentQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return candidates.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.username.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.22))
                .frame(width: 42, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            HStack(alignment: .top) {
                Text("Challenge a \(app.activeSport.title) player")
                    .font(RallyType.title)
                    .rallyDisplayLeading()
                Spacer()
                closeButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Divider().padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fieldLabel("Opponent")
                    opponentSearch

                    Text("You can only challenge people you are already connected with.")
                        .font(.system(size: 10))
                        .foregroundStyle(RallyPalette.inkMuted)

                    fieldLabel("Venue")
                    RallyOptionSelector(
                        label: "Venue",
                        selection: venue,
                        options: ["Riverside Courts", "Zilker Courts", "Austin Pickle Ranch"].map {
                            RallySelectorOption(id: $0, title: $0)
                        },
                        showsLabel: false,
                        select: { venue = $0.title }
                    )

                    fieldLabel("Times you can play")
                    ForEach(proposedDates.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(RallyPalette.ink)
                                .frame(width: 28, height: 28)
                                .background(app.activeSport.rallyAccent, in: Circle())
                            dateControl(index, showsTime: false)
                                .frame(maxWidth: .infinity)
                            dateControl(index, showsTime: true)
                                .frame(width: 112)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 58)
                        .background(RallyPalette.creamDeep.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    if proposedDates.count < 3 {
                        Button {
                            proposedDates.append((proposedDates.last ?? .now).addingTimeInterval(86_400))
                        } label: {
                            Label("Offer another time", systemImage: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(RallyPalette.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(RallyPalette.creamDeep, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: send) {
                        Text("Send \(proposedDates.count) \(proposedDates.count == 1 ? "time" : "times")")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(RallyPalette.ink, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(opponentId == nil)
                    .opacity(opponentId == nil ? 0.42 : 1)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RallyPalette.cream.ignoresSafeArea())
        .foregroundStyle(RallyPalette.ink)
        .preferredColorScheme(.light)
        .onChange(of: opponentQuery) { _, query in
            guard let opponentId, let selectedPlayer = app.player(opponentId) else { return }
            if query != selectedPlayer.name { self.opponentId = nil }
        }
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demo-challenge-search") {
                opponentQuery = "ma"
                opponentSearchFocused = true
            }
            if ProcessInfo.processInfo.arguments.contains("-demo-challenge-time-picker") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    dateEditor = ChallengeDateEditor(index: 0, mode: .time)
                }
            }
#endif
        }
        .sheet(item: $dateEditor) { editor in
            RallyDateTimeEditor(
                mode: editor.mode,
                selection: proposedDates[editor.index],
                accent: app.activeSport.rallyAccent
            ) { value in
                proposedDates[editor.index] = value
            }
            .presentationDetents([editor.mode == .date ? .medium : .large])
            .presentationDragIndicator(.hidden)
        }
    }

    private var opponentSearch: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(RallyPalette.inkMuted)
                TextField("Search by name or username", text: $opponentQuery)
                    .font(RallyType.body(15))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($opponentSearchFocused)
                if !opponentQuery.isEmpty {
                    Button {
                        opponentQuery = ""
                        opponentId = nil
                        opponentSearchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(RallyPalette.inkMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear opponent search")
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(RallyPalette.creamDeep, in: Capsule())

            if opponentSearchFocused && !opponentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 0) {
                    if filteredCandidates.isEmpty {
                        Text("No connected players found")
                            .font(RallyType.caption)
                            .foregroundStyle(RallyPalette.inkMuted)
                            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                            .padding(.horizontal, 14)
                    } else {
                        ForEach(Array(filteredCandidates.prefix(5))) { player in
                            Button {
                                opponentId = player.id
                                opponentQuery = player.name
                                opponentSearchFocused = false
                            } label: {
                                HStack(spacing: 11) {
                                    RallyPlayerAvatar(player: player, size: 34)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(player.name).font(RallyType.action)
                                        Text(player.username.isEmpty
                                             ? "MP Rating \(player.rating(app.activeSport))"
                                             : "@\(player.username) · MP \(player.rating(app.activeSport))")
                                            .font(RallyType.caption)
                                            .foregroundStyle(RallyPalette.inkMuted)
                                    }
                                    Spacer()
                                }
                                .foregroundStyle(RallyPalette.ink)
                                .padding(.horizontal, 14)
                                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if player.id != filteredCandidates.prefix(5).last?.id {
                                Divider().overlay(RallyPalette.rule)
                            }
                        }
                    }
                }
                .background(RallyPalette.creamDeep.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: RallyPalette.ink.opacity(0.08), radius: 12, y: 5)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: filteredCandidates.map(\.id))
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 40, height: 40)
                .background(RallyPalette.creamDeep, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy))
            .tracking(1)
            .foregroundStyle(RallyPalette.inkMuted)
    }

    private func dateControl(_ index: Int, showsTime: Bool) -> some View {
        let value = proposedDates[index]
        let title = showsTime
            ? value.formatted(date: .omitted, time: .shortened)
            : value.formatted(.dateTime.day().month(.abbreviated).year())
        return Button {
            dateEditor = ChallengeDateEditor(index: index, mode: showsTime ? .time : .date)
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(RallyType.numeral(16))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(RallyPalette.inkMuted)
            }
            .foregroundStyle(RallyPalette.ink)
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(RallyPalette.cream.opacity(0.92), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsTime ? "Choose time" : "Choose date")
    }

    private func send() {
        guard let opponentId, let player = app.player(opponentId), let first = proposedDates.first else { return }
        app.createChallenge(
            with: player,
            sport: app.activeSport,
            date: first,
            proposedDates: proposedDates,
            venue: venue,
            note: "",
            isRatingExempt: app.isRatingExempt(opponentIds: [opponentId], sport: app.activeSport)
        )
        dismiss()
    }
}

private struct ChallengeDateEditor: Identifiable {
    enum Mode: Equatable { case date, time }
    let index: Int
    let mode: Mode
    var id: String { "\(index)-\(mode == .date ? "date" : "time")" }
}

private struct RallyDateTimeEditor: View {
    @Environment(\.dismiss) private var dismiss
    let mode: ChallengeDateEditor.Mode
    let selection: Date
    let accent: Color
    let select: (Date) -> Void

    private let calendar = Calendar.current

    private var dates: [Date] {
        let start = calendar.startOfDay(for: .now)
        return (1...14).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var times: [Date] {
        let day = calendar.startOfDay(for: selection)
        return stride(from: 7 * 60, through: 22 * 60, by: 30).compactMap { minutes in
            calendar.date(byAdding: .minute, value: minutes, to: day)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(mode == .date ? "Choose a date" : "Choose a time")
                    .font(RallyType.title)
                    .rallyDisplayLeading()
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(RallyPalette.creamDeep, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider().overlay(RallyPalette.rule)

            ScrollView {
                if mode == .date {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(dates, id: \.self) { date in
                            option(
                                primary: date.formatted(.dateTime.weekday(.wide)),
                                secondary: date.formatted(.dateTime.month(.abbreviated).day()),
                                selected: calendar.isDate(date, inSameDayAs: selection)
                            ) { replacingDate(with: date) }
                        }
                    }
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                        ForEach(times, id: \.self) { time in
                            option(
                                primary: time.formatted(date: .omitted, time: .shortened),
                                secondary: nil,
                                selected: sameTime(time, selection)
                            ) { time }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.white.ignoresSafeArea())
        .foregroundStyle(RallyPalette.ink)
        .preferredColorScheme(.light)
    }

    private func option(primary: String, secondary: String?, selected: Bool, value: @escaping () -> Date) -> some View {
        Button {
            select(value())
            dismiss()
        } label: {
            VStack(spacing: 3) {
                Text(primary)
                    .font(RallyType.numeral(18))
                if let secondary {
                    Text(secondary)
                        .font(RallyType.caption)
                        .foregroundStyle(selected ? RallyPalette.ink.opacity(0.68) : RallyPalette.inkMuted)
                }
            }
            .foregroundStyle(RallyPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(selected ? accent : RallyPalette.creamDeep.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func replacingDate(with date: Date) -> Date {
        let time = calendar.dateComponents([.hour, .minute], from: selection)
        return calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: date) ?? date
    }

    private func sameTime(_ lhs: Date, _ rhs: Date) -> Bool {
        let left = calendar.dateComponents([.hour, .minute], from: lhs)
        let right = calendar.dateComponents([.hour, .minute], from: rhs)
        return left.hour == right.hour && left.minute == right.minute
    }
}

struct SashankScoreUploadSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void
    @State private var format = "Singles"
    @State private var selectedPlayerIds: [UUID?] = [nil, nil, nil]
    @State private var playerQueries = ["", "", ""]
    @State private var gameCount = 3
    @State private var winners = [true, true, false]
    @FocusState private var focusedPlayerSlot: Int?

    private var candidates: [Player] { app.players.filter { $0.profile(app.activeSport) != nil } }
    private var myWins: Int { winners.prefix(gameCount).filter { $0 }.count }
    private var opponentWins: Int { gameCount - myWins }
    private var requiredPlayerCount: Int { format == "Doubles" ? 3 : 1 }
    private var canSubmit: Bool { selectedPlayerIds.prefix(requiredPlayerCount).allSatisfy { $0 != nil } }

    var body: some View {
        VStack(spacing: 0) {
            stickyHeader
            Divider().overlay(RallyPalette.rule)

            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    label("Format")
                    ReferenceSegmented(
                        options: ["Singles", "Doubles"],
                        selection: Binding(
                            get: { format },
                            set: { newFormat in
                                guard newFormat != format else { return }
                                format = newFormat
                                selectedPlayerIds = [nil, nil, nil]
                                playerQueries = ["", "", ""]
                                focusedPlayerSlot = nil
                            }
                        )
                    )

                    ForEach(0..<requiredPlayerCount, id: \.self) { slot in
                        label(playerRole(slot))
                        playerSearch(slot: slot)
                    }

                    label("Games played in this session")
                    HStack(spacing: 10) {
                        ForEach(1...7, id: \.self) { count in
                            Button { setGameCount(count) } label: {
                                Text("\(count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(gameCount == count ? RallyPalette.cream : RallyPalette.ink)
                                    .frame(width: 38, height: 38)
                                    .background(gameCount == count ? RallyPalette.ink : RallyPalette.creamDeep, in: Circle())
                            }.buttonStyle(.plain)
                        }
                    }
                    Text("Record every individual game you played during the outing.")
                        .font(.system(size: 10)).foregroundStyle(RallyPalette.inkMuted)

                    label("Mark the winning side for each game")
                    ForEach(0..<gameCount, id: \.self) { index in
                        HStack(spacing: 8) {
                            Text("Game \(index + 1)")
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(RallyPalette.inkMuted)
                                .frame(width: 50, alignment: .leading)
                            winnerButton("You", selected: winners[index]) { winners[index] = true }
                            winnerButton("Opponent", selected: !winners[index]) { winners[index] = false }
                        }
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Session result").font(.system(size: 14, weight: .bold))
                            Text("\(myWins)–\(opponentWins) games · \(myWins > opponentWins ? "You won the session." : "Opponent won the session.")")
                                .font(.system(size: 11)).foregroundStyle(RallyPalette.cream.opacity(0.68))
                        }
                        Spacer()
                        Text("\(myWins)-\(opponentWins)")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(RallyPalette.ink)
                            .padding(.horizontal, 10).frame(height: 28).background(app.activeSport.rallyAccent, in: Capsule())
                    }
                    .foregroundStyle(RallyPalette.cream)
                    .padding(16)
                    .background(RallyPalette.ink, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Button(action: submit) {
                        Text("Submit for verification")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(RallyPalette.ink, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.42)
                }
                .padding(20).padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(RallyPalette.cream).foregroundStyle(RallyPalette.ink).preferredColorScheme(.light)
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-demo-score-doubles") {
                format = "Doubles"
            }
#endif
        }
    }

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.secondary.opacity(0.22)).frame(width: 42, height: 4).padding(.top, 10)
            HStack(alignment: .top) {
                Text("Upload \(app.activeSport.title) scores")
                    .font(RallyType.title)
                    .rallyDisplayLeading()
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                        .frame(width: 40, height: 40).background(RallyPalette.creamDeep, in: Circle())
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
        }
        .background(RallyPalette.cream)
        .zIndex(5)
    }

    private func label(_ value: String) -> some View {
        Text(value.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(1.2).foregroundStyle(RallyPalette.ink)
    }

    private func playerRole(_ slot: Int) -> String {
        guard format == "Doubles" else { return "Opponent" }
        return ["Your partner", "Opponent", "Opponent's partner"][slot]
    }

    private func filteredCandidates(for slot: Int) -> [Player] {
        let query = playerQueries[slot].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let otherSelections = Set(selectedPlayerIds.enumerated().compactMap { index, id in index == slot ? nil : id })
        return candidates.filter {
            !otherSelections.contains($0.id) &&
            ($0.name.localizedCaseInsensitiveContains(query) || $0.username.localizedCaseInsensitiveContains(query))
        }
    }

    private func playerSearch(slot: Int) -> some View {
        let results = filteredCandidates(for: slot)
        return VStack(spacing: 8) {
            if let selectedId = selectedPlayerIds[slot], let player = app.player(selectedId) {
                HStack(spacing: 11) {
                    RallyPlayerAvatar(player: player, size: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(player.name).font(RallyType.action)
                        Text(player.username.isEmpty ? "MP Rating \(player.rating(app.activeSport))" : "@\(player.username) · MP \(player.rating(app.activeSport))")
                            .font(RallyType.caption).foregroundStyle(RallyPalette.inkMuted)
                    }
                    Spacer()
                    Button {
                        selectedPlayerIds[slot] = nil
                        playerQueries[slot] = ""
                        focusedPlayerSlot = slot
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(RallyPalette.inkMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change \(playerRole(slot).lowercased())")
                }
                .padding(.horizontal, 14).frame(minHeight: 56)
                .background(RallyPalette.creamDeep.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(RallyPalette.inkMuted)
                    TextField("Search by name or username", text: $playerQueries[slot])
                        .font(RallyType.body(15)).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focusedPlayerSlot, equals: slot)
                    if !playerQueries[slot].isEmpty {
                        Button { playerQueries[slot] = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(RallyPalette.inkMuted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear \(playerRole(slot).lowercased()) search")
                    }
                }
                .padding(.horizontal, 16).frame(height: 52)
                .background(RallyPalette.creamDeep, in: Capsule())

                if focusedPlayerSlot == slot && !playerQueries[slot].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(spacing: 0) {
                        if results.isEmpty {
                            Text("No available players found")
                                .font(RallyType.caption).foregroundStyle(RallyPalette.inkMuted)
                                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).padding(.horizontal, 14)
                        } else {
                            ForEach(Array(results.prefix(5))) { player in
                                Button {
                                    selectedPlayerIds[slot] = player.id
                                    playerQueries[slot] = player.name
                                    focusedPlayerSlot = nextEmptySlot(after: slot)
                                } label: {
                                    HStack(spacing: 11) {
                                        RallyPlayerAvatar(player: player, size: 34)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(player.name).font(RallyType.action)
                                            Text(player.username.isEmpty ? "MP Rating \(player.rating(app.activeSport))" : "@\(player.username) · MP \(player.rating(app.activeSport))")
                                                .font(RallyType.caption).foregroundStyle(RallyPalette.inkMuted)
                                        }
                                        Spacer()
                                    }
                                    .foregroundStyle(RallyPalette.ink).padding(.horizontal, 14)
                                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if player.id != results.prefix(5).last?.id { Divider().overlay(RallyPalette.rule) }
                            }
                        }
                    }
                    .background(RallyPalette.creamDeep.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: RallyPalette.ink.opacity(0.08), radius: 12, y: 5)
                }
            }
        }
    }

    private func nextEmptySlot(after slot: Int) -> Int? {
        guard format == "Doubles" else { return nil }
        return ((slot + 1)..<requiredPlayerCount).first { selectedPlayerIds[$0] == nil }
    }

    private func winnerButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: .bold))
                .foregroundStyle(selected ? RallyPalette.cream : RallyPalette.ink)
                .frame(maxWidth: .infinity).frame(height: 38)
                .background(selected ? RallyPalette.ink : RallyPalette.creamDeep, in: Capsule())
        }.buttonStyle(.plain)
    }

    private func setGameCount(_ count: Int) {
        gameCount = count
        while winners.count < count { winners.append(true) }
    }

    private func submit() {
        let participantIds = selectedPlayerIds.prefix(requiredPlayerCount).compactMap { $0 }
        guard participantIds.count == requiredPlayerCount else { return }
        let opponentIds = format == "Doubles" ? Array(participantIds.suffix(2)) : participantIds
        let exempt = app.isRatingExempt(opponentIds: opponentIds, sport: app.activeSport)
        guard let faceOff = app.createUnscheduledMatch(
            sport: app.activeSport,
            participantIds: participantIds,
            opponentIds: opponentIds,
            isRatingExempt: exempt
        ) else { return }
        let scores = winners.prefix(gameCount).map { GameScore(myScore: $0 ? 11 : 7, opponentScore: $0 ? 7 : 11) }
        app.submitScoreUpdate(faceOffId: faceOff.id, scores: scores)
        onComplete()
        dismiss()
    }
}

private struct ReferenceSegmented: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                Button(option) { selection = option }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(selection == option ? RallyPalette.cream : RallyPalette.inkMuted)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(selection == option ? RallyPalette.ink : Color.clear, in: Capsule())
                    .buttonStyle(.plain)
            }
        }
        .padding(4).background(RallyPalette.creamDeep, in: Capsule())
    }
}
