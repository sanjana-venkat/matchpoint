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
                        Stepper("\(me.age) years", value: $me.age, in: 13...99)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gender").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        Picker("Gender", selection: $me.gender) {
                            ForEach(Gender.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
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
            content().padding().background(Color(.secondarySystemBackground),
                                            in: RoundedRectangle(cornerRadius: 12))
        }
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
