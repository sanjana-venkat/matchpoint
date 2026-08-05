import SwiftUI

/// Renders a single chat message. Text, attachments, challenges and face-off
/// cards each get their own styling.
struct MessageBubble: View {
    let message: ChatMessage
    let player: Player?
    let sport: Sport
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack {
            if message.fromMe { Spacer(minLength: 40) }
            content
            if !message.fromMe { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder private var content: some View {
        switch message.kind {
        case .text(let t):
            bubble { Text(t) }
        case .image:
            bubble {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 160, height: 110)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
            }
        case .location(let name):
            bubble {
                Label(name, systemImage: "mappin.circle.fill")
            }
        case .system(let s):
            Text(s).font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        case .challenge(let c):
            challengeCard(c)
        case .faceOff(let fo):
            faceOffCard(fo)
        }
    }

    private func bubble<Content: View>(@ViewBuilder _ inner: () -> Content) -> some View {
        inner()
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(message.fromMe ? Theme.color(for: sport) : Theme.surface)
            .foregroundStyle(message.fromMe ? Theme.bg : Theme.ink)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 20,
                    bottomLeadingRadius: message.fromMe ? 20 : 5,
                    bottomTrailingRadius: message.fromMe ? 5 : 20,
                    topTrailingRadius: 20
                )
            )
            .overlay {
                UnevenRoundedRectangle(
                    topLeadingRadius: 20,
                    bottomLeadingRadius: message.fromMe ? 20 : 5,
                    bottomTrailingRadius: message.fromMe ? 5 : 20,
                    topTrailingRadius: 20
                )
                .stroke(Theme.ink, lineWidth: 2.5)
            }
    }

    private func challengeCard(_ c: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Challenge", systemImage: "flag.checkered").font(.caption.bold())
            Text("Wager: \(c.wager)").font(.subheadline.weight(.semibold))
            if !c.note.isEmpty { Text(c.note).font(.caption).opacity(0.9) }
        }
        .padding(12)
        .frame(maxWidth: 240, alignment: .leading)
        .background(Theme.pink)
        .foregroundStyle(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 21))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(Theme.ink, lineWidth: 3))
    }

    private func faceOffCard(_ fo: FaceOff) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Face-off confirmed", systemImage: "calendar.badge.checkmark").font(.caption.bold())
            Text(fo.date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.weight(.semibold))
            Label(fo.venue, systemImage: "mappin.and.ellipse").font(.caption)
            if !fo.wager.isEmpty { Label("Wager: \(fo.wager)", systemImage: "gift").font(.caption) }
        }
        .padding(12)
        .frame(maxWidth: 250, alignment: .leading)
        .foregroundStyle(Theme.bg)
        .background(Theme.lime)
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(Theme.ink, lineWidth: 3))
        .clipShape(RoundedRectangle(cornerRadius: 21))
    }
}
