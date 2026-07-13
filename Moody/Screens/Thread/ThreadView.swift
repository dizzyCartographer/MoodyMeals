import SwiftUI

// GROUP THREAD — pixel-faithful build of design_refs/2f-thread.html
// (voice/card reference: design_refs/4abc-persona-notes.html, README §Screens.6).
// Placeholder cast (Peach/Grandma Greens/Mr. Kettle, Dev) → authoritative cast:
// Hannah (snark-warm), Cat (chef tips), Julie (ND reality-reminders), Chuck (family).
// iMessage-adjacent and zero-pressure: NO unread counts, NO reply nagging —
// "lurking counts as participating ✓".

private let threadMutedText = Color(hex: 0xB3A9BE)

struct ThreadView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = ""

    private let quickReplies = ["on it 🌮", "chaos accepted", "brb crying (affectionate)"]

    var body: some View {
        VStack(spacing: 0) {
            ThreadHeaderBanner(persona: bannerPersona)
                .padding(.bottom, 18)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(appState.thread.enumerated()), id: \.element.id) { index, message in
                            ThreadMessageRow(message: message,
                                             info: authorInfo(for: message.author),
                                             showsRole: showsRole(at: index))
                                .id(message.id)
                        }
                        quickReplyRow
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 12)
                }
                .onAppear { scrollToBottom(proxy, animated: false) }
                .onChange(of: appState.thread.count) {
                    scrollToBottom(proxy, animated: !reduceMotion)
                }
            }

            // D-48: zero response debt is carried by the design (no unread
            // counts, no nagging) — announcing it in app voice converts it
            // into an expectation. (Footer removed; spacing kept.)
            Spacer().frame(height: 14)

            composer
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.shelf.ignoresSafeArea())
    }

    // MARK: Banner

    /// Header spotlights whoever delivered the "moment" (Hannah in the demo).
    private var bannerPersona: Persona {
        for message in appState.thread {
            if case .persona(let id) = message.author, message.kind == .moment {
                return appState.persona(id)
            }
        }
        return appState.personas[0]
    }

    // MARK: Author resolution (personas + real family coexist, README §Screens.6)

    private func authorInfo(for author: ThreadMessage.Author) -> ThreadAuthorInfo? {
        switch author {
        case .persona(let id):
            let p = appState.persona(id)
            return ThreadAuthorInfo(name: p.name,
                                    role: ThreadView.roleTag(forPersona: id),
                                    nameColor: p.slot.label,
                                    blobColor: p.slot.color,
                                    blobVariant: p.blobVariant,
                                    isFamily: false)
        case .family(let id):
            let m = appState.member(id)
            let slot = Palette.slots.first { $0.color == m.blobColor }
            return ThreadAuthorInfo(name: m.name,
                                    role: "the real one",
                                    nameColor: slot?.label ?? Theme.textSecondary,
                                    blobColor: m.blobColor,
                                    blobVariant: m.blobVariant,
                                    isFamily: true)
        case .ria:
            return nil // Ria renders right-aligned, no avatar/name
        }
    }

    /// Short thread handles in each persona's register (README §The Cast).
    private static func roleTag(forPersona id: String) -> String {
        switch id {
        case "hannah": return "house morale"     // snarky best friend, spot-on
        case "cat": return "chef things"          // technique tips, aunt energy
        case "julie": return "comeback dept"      // notices comebacks fast
        default: return "the cast"
        }
    }

    /// Ref shows the role tag on an author's first bubble, name-only after.
    private func showsRole(at index: Int) -> Bool {
        let author = appState.thread[index].author
        return !appState.thread[..<index].contains { $0.author == author }
    }

    // MARK: Quick replies (right-aligned; tap = a Ria message, appended locally)

    private var quickReplyRow: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 8) {
                quickReplyPill(quickReplies[0])
                quickReplyPill(quickReplies[1])
            }
            quickReplyPill(quickReplies[2])
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 4)
        .id("quickReplies")
    }

    private func quickReplyPill(_ text: String) -> some View {
        Button {
            appendFromRia(text)
        } label: {
            Text(text)
                .font(.nunito(12.5, .black))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 48) // law 1: ≥48pt hit targets
                .inkCard(background: Theme.paper, radius: Theme.Radius.pill)
        }
        .buttonStyle(.plain)
    }

    // MARK: Composer ("reply if you feel like it" — no pressure, voice on every input)

    private var composer: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                if draft.isEmpty {
                    Text("reply if you feel like it")
                        .font(.nunito(13.5, .bold))
                        .foregroundStyle(threadMutedText)
                        .allowsHitTesting(false)
                }
                TextField("", text: $draft)
                    .font(.nunito(13.5, .bold))
                    .foregroundStyle(Theme.ink)
                    .submitLabel(.send)
                    .onSubmit(sendDraft)
                    // The visible placeholder is a decorative Text (styled to
                    // match the ref), so VoiceOver needs the title here.
                    .accessibilityLabel("reply if you feel like it")
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.paper, in: Capsule())
            .shadow(color: Theme.ink.opacity(0.06), radius: 5, x: 0, y: 2)

            Button(action: sendDraft) {
                ZStack {
                    Circle()
                        .fill(Theme.ink)
                        .frame(width: 46, height: 46)
                    ThreadMicGlyph()
                }
                .frame(width: 48, height: 48) // ≥48pt target around the 46px ref circle
            }
            .buttonStyle(.plain)
            // The circle does double duty: mic with an empty draft, send once
            // there's text — the label tracks what a tap actually does.
            .accessibilityLabel(draft.isEmpty ? "Voice reply" : "Send")
        }
    }

    // MARK: Local appends

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        appendFromRia(text)
    }

    private func appendFromRia(_ text: String) {
        let message = ThreadMessage(author: .ria, text: text)
        if reduceMotion {
            appState.thread.append(message)
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                appState.thread.append(message)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        // Target the quick-reply row (the true bottom of the scroll content) so
        // the pills are never clipped below the fold when we land on the thread.
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("quickReplies", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("quickReplies", anchor: .bottom)
        }
    }
}

// MARK: - Header banner (ink pill: "HANNAH · Dinner Cabinet / get in here. it's important.")

private struct ThreadHeaderBanner: View {
    var persona: Persona

    var body: some View {
        HStack(spacing: 10) {
            BlobAvatar(color: persona.slot.color, variant: persona.blobVariant, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(persona.name.uppercased()) · Dinner Cabinet")
                    .font(.nunito(12, .black))
                    .foregroundStyle(.white)
                Text("the cabinet's open whenever.")   // D-55: invite, never summon
                    .font(.nunito(12.5, .bold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("now")
                .font(.nunito(10.5, .heavy))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .background(Theme.ink.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

// MARK: - Message row

private struct ThreadAuthorInfo {
    var name: String
    var role: String
    var nameColor: Color
    var blobColor: Color
    var blobVariant: Int
    var isFamily: Bool
}

private struct ThreadMessageRow: View {
    var message: ThreadMessage
    var info: ThreadAuthorInfo? // nil = Ria (right-aligned, no avatar)
    var showsRole: Bool

    var body: some View {
        if let info {
            HStack(alignment: .top, spacing: 9) {
                avatar(for: info)
                VStack(alignment: .leading, spacing: 0) {
                    Text(showsRole ? "\(info.name) · \(info.role)" : info.name)
                        .font(.nunito(11.5, .black))
                        .foregroundStyle(info.nameColor)
                        .padding(.leading, 4)
                        .padding(.bottom, 3)
                    ThreadBubble(message: message, info: info)
                    if !message.tapbacks.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(Array(message.tapbacks.enumerated()), id: \.offset) { i, tapback in
                                ThreadTapbackChip(text: tapback, index: i)
                            }
                        }
                        .padding(.top, 7)
                        .padding(.leading, 8)
                    }
                }
                Spacer(minLength: 24)
            }
        } else {
            HStack(spacing: 0) {
                Spacer(minLength: 60)
                Text(message.text)
                    .font(.nunito(14, .heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                    .background(Palette.pink.tint, in: ThreadBubble.riaShape)
                    .frame(maxWidth: 280, alignment: .trailing)
            }
        }
    }

    /// Real humans read as flat solid circles with an initial (mock) — no face,
    /// no ink border. Personas keep the drawn BlobAvatar.
    @ViewBuilder
    private func avatar(for info: ThreadAuthorInfo) -> some View {
        if info.isFamily {
            ZStack {
                Circle().fill(info.blobColor)
                Text(String(info.name.prefix(1)).uppercased())
                    .font(.nunito(12, .black))
                    .foregroundStyle(.white)
            }
            .frame(width: 31, height: 31)
        } else {
            BlobAvatar(color: info.blobColor, variant: info.blobVariant, size: 34)
        }
    }
}

// MARK: - Bubbles (moment = paper + ink border + hard shadow · aside = tint · normal = quiet paper)

private struct ThreadBubble: View {
    var message: ThreadMessage
    var info: ThreadAuthorInfo

    // border-radius: 4px 18px 18px 18px (ref), mirrored for Ria
    static let shape = UnevenRoundedRectangle(topLeadingRadius: 4,
                                              bottomLeadingRadius: 18,
                                              bottomTrailingRadius: 18,
                                              topTrailingRadius: 18,
                                              style: .continuous)
    static let riaShape = UnevenRoundedRectangle(topLeadingRadius: 18,
                                                 bottomLeadingRadius: 18,
                                                 bottomTrailingRadius: 18,
                                                 topTrailingRadius: 4,
                                                 style: .continuous)

    var body: some View {
        Group {
            switch message.kind {
            case .moment:
                Text(message.text)
                    .font(.nunito(14.5, .heavy))
                    .lineSpacing(1) // mock: 14.5px × 1.45 ≈ 21px pitch; the face already has ~20pt line height
                    .foregroundStyle(Theme.ink)
                    .padding(EdgeInsets(top: 12, leading: 15, bottom: 12, trailing: 15))
                    .background(Theme.paper)
                    .clipShape(Self.shape)
                    .overlay(Self.shape.strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
                    .hardShadow(Palette.yellow.color, x: 3, y: 3)
            case .aside:
                Text(message.text)
                    .font(.nunito(14, .heavy))
                    .lineSpacing(3)
                    .foregroundStyle(Theme.ink)
                    .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                    .background(asideTint, in: Self.shape)
            case .normal:
                Text(message.text)
                    .font(.nunito(14, info.isFamily ? .bold : .heavy))
                    .lineSpacing(3)
                    .foregroundStyle(Theme.ink)
                    .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                    .background(Theme.paper, in: Self.shape)
                    .shadow(color: Theme.ink.opacity(0.07), radius: 5, x: 0, y: 2)
            }
        }
        .frame(maxWidth: 280, alignment: .leading)
    }

    /// Aside bubbles sit on the author's own tint (yellow for family, per ref).
    private var asideTint: Color {
        if info.isFamily { return Palette.yellow.tintAlt }
        return Palette.slots.first { $0.color == info.blobColor }?.tint ?? Palette.yellow.tintAlt
    }
}

// MARK: - Tapback chip (♥ 2 on pink tint, ★ Chuck on yellow tint — ref colors)

private struct ThreadTapbackChip: View {
    var text: String
    var index: Int

    private static let tints: [Color] = [Palette.pink.tintAlt, Palette.yellow.tint,
                                         Palette.green.tint, Palette.blue.tint]

    var body: some View {
        Text(text)
            .font(.nunito(11, .black))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .inkCard(background: Self.tints[index % Self.tints.count],
                     radius: Theme.Radius.pill)
    }
}

// MARK: - Mic glyph (drawn: 12×17 capsule outline + stem, shelf color on ink)

private struct ThreadMicGlyph: View {
    var body: some View {
        VStack(spacing: 2) {
            Capsule()
                .strokeBorder(Theme.shelf, lineWidth: 2.5)
                .frame(width: 12, height: 17)
            Rectangle()
                .fill(Theme.shelf)
                .frame(width: 2.5, height: 5)
        }
    }
}

#Preview {
    ThreadView()
        .environmentObject(AppState())
}
