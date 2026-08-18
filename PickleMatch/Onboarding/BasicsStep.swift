import SwiftUI

/// Collects name, gender, age and avatar before sports are chosen.
struct BasicsStep: View {
    @Binding var me: Player
    let onContinue: () -> Void

    private var isValid: Bool { !me.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    StepHeader(title: "About you", subtitle: "This is how other players will see you.")

                    // Selected avatar preview
                    HStack {
                        Spacer()
                        AvatarView(avatar: me.avatar, size: 96)
                        Spacer()
                    }

                    field("Name") {
                        TextField("Your name", text: $me.name)
                            .textInputAutocapitalization(.words)
                    }

                    field("Age") {
                        HStack {
                            Text("\(me.age) years").font(RallyType.meta)
                            Spacer()
                            ageButton("minus") { me.age = max(13, me.age - 1) }
                            ageButton("plus") { me.age = min(99, me.age + 1) }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gender").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        MinimalChoiceBar(
                            options: Gender.allCases.map(\.rawValue),
                            selection: Binding(
                                get: { me.gender.rawValue },
                                set: { value in
                                    if let gender = Gender.allCases.first(where: { $0.rawValue == value }) {
                                        me.gender = gender
                                    }
                                }
                            )
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Choose an avatar").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        AvatarPicker(selection: $me.avatar)
                    }
                }
                .padding()
            }
            PrimaryButton(title: "Continue", enabled: isValid, action: onContinue)
                .padding()
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            content().padding().background(Theme.surface2, in: Capsule())
        }
    }

    private func ageButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(RallyPalette.cream)
                .frame(width: 42, height: 42)
                .background(RallyPalette.ink, in: Circle())
        }
        .buttonStyle(RallyPressStyle())
    }
}

/// Grid of selectable avatars.
struct AvatarPicker: View {
    @Binding var selection: Avatar
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Avatar.all) { avatar in
                AvatarView(avatar: avatar, size: 64)
                    .overlay(
                        Circle().strokeBorder(Theme.accent, lineWidth: selection == avatar ? 4 : 0)
                    )
                    .scaleEffect(selection == avatar ? 1.05 : 1)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) { selection = avatar }
                    }
            }
        }
    }
}
