import SwiftUI

// Onboarding — cast co-creation. Reference: design_refs/2g-onboarding.html +
// README §Screens.7. One question per screen, progress dots top-right.
// Step 3 (persona pick) is the fully mocked step; steps 1–2 (hard rules,
// favorite colors) are lightweight preceding questions in the same system.
// Placeholder cast from the mock (Peach/Grandma Greens/Mr. Kettle) is replaced
// with the authoritative personas: Hannah / Cat / Julie.

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Called when onboarding finishes — both "add to the cast" and skip.
    var onDone: (() -> Void)? = nil

    @State private var step = 0
    @State private var selectedPersonaID = "hannah"
    @State private var personaName = "Hannah"
    /// Local until commit — written to appState.sassLevel on continue.
    @State private var sassLevel: Double = 6.2   // 0 mild … 10 full chaos

    /// Dots show 4: the 3 built steps + the rest of the flow (stressor
    /// interview, meal swipe-rating) that lives beyond this mock.
    private let totalDots = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Group {
                switch step {
                case 0: hardRulesStep
                case 1: colorsStep
                default: personaStep
                }
            }
            .transition(stepTransition)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.shelf.ignoresSafeArea())
    }

    // MARK: Header (fixed across steps — navigation never moves)

    private var header: some View {
        HStack {
            OnboardingCapsLabel(text: "BUILDING YOUR CAST")
            Spacer()
            OnboardingProgressDots(current: step, total: totalDots)
        }
    }

    // MARK: Step 1 — household hard requirements (celiac safety FIRST)

    private var hardRulesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            OnboardingTitleBlock(
                title: "The household's in.\nWho has hard rules?",
                subtitle: "celiac safety comes FIRST — hard rules get solved before taste, effort, or vibes. these three carry guarantees:")

            VStack(spacing: 9) {
                OnboardingRequirementRow(
                    member: appState.member("caddie"),
                    headline: "Caddie — celiac",
                    detail: "safety, not a preference. solved first.",
                    badgeText: "Caddie GF ✓", badgeSlot: Palette.green,
                    emphasized: true)
                OnboardingRequirementRow(
                    member: appState.member("elsie"),
                    headline: "Elsie — safe foods",
                    detail: "her plain option always exists.",
                    badgeText: "Elsie plain ✓", badgeSlot: Palette.blue)
                OnboardingRequirementRow(
                    member: appState.member("chad"),
                    headline: "Chad — volume",
                    detail: "double batch. growing-boy math.",
                    badgeText: "Chad ×2 ✓", badgeSlot: Palette.yellow)
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Button("LOCKED IN — SAFETY FIRST") { advance(from: 0) }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                Text("adjust anytime — the week re-solves around safety")
                    .font(.nunito(12, .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Step 2 — favorite colors (fills the 5 palette slots)

    private var colorsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            OnboardingTitleBlock(
                title: "Rules locked.\nWhich colors are yours?",
                subtitle: "your favorites fill 5 slots — confetti, magnets, and celebrations sample them all year.")

            HStack(spacing: 8) {
                ForEach(Array(Palette.slots.enumerated()), id: \.element.id) { entry in
                    OnboardingPaletteSlotTile(slot: entry.element, index: entry.offset)
                }
            }

            Text("Ria's five shown — every slot takes any color you love.")
                .font(.nunito(12, .heavy))
                .foregroundStyle(Theme.textSecondary)

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Button("KEEP THESE FIVE") { advance(from: 1) }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                Text("swap any slot later — the app re-paints itself")
                    .font(.nunito(12, .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Step 3 — someone imaginary (the mocked step)

    private var candidates: [OnboardingPersonaCandidate] {
        [("hannah", "snarky best friend", "\u{201C}you fed FIVE humans. i\u{2019}m framing this.\u{201D}"),
         ("cat", "chef · best-aunt energy", "\u{201C}warm the tortillas 30 sec a side. game changer.\u{201D}"),
         ("julie", "ND · whip-smart", "\u{201C}task re-initiation costs more dopamine than the task.\u{201D}")]
            .map { id, role, sample in
                let p = appState.persona(id)
                return OnboardingPersonaCandidate(
                    id: id, title: "\(p.name) — \(role)", name: p.name, sample: sample,
                    blobColor: p.slot.color, blobVariant: p.blobVariant)
            }
    }

    private var displayName: String {
        let trimmed = personaName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return candidates.first { $0.id == selectedPersonaID }?.name ?? "Hannah"
        }
        return trimmed
    }

    private var personaStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            OnboardingTitleBlock(
                title: "Chuck + the kids are in.\nNow: someone imaginary.",
                subtitle: "fictional cast members text like people, remember everything, and never get tired of you.")

            VStack(spacing: 9) {
                ForEach(candidates) { candidate in
                    OnboardingPersonaCard(
                        candidate: candidate,
                        isSelected: candidate.id == selectedPersonaID) {
                            selectedPersonaID = candidate.id
                            personaName = candidate.name
                        }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                OnboardingCapsLabel(text: "NAME (OR KEEP IT)")
                nameField
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    OnboardingCapsLabel(text: "MILD")
                    Spacer()
                    OnboardingCapsLabel(text: "SASS")
                    Spacer()
                    OnboardingCapsLabel(text: "FULL CHAOS")
                }
                OnboardingSassSlider(value: $sassLevel)
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Button("ADD \(displayName.uppercased()) TO THE CAST") {
                    appState.sassLevel = sassLevel
                    onDone?()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())

                Button {
                    onDone?()
                } label: {
                    Text("or skip — the cast works at any size")
                        .font(.nunito(12, .heavy))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Ink-border pill name field with voice glyph (law 1: voice on every input).
    /// Mock (2g line 34) specifies border-radius:999px — a full pill.
    private var nameField: some View {
        HStack(spacing: 8) {
            TextField("name your person", text: $personaName)
                .font(.nunito(15, .black))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            Button {
                // Voice entry — wired to dictation later; affordance ships in v1.
            } label: {
                OnboardingMicGlyph()
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dictate a name")
        }
        .padding(.leading, 16)
        .padding(.trailing, 2)
        .frame(minHeight: 52)
        .inkCard(background: Theme.paper, radius: Theme.Radius.pill)
    }

    // MARK: Step transition (≤250ms ease-out; Reduce Motion → opacity only)

    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                          removal: .move(edge: .leading).combined(with: .opacity))
    }

    /// The outgoing button stays tappable during the 250ms slide, so a fast
    /// double-tap could fire twice and skip a step. Each button passes the
    /// step it belongs to; a stale tap (step already moved on) is ignored,
    /// and the clamp keeps `step` inside the built range regardless.
    private func advance(from currentStep: Int) {
        guard step == currentStep else { return }
        withAnimation(.easeOut(duration: 0.25)) { step = min(step + 1, 2) }
    }
}

// MARK: - Persona candidate (screen-local; voices per README §The Cast)

private struct OnboardingPersonaCandidate: Identifiable {
    let id: String
    let title: String       // "Hannah — snarky best friend"
    let name: String
    let sample: String      // one line in their real voice
    let blobColor: Color
    let blobVariant: Int
}

private struct OnboardingPersonaCard: View {
    var candidate: OnboardingPersonaCandidate
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                BlobAvatar(color: candidate.blobColor, variant: candidate.blobVariant, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.title)
                        .font(.nunito(15, .black))
                        .foregroundStyle(Theme.ink)
                    Text(candidate.sample)
                        .font(.nunito(12, .heavy))
                        .foregroundStyle(isSelected ? Palette.pink.labelMuted : Theme.textSecondary)
                        .lineLimit(2)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isSelected {
                    Text("✓")
                        .font(.nunito(12, .black))
                        .foregroundStyle(Theme.paper)
                        .frame(width: 24, height: 24)
                        .background(Theme.ink, in: Circle())
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .inkCard(background: isSelected ? Palette.pink.tintAlt : Theme.paper, radius: 18)
            .hardShadow(isSelected ? Palette.pink.color : .clear, x: 4, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Hard-requirement row (step 1)

private struct OnboardingRequirementRow: View {
    var member: HouseholdMember
    var headline: String
    var detail: String
    var badgeText: String
    var badgeSlot: PaletteSlot
    var emphasized: Bool = false   // Caddie: celiac safety FIRST

    var body: some View {
        HStack(spacing: 11) {
            BlobAvatar(color: member.blobColor, variant: member.blobVariant, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.nunito(15, .black))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.nunito(12, .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            SafetyBadge(text: badgeText, slot: badgeSlot)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inkCard(background: emphasized ? Palette.green.tint : Theme.paper, radius: 18)
        .hardShadow(emphasized ? Palette.green.color : .clear, x: 4, y: 4)
    }
}

// MARK: - Palette slot tile (step 2 — the 5 slots, law 6)

private struct OnboardingPaletteSlotTile: View {
    var slot: PaletteSlot
    var index: Int

    var body: some View {
        VStack(spacing: 7) {
            Circle()
                .fill(slot.color)
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
                .frame(width: 34, height: 34)
            Text("\(index + 1)")
                .font(.nunito(11, .black))
                .foregroundStyle(slot.label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .inkCard(background: slot.tint, radius: Theme.Radius.sticker)
    }
}

// MARK: - Sass slider (yellow fill, chunky ink-border thumb, hard shadow)

private struct OnboardingSassSlider: View {
    @Binding var value: Double   // 0 mild … 10 full chaos

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let frac = CGFloat(min(max(value / 10, 0), 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.paper)
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
                    .frame(height: 16)
                Capsule()
                    .fill(Palette.yellow.color)
                    .frame(width: max(frac * width - 4, 12), height: 12)
                    .padding(.leading, 2)
                    .opacity(frac > 0.02 ? 1 : 0)
                Circle()
                    .fill(Theme.paper)
                    .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
                    .frame(width: 26, height: 26)
                    .hardShadow(Theme.ink, x: 2, y: 2)
                    .position(x: min(max(frac * width, 13), width - 13),
                              y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        value = min(max(Double(g.location.x / width) * 10, 0), 10)
                    }
            )
        }
        .frame(height: 48)   // law 1: ≥48pt hit target
        .accessibilityRepresentation {
            Slider(value: $value, in: 0...10) { Text("Sass level") }
        }
    }
}

// MARK: - Small shared pieces

private struct OnboardingTitleBlock: View {
    var title: String
    var subtitle: String

    /// Baloo 2 at 27pt renders ~43pt baseline-to-baseline; the mock wants
    /// ~30px (line-height 1.1). SwiftUI's .lineSpacing can't go negative, so
    /// the title is split on "\n" and stacked per-line with negative VStack
    /// spacing to pull baselines ~30pt apart. Single-line titles render in a
    /// one-child VStack, so spacing never applies to them.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: -12) {
                ForEach(Array(title.components(separatedBy: "\n").enumerated()),
                        id: \.offset) { _, line in
                    Text(line)
                        .font(.baloo(27, .heavy))
                        .foregroundStyle(Theme.ink)
                }
            }
            .accessibilityElement(children: .combine)
            Text(subtitle)
                .font(.nunito(13, .bold))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

private struct OnboardingCapsLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.nunito(11, .black))
            .kerning(0.9)
            .foregroundStyle(Theme.textSecondary)
    }
}

private struct OnboardingProgressDots: View {
    var current: Int
    var total: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < current ? Palette.green.color
                          : (i == current ? Palette.yellow.color : Theme.paper))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(
                        i <= current ? Theme.ink : Theme.textDisabled,
                        lineWidth: Theme.borderWidth))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

/// Drawn mic glyph (no icon font — matches the mock's CSS mic).
private struct OnboardingMicGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.shelf)
                .frame(width: 34, height: 34)
            VStack(spacing: 0) {
                Capsule()
                    .strokeBorder(Theme.ink, lineWidth: Theme.borderWidth)
                    .frame(width: 9, height: 13)
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: 2, height: 4)
            }
        }
    }
}

/// Primary onboarding pill — pink, ink border, 4×4 ink hard shadow (per mock).
private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.baloo(18, .heavy))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .inkCard(background: Palette.pink.color, radius: Theme.Radius.pill)
            .hardShadow(Theme.ink, x: 4, y: 4)
            .offset(x: configuration.isPressed ? 2 : 0,
                    y: configuration.isPressed ? 2 : 0)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
