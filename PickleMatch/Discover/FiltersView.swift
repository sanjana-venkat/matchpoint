import SwiftUI

/// Filter the discover deck by distance, rating, partner status, equipment and
/// tournament history.
struct FiltersView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = DiscoverFilters()

    var body: some View {
        NavigationStack {
            Form {
                Section("Distance") {
                    VStack(alignment: .leading) {
                        Text("Within \(Int(draft.maxDistance)) miles")
                            .font(.subheadline.weight(.semibold))
                        Slider(value: $draft.maxDistance, in: 1...25, step: 1)
                    }
                }

                Section("Skill rating") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(Int(draft.ratingRange.lowerBound)) – \(Int(draft.ratingRange.upperBound))")
                            .font(.subheadline.weight(.semibold))
                        RangeSlider(range: $draft.ratingRange, bounds: 0...200)
                            .frame(height: 30)
                    }
                }

                Section("Partner status") {
                    ForEach(PartnerStatus.allCases) { status in
                        Toggle(isOn: Binding(
                            get: { draft.partnerStatuses.contains(status) },
                            set: { on in
                                if on { draft.partnerStatuses.insert(status) }
                                else { draft.partnerStatuses.remove(status) }
                            }
                        )) {
                            Label(status.rawValue, systemImage: status.systemImage)
                        }
                        .tint(app.themeColor)
                    }
                }

                Section("Other") {
                    Toggle("Has own equipment", isOn: $draft.requireEquipment).tint(app.themeColor)
                    Toggle("Tournament players only", isOn: $draft.tournamentsOnly).tint(app.themeColor)
                }

                Section {
                    Button("Reset all filters", role: .destructive) { draft.reset() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .foregroundStyle(Theme.ink)
            .tint(Theme.grape)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseIconButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        app.filters = draft
                        app.resetDeck()
                        dismiss()
                    }.fontWeight(.semibold)
                }
            }
            .onAppear { draft = app.filters }
        }
    }
}

/// Minimal two-thumb range slider (SwiftUI has no built-in one).
struct RangeSlider: View {
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let span = bounds.upperBound - bounds.lowerBound
            let lowX = CGFloat((range.lowerBound - bounds.lowerBound) / span) * width
            let highX = CGFloat((range.upperBound - bounds.lowerBound) / span) * width

            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.25)).frame(height: 4)
                Capsule().fill(Theme.grape)
                    .frame(width: max(0, highX - lowX), height: 4)
                    .offset(x: lowX)
                thumb.offset(x: lowX - 11).gesture(drag(isLower: true, width: width, span: span))
                thumb.offset(x: highX - 11).gesture(drag(isLower: false, width: width, span: span))
            }
            .frame(height: 30)
        }
    }

    private var thumb: some View {
        Circle().fill(Theme.surface)
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(Theme.ink, lineWidth: 3))
    }

    private func drag(isLower: Bool, width: CGFloat, span: Double) -> some Gesture {
        DragGesture().onChanged { value in
            let ratio = min(1, max(0, value.location.x / width))
            let v = (bounds.lowerBound + ratio * span).rounded()
            if isLower {
                range = min(v, range.upperBound - 1)...range.upperBound
            } else {
                range = range.lowerBound...max(v, range.lowerBound + 1)
            }
        }
    }
}
