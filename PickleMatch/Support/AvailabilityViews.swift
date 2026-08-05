import SwiftUI

enum AvailabilityEditorMode: String, CaseIterable, Identifiable {
    case specificDates = "Specific dates"
    case everyWeek = "Every week"
    var id: String { rawValue }
}

struct AvailabilityScheduleEditor: View {
    @Binding var slots: [AvailabilitySlot]
    @Binding var mode: AvailabilityEditorMode
    var comparisonSlots: [AvailabilitySlot] = []
    var ownerLabel = "You"
    var comparisonLabel: String? = nil

    var body: some View {
        VStack(spacing: DesignSystem.Metrics.verticalRhythm) {
            MinimalChoiceBar(
                options: AvailabilityEditorMode.allCases.map(\.rawValue),
                selection: Binding(
                    get: { mode.rawValue },
                    set: { mode = AvailabilityEditorMode(rawValue: $0) ?? .everyWeek }
                )
            )

            if mode == .everyWeek {
                WeeklyAvailabilityEditor(
                    slots: $slots,
                    comparisonSlots: comparisonSlots,
                    ownerLabel: ownerLabel,
                    comparisonLabel: comparisonLabel
                )
            } else {
                AvailabilityMonthEditor(
                    slots: $slots,
                    comparisonSlots: comparisonSlots,
                    ownerLabel: ownerLabel,
                    comparisonLabel: comparisonLabel
                )
            }
        }
    }
}

private struct WeeklyAvailabilityEditor: View {
    @Binding var slots: [AvailabilitySlot]
    let comparisonSlots: [AvailabilitySlot]
    let ownerLabel: String
    let comparisonLabel: String?
    @State private var selectedWeekdays: Set<Int> = []
    private let calendar = Calendar.current
    private var comparisonWeekdays: Set<Int> { Set(comparisonSlots.compactMap(\.weekday)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Every week").font(Theme.heading(19))
                Text("Choose days, then every window that usually works.")
                    .font(Theme.ui(10)).foregroundStyle(Theme.muted)
            }

            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { weekday in
                    let mine = selectedWeekdays.contains(weekday)
                    let theirs = comparisonWeekdays.contains(weekday)
                    Button { toggleWeekday(weekday) } label: {
                        Text(calendar.veryShortWeekdaySymbols[weekday - 1])
                            .font(Theme.ui(11, weight: .bold))
                            .foregroundStyle(mine ? Theme.bg : Theme.ink)
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(mine ? Theme.accent : (theirs ? Theme.blue.opacity(0.22) : Theme.faint),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                                mine ? Theme.accent : (theirs ? Theme.blue : Theme.hairline),
                                lineWidth: theirs && !mine ? 2 : 1
                            ))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(mine ? .isSelected : [])
                    .accessibilityValue(mine && theirs ? "You and \(comparisonLabel ?? "others")"
                                        : mine ? ownerLabel : theirs ? (comparisonLabel ?? "Other player") : "Not selected")
                }
            }

            VStack(spacing: 8) {
                ForEach(AvailabilityPeriod.allCases) { period in weeklyPeriodButton(period) }
            }

            if let comparisonLabel {
                Text("\(ownerLabel) uses white; \(comparisonLabel)'s saved weekly windows use blue.")
                    .font(Theme.ui(9, weight: .bold)).foregroundStyle(Theme.muted)
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.hairline, lineWidth: 1))
        .onAppear {
            selectedWeekdays = Set(slots.compactMap(\.weekday))
        }
    }

    private func toggleWeekday(_ weekday: Int) {
        if selectedWeekdays.remove(weekday) != nil {
            slots.removeAll { $0.weekday == weekday }
        } else {
            let commonPeriods = AvailabilityPeriod.allCases.filter { period in
                !selectedWeekdays.isEmpty && selectedWeekdays.allSatisfy { day in
                    slots.contains { $0.weekday == day && $0.period == period }
                }
            }
            selectedWeekdays.insert(weekday)
            for period in commonPeriods { slots.append(AvailabilitySlot(weekday: weekday, period: period)) }
        }
    }

    private func weeklyPeriodButton(_ period: AvailabilityPeriod) -> some View {
        let mine = !selectedWeekdays.isEmpty && selectedWeekdays.allSatisfy { day in
            slots.contains { $0.weekday == day && $0.period == period }
        }
        let theirs = !selectedWeekdays.isEmpty && selectedWeekdays.contains { day in
            comparisonSlots.contains { $0.weekday == day && $0.period == period }
        }
        return Button {
            guard !selectedWeekdays.isEmpty else { return }
            if mine {
                slots.removeAll { slot in selectedWeekdays.contains(slot.weekday ?? -1) && slot.period == period }
            } else {
                for day in selectedWeekdays where !slots.contains(where: { $0.weekday == day && $0.period == period }) {
                    slots.append(AvailabilitySlot(weekday: day, period: period))
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(period.rawValue).font(Theme.ui(16, weight: .bold))
                Text(period.hours).font(Theme.ui(15, weight: .medium))
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(mine ? Theme.bg : Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading).frame(height: 64)
            .padding(.horizontal, 14)
            .background(mine ? Theme.accent : (theirs ? Theme.blue.opacity(0.22) : Theme.faint),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theirs ? Theme.blue : Theme.hairline, lineWidth: theirs ? 2 : 1))
        }
        .buttonStyle(SorbetScaleButtonStyle())
        .disabled(selectedWeekdays.isEmpty)
    }
}

struct AvailabilityMonthEditor: View {
    @Binding var slots: [AvailabilitySlot]
    var comparisonSlots: [AvailabilitySlot] = []
    var ownerLabel = "You"
    var comparisonLabel: String? = nil
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var displayedMonth = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: .now)
    ) ?? .now

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let days = range.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: monthStart)
        }
        return Array(repeating: nil, count: leading) + days
    }

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthStart.formatted(.dateTime.month(.wide)))
                        .font(Theme.heading(19))
                    Text("Tap a day, then choose every window that works.")
                        .font(Theme.ui(10))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                HStack(spacing: 5) {
                    monthButton("chevron.left", delta: -1)
                    monthButton("chevron.right", delta: 1)
                    Text("\(slots.filter { !$0.isWeekly }.count)")
                        .font(Theme.ui(10, weight: .bold))
                        .foregroundStyle(Theme.bg)
                        .frame(width: 29, height: 29)
                        .background(Theme.accent, in: Circle())
                }
            }

            if let comparisonLabel {
                HStack(spacing: 14) {
                    legendDot(Theme.accent, "\(ownerLabel) — editable")
                    legendDot(Theme.blue, "\(comparisonLabel) — saved")
                    Spacer()
                }
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, weekday in
                    Text(weekday)
                        .font(Theme.ui(9, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayButton(day)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }

            VStack(spacing: 8) {
                ForEach(AvailabilityPeriod.allCases) { period in
                    periodButton(period)
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
        .onAppear {
            guard slots.isEmpty,
                  let range = calendar.range(of: .day, in: .month, for: .now) else { return }
            let remainingDays = range.count - calendar.component(.day, from: .now)
            if remainingDays < 7,
               let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
               let nextMonthStart = calendar.date(
                   from: calendar.dateComponents([.year, .month], from: nextMonth)
               ) {
                displayedMonth = nextMonthStart
                selectedDate = nextMonthStart
            }
        }
    }

    private func monthButton(_ symbol: String, delta: Int) -> some View {
        let candidate = calendar.date(byAdding: .month, value: delta, to: monthStart) ?? monthStart
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        let disabled = candidate < currentMonth
        return Button {
            displayedMonth = candidate
            selectedDate = max(calendar.startOfDay(for: .now), candidate)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(disabled ? Theme.muted.opacity(0.3) : Theme.ink)
                .frame(width: 44, height: 44)
                .background(Theme.faint, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func dayButton(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let hasMine = slots.contains { !$0.isWeekly && calendar.isDate($0.date, inSameDayAs: day) }
        let hasTheirs = comparisonSlots.contains { !$0.isWeekly && calendar.isDate($0.date, inSameDayAs: day) }
        let isPast = day < calendar.startOfDay(for: .now)

        return Button {
            selectedDate = day
        } label: {
            ZStack(alignment: .bottom) {
                Text("\(calendar.component(.day, from: day))")
                    .font(Theme.ui(12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isPast ? Theme.muted.opacity(0.35) : (isSelected ? Theme.bg : Theme.ink))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        isSelected
                            ? Theme.accent
                            : (hasMine
                               ? Theme.accent.opacity(0.20)
                               : (hasTheirs ? Theme.blue.opacity(0.22) : Color.clear)),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .overlay {
                        if hasTheirs && !isSelected {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Theme.blue, lineWidth: 1.5)
                        }
                    }

                if !isSelected && (hasMine || hasTheirs) {
                    HStack(spacing: 2) {
                        if hasMine { Circle().fill(Theme.accent).frame(width: 4, height: 4) }
                        if hasTheirs { Circle().fill(Theme.blue).frame(width: 4, height: 4) }
                    }
                    .padding(.bottom, 3)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isPast)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(
            [
                day.formatted(date: .complete, time: .omitted),
                hasMine ? "\(ownerLabel) available" : nil,
                hasTheirs ? "\(comparisonLabel ?? "Other player") available" : nil
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
        )
    }

    private func periodButton(_ period: AvailabilityPeriod) -> some View {
        let isSelected = slots.contains {
            !$0.isWeekly && calendar.isDate($0.date, inSameDayAs: selectedDate) && $0.period == period
        }
        let isComparisonSelected = comparisonSlots.contains {
            !$0.isWeekly && calendar.isDate($0.date, inSameDayAs: selectedDate) && $0.period == period
        }

        return Button {
            if let index = slots.firstIndex(where: {
                !$0.isWeekly && calendar.isDate($0.date, inSameDayAs: selectedDate) && $0.period == period
            }) {
                slots.remove(at: index)
            } else {
                slots.append(AvailabilitySlot(date: selectedDate, period: period))
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(period.rawValue)
                    .font(Theme.ui(16, weight: .bold))
                Text(period.hours)
                    .font(Theme.ui(15, weight: .medium))
                if comparisonLabel != nil && (isSelected || isComparisonSelected) {
                    Text(ownershipLabel(isMine: isSelected, isTheirs: isComparisonSelected))
                        .font(Theme.ui(7, weight: .bold))
                        .textCase(.uppercase)
                        .lineLimit(1)
                }
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(isSelected || isComparisonSelected ? Theme.bg : Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: comparisonLabel == nil ? 64 : 70)
            .padding(.horizontal, 14)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(periodBackground(isMine: isSelected, isTheirs: isComparisonSelected))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isComparisonSelected ? Theme.blue : Theme.hairline, lineWidth: isComparisonSelected ? 2 : 1)
            )
        }
        .buttonStyle(SorbetScaleButtonStyle())
        .accessibilityLabel("\(period.rawValue), \(period.hours)")
        .accessibilityValue(ownershipLabel(isMine: isSelected, isTheirs: isComparisonSelected))
    }

    private func periodBackground(isMine: Bool, isTheirs: Bool) -> AnyShapeStyle {
        if isMine && isTheirs {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Theme.accent, Theme.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        if isMine { return AnyShapeStyle(Theme.accent) }
        if isTheirs { return AnyShapeStyle(Theme.blue) }
        return AnyShapeStyle(Theme.faint)
    }

    private func ownershipLabel(isMine: Bool, isTheirs: Bool) -> String {
        switch (isMine, isTheirs) {
        case (true, true): return "\(ownerLabel) + \(comparisonLabel ?? "them")"
        case (true, false): return ownerLabel
        case (false, true): return comparisonLabel ?? "Other player"
        case (false, false): return "Not selected"
        }
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 8)
            Text(text)
                .font(Theme.ui(9, weight: .bold))
                .foregroundStyle(Theme.ink.opacity(0.82))
        }
    }
}

struct AvailabilityPill: View {
    let slot: AvailabilitySlot?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: slot == nil ? "calendar.badge.exclamationmark" : "calendar.badge.checkmark")
                VStack(alignment: .leading, spacing: 1) {
                    Text(slot == nil ? "Compare availability" : "Next time everyone is free")
                        .font(Theme.ui(9, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.6)
                    Text(slot.map {
                        "\($0.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · \($0.period.hours)"
                    } ?? "Add or adjust times")
                        .font(Theme.ui(12, weight: .bold))
                }
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.caption.bold())
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(Theme.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.accent.opacity(0.65), lineWidth: 1))
        }
        .buttonStyle(SorbetScaleButtonStyle())
    }
}

struct MatchingAvailabilityStrip: View {
    let slots: [AvailabilitySlot]
    let onSelect: (AvailabilitySlot?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    slots.isEmpty ? "No matching times yet" : "Next times that work",
                    systemImage: "calendar.badge.checkmark"
                )
                .font(Theme.ui(10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(slots.isEmpty ? Theme.muted : Theme.accent)

                Spacer()

                Button {
                    onSelect(nil)
                } label: {
                    Label("Calendars", systemImage: "slider.horizontal.3")
                        .font(Theme.ui(9, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
            }

            if slots.isEmpty {
                Button {
                    onSelect(nil)
                } label: {
                    Text("Add your availability to find an overlap")
                        .font(Theme.ui(11, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Theme.faint, in: Capsule())
                }
                .buttonStyle(SorbetScaleButtonStyle())
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(slots) { slot in
                            Button {
                                onSelect(slot)
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(slot.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                        .font(Theme.ui(11, weight: .bold))
                                    Text(slot.period.hours)
                                        .font(Theme.ui(9))
                                }
                                .foregroundStyle(Theme.bg)
                                .padding(.horizontal, 13)
                                .frame(height: 43)
                                .background(Theme.accent, in: Capsule())
                            }
                            .buttonStyle(SorbetScaleButtonStyle())
                            .accessibilityHint("Review and propose this exact match time")
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hairline, lineWidth: 1))
    }
}

struct AvailabilityCoordinationSheet: View {
    let participantIds: [UUID]
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var mySlots: [AvailabilitySlot] = []
    @State private var mode: AvailabilityEditorMode = .everyWeek

    private var aligned: AvailabilitySlot? {
        app.nextAlignedAvailability(with: participantIds)
    }
    private var comparisonSlots: [AvailabilitySlot] {
        participantIds.compactMap { app.player($0)?.availability }.flatMap { $0 }
    }
    private var comparisonLabel: String {
        guard participantIds.count == 1,
              let player = participantIds.first.flatMap(app.player) else { return "Other players" }
        return player.name.split(separator: " ").first.map(String.init) ?? player.name
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Find the overlap")
                            .font(Theme.heading(28))
                        Text("Everyone owns their schedule. Match Point only highlights windows shared by the whole group.")
                            .font(Theme.ui(13))
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(3)
                    }

                    if let aligned {
                        HStack(spacing: 11) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Theme.bg)
                                .frame(width: 38, height: 38)
                                .background(Theme.accent, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NEXT SHARED OPENING")
                                    .font(Theme.ui(9, weight: .bold))
                                    .tracking(1)
                                Text("\(aligned.startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) · \(aligned.period.hours)")
                                    .font(Theme.heading(16))
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 20))
                    }

                    participantStrip

                    AvailabilityScheduleEditor(
                        slots: $mySlots,
                        mode: $mode,
                        comparisonSlots: comparisonSlots,
                        ownerLabel: "You",
                        comparisonLabel: comparisonLabel
                    )

                    Text("Mint + “You” marks your times. Blue + “\(comparisonLabel)” marks their times. Split mint/blue windows mean you are both free.")
                        .font(Theme.ui(11))
                        .foregroundStyle(Theme.ink.opacity(0.78))
                        .lineSpacing(3)
                }
                .padding(20)
            }
            .background(Theme.bg)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 9) {
                    Button {
                        app.updateMyAvailability(mySlots)
                        if let aligned = app.nextAlignedAvailability(with: participantIds) {
                            app.scheduleAlignedFaceOff(
                                participantIds: participantIds,
                                date: aligned.startDate,
                                wager: app.agreedWager(with: participantIds)
                            )
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text(aligned == nil ? "Save availability" : "Schedule shared time")
                            Spacer()
                            Image(systemName: aligned == nil ? "checkmark" : "calendar.badge.checkmark")
                        }
                        .font(Theme.ui(15, weight: .bold))
                        .foregroundStyle(Theme.bg)
                        .padding(.horizontal, 20)
                        .frame(height: 54)
                        .background(Theme.accent, in: Capsule())
                    }
                    .buttonStyle(SorbetScaleButtonStyle())

                    Button("Done") {
                        app.updateMyAvailability(mySlots)
                        dismiss()
                    }
                    .font(Theme.ui(12, weight: .bold))
                    .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.surface)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        app.updateMyAvailability(mySlots)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { mySlots = app.me.availability }
        .onChange(of: mySlots) { _, updated in
            app.updateMyAvailability(updated)
        }
    }

    private var participantStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CALENDARS IN THIS MATCH")
                .font(Theme.ui(10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    participantCard(name: "You", avatar: app.me.avatar, count: mySlots.count, isMe: true)
                    ForEach(participantIds, id: \.self) { id in
                        if let player = app.player(id) {
                            participantCard(
                                name: player.name.split(separator: " ").first.map(String.init) ?? player.name,
                                avatar: player.avatar,
                                count: player.availability.count,
                                isMe: false
                            )
                        }
                    }
                }
            }
        }
    }

    private func participantCard(name: String, avatar: Avatar, count: Int, isMe: Bool) -> some View {
        HStack(spacing: 8) {
            AvatarView(avatar: avatar, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(Theme.ui(11, weight: .bold))
                Text(isMe ? "Mint · tap below to edit" : "Blue · \(count) windows saved")
                    .font(Theme.ui(8))
                    .foregroundStyle(Theme.ink.opacity(0.74))
            }
        }
        .padding(9)
        .background(
            isMe ? Theme.accent.opacity(0.16) : Theme.blue.opacity(0.16),
            in: RoundedRectangle(cornerRadius: 15)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(isMe ? Theme.accent : Theme.blue, lineWidth: 1.5)
        )
    }
}

struct MatchTimeProposalSheet: View {
    let participantIds: [UUID]
    let slot: AvailabilitySlot
    let playerName: String
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var venue = "Zilker Courts"
    @State private var showUnratedWarning = false

    private var wager: String {
        app.agreedWager(with: participantIds)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Confirm this time")
                        .font(Theme.heading(27))
                    Text(
                        "You and \(playerName.split(separator: " ").first.map(String.init) ?? playerName) " +
                        "are both free in this window."
                    )
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.ink.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 13) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.bg)
                        .frame(width: 48, height: 48)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(slot.startDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(Theme.heading(16))
                        Text(slot.period.hours)
                            .font(Theme.ui(15, weight: .bold))
                            .foregroundStyle(Theme.ink.opacity(0.76))
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 7) {
                    Text("COURT / VENUE")
                        .font(Theme.ui(10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.ink.opacity(0.72))
                    TextField("Choose a court", text: $venue)
                        .font(Theme.ui(14))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 15))
                }

                HStack {
                    Label(
                        wager,
                        systemImage: wager == "No wager" ? "hand.raised.slash" : "checkmark.seal.fill"
                    )
                    .font(Theme.ui(12, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(wager == "No wager" ? "No wager agreed" : "Agreed in chat")
                        .font(Theme.ui(9, weight: .bold))
                        .foregroundStyle(Theme.ink.opacity(0.72))
                }
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))

                Spacer()

                Button {
                    if app.isRatingExempt(opponentIds: participantIds, sport: app.activeSport) {
                        showUnratedWarning = true
                    } else {
                        sendProposal()
                    }
                } label: {
                    HStack {
                        Text("Send match proposal")
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
            }
            .padding(20)
            .background(Theme.bg)
            .navigationTitle("Match time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseIconButton { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showUnratedWarning) {
            UnratedInviteConfirmationSheet(name: playerName, sport: app.activeSport) {
                sendProposal()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.bg)
        }
    }

    private func sendProposal() {
        app.scheduleAlignedFaceOff(
            participantIds: participantIds,
            date: slot.startDate,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "TBD" : venue,
            wager: wager
        )
        dismiss()
    }
}

struct ProfileAvailabilitySheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var slots: [AvailabilitySlot] = []
    @State private var mode: AvailabilityEditorMode = .everyWeek

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your play windows")
                        .font(Theme.heading(28))
                    Text("Keep this current and every conversation can surface the next shared opening automatically.")
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.muted)
                    AvailabilityScheduleEditor(slots: $slots, mode: $mode)
                }
                .padding(20)
            }
            .background(Theme.bg)
            .safeAreaInset(edge: .bottom) {
                Button {
                    app.updateMyAvailability(slots)
                    dismiss()
                } label: {
                    HStack {
                        Text("Save availability")
                        Spacer()
                        Text("\(slots.count) windows")
                        Image(systemName: "checkmark")
                    }
                    .font(Theme.ui(14, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 19)
                    .frame(height: 54)
                    .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(SorbetScaleButtonStyle())
                .padding(16)
                .background(Theme.surface)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseIconButton { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { slots = app.me.availability }
    }
}
