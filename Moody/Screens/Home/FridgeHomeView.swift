import SwiftUI

// THE FRIDGE — home screen.
// Pixel-authoritative reference: design_refs/home-fridge-door.html (px → pt 1:1),
// spec: design_handoff_moody_app/README.md §Screens.1.
//
// The home screen is a fridge door: tonight's plan pinned under a magnet,
// sticky notes from the cast, the week as a row of magnets, and a 3-option
// tank check pinned to the bottom. Long-press the door itself to open the Vent
// (README §Screens.5 — reachable in one press from anywhere, v1 spec).

struct FridgeHomeView: View {
    @EnvironmentObject var appState: AppState

    // Navigation wiring happens later — never reference other screens' types.
    var onOpenThread: (() -> Void)? = nil
    var onOpenStreaks: (() -> Void)? = nil
    var onOpenWeek: (() -> Void)? = nil
    var onOpenShopping: (() -> Void)? = nil
    var onOpenMeals: (() -> Void)? = nil   // B-1: the library door
    var onOpenVent: (() -> Void)? = nil
    /// Fired after decide-for-me commits — the everyday win (celebration wiring).
    var onWin: (() -> Void)? = nil

    @State private var showSwapSheet = false
    /// Snapshot of the 3 swap alternatives, taken when the sheet opens.
    /// Rendering appState.swapOptions() live would reshuffle the rows the
    /// moment commitTonight() changes state, mid-dismiss.
    @State private var swapChoices: [Meal] = []

    var body: some View {
        VStack(spacing: Theme.Space.m) {   // mockup: flex column, gap 12
            header
            tonightCard
            stickyNotes
            weekMagnets
            Spacer(minLength: 0)
            bottomPinned                    // mockup: margin-top auto
        }
        .padding(.top, 8)
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Theme.fridge
                .ignoresSafeArea()
                .onLongPressGesture(minimumDuration: 0.6) { onOpenVent?() }
        )
        .sheet(isPresented: $showSwapSheet) { swapSheet }
        // The long-press on the door is invisible to VoiceOver/Switch Control —
        // expose the Vent as a rotor action on the screen itself (v1 spec:
        // reachable in one press from anywhere).
        .accessibilityAction(named: "Open the Vent") { onOpenVent?() }
    }

    // MARK: - Header ("The Fridge" + 3 decorative magnet dots)

    private var header: some View {
        HStack {
            Text("The Fridge")
                .font(.baloo(26, .heavy))
                .foregroundStyle(Theme.ink)
            Spacer()
            // B-1: the meal library door — quiet chip, kit register.
            Button { onOpenMeals?() } label: {
                Text("meals")
                    .font(.nunito(11.5, .black))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Theme.paper, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
                    .hardShadow(Theme.ink, x: 2, y: 2)
                    .frame(minHeight: 48)   // law 1: full-size hit target
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Meal library")
            HStack(spacing: 6) {
                ForEach([Palette.pink, Palette.yellow, Palette.green]) { slot in
                    MagnetDot(color: slot.color)
                        .shadow(color: Theme.ink.opacity(0.3), radius: 0, x: 1, y: 1)
                }
            }
            .accessibilityHidden(true)   // purely decorative
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Tonight card (paper, ink border, r20, tilt −0.5°, pink magnet)

    @ViewBuilder private var tonightCard: some View {
        if let meal = appState.tonight.meal {
            plannedTonightCard(meal)
        } else {
            // Cold start is canon (PT-1): no plan entry exists tonight, and
            // the door says so honestly — never fallback-as-plan (D-35 note).
            emptyTonightCard
        }
    }

    private func plannedTonightCard(_ meal: Meal) -> some View {
        VStack(spacing: 0) {
            Text(appState.tonightLabel)
                .font(.nunito(10.5, .black))
                .kerning(1.05)                        // .1em at 10.5
                .foregroundStyle(Palette.pink.label)  // #D46A92
            Text(meal.name)
                .font(.baloo(24, .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 3)
            HStack(spacing: 6) {
                // Guarantees, not decorations — straight from meal.badges.
                ForEach(meal.badges) { badge in
                    SafetyBadge(text: badge.text, slot: badge.slot)
                }
            }
            .padding(.top, 7)
            tonightActions
                .padding(.top, 11)
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 16, leading: 15, bottom: 15, trailing: 15))
        .inkCard()                          // paper, 2pt ink, r20
        .softHardShadow(x: 5, y: 5)         // 5px 5px 0 rgba(ink,.12)
        .overlay(alignment: .top) {
            MagnetDot(color: Palette.pink.color, size: 18)
                .offset(y: -9)
                .accessibilityHidden(true)
        }
        .rotationEffect(.degrees(-0.5))     // per mockup
    }

    /// Nothing planned tonight (cold start / open day): no badges to fake
    /// (zero scores exist by canon), no swap of nothing — DECIDE FOR ME stays
    /// the sole hero action (law 1). Composed from the kit; the layout is
    /// designed-ADJACENT, not designed — flagged for a real design pass.
    private var emptyTonightCard: some View {
        VStack(spacing: 0) {
            Text("TONIGHT")
                .font(.nunito(10.5, .black))
                .kerning(1.05)
                .foregroundStyle(Palette.pink.label)
            Text("nothing picked yet")   // D-48: state, not permission
                .font(.baloo(24, .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 3)
            Button("DECIDE FOR ME") { appState.decideForMe(); onWin?() }
                .buttonStyle(PillButtonStyle(background: Palette.pink.color, emphasis: true))
                .frame(height: 48)
                .padding(.top, 11)
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 16, leading: 15, bottom: 15, trailing: 15))
        .inkCard()
        .softHardShadow(x: 5, y: 5)
        .overlay(alignment: .top) {
            MagnetDot(color: Palette.pink.color, size: 18)
                .offset(y: -9)
                .accessibilityHidden(true)
        }
        .rotationEffect(.degrees(-0.5))
    }

    /// Actions grid 1.5fr / 1fr, gap 8 — "decide for me" is always the most
    /// prominent action (law 1) and commits instantly; undo is "swap".
    private var tonightActions: some View {
        GeometryReader { geo in
            HStack(spacing: 8) {
                Button("DECIDE FOR ME") { appState.decideForMe(); onWin?() }
                    .buttonStyle(PillButtonStyle(background: Palette.pink.color, emphasis: true))
                    .frame(width: max(0, (geo.size.width - 8) * 0.6))   // 1.5fr of 2.5fr
                Button("swap") {
                    swapChoices = appState.swapOptions()   // snapshot before presenting
                    showSwapSheet = true
                }
                .buttonStyle(PillButtonStyle())
            }
        }
        .frame(height: 48)
    }

    // MARK: - Sticky notes (noticer note + streak patch)

    private var stickyNotes: some View {
        HStack(alignment: .top, spacing: 10) {
            noticerNote
            streakNote
        }
        .fixedSize(horizontal: false, vertical: true)   // equal-height cells like the CSS grid
    }

    private var noticerNote: some View {
        let note = appState.homeNote
        return Button { onOpenThread?() } label: {
            StickyNote(slot: Palette.yellow, rotation: 1.4,
                       magnetColor: Palette.blue.color, magnetAlignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(note.author.name.uppercased()) LEFT A NOTE")
                        .font(.nunito(10.5, .black))
                        .foregroundStyle(Palette.yellow.label)       // #8A6D1E
                    Text(note.text)
                        .font(.nunito(12.5, .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(2)                              // line-height ≈1.35
                        .padding(.top, 3)
                    Text(note.more)
                        .font(.nunito(10.5, .black))
                        .foregroundStyle(Palette.yellow.labelMuted)  // darkened, see Theme
                        .padding(.top, 5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(FridgeHomePressStyle())
        .frame(maxWidth: .infinity)
    }

    /// The mockup's streak note sits on the pink primary tint (#FDE7F0) while the
    /// shared StickyNote draws `slot.tintAlt`, so this slot carries the mockup's
    /// exact note colors (incl. the muted #C08BA0 subline).
    // labelMuted darkened from the mockup's #C08BA0 (2.4:1 on the tint) to the
    // slot label — readability adjudication, 2026-07-08.
    private static let streakNoteSlot = PaletteSlot(
        id: "her-1-streak-note", color: 0xFF7BAC, tint: 0xFDE7F0, tintAlt: 0xFDE7F0,
        label: 0xB04A72)

    private var streakNote: some View {
        Button { onOpenStreaks?() } label: {
            StickyNote(slot: Self.streakNoteSlot, rotation: -1.2,
                       magnetColor: Palette.green.color, magnetAlignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("STREAK PATCH")
                        .font(.nunito(10.5, .black))
                        .foregroundStyle(Self.streakNoteSlot.label)       // #B04A72
                    Text("\(appState.streak.displayDay) 🧲")              // never renders "0" (law 4)
                        .font(.baloo(19, .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 2)
                    Text(appState.streak.subline)                         // "PB 23 · the rebuild"
                        .font(.nunito(10.5, .black))
                        .foregroundStyle(Self.streakNoteSlot.labelMuted)  // #C08BA0
                        .padding(.top, 3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(FridgeHomePressStyle())
        .frame(maxWidth: .infinity)
    }

    // MARK: - Week magnets (wrapping row, tap → week plan)

    private static let magnetTilts: [Double] = [-1.0, 1.5, -0.8, 1.0, -1.4, 0.9, 0]

    private var weekMagnets: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: "WEEK MAGNETS")
                .padding(.horizontal, 4)
            FridgeHomeWrapLayout(spacing: 6) {
                ForEach(appState.week) { plan in
                    FridgeHomeWeekMagnet(
                        label: magnetLabel(for: plan),
                        kind: plan.kind,
                        rotation: Self.magnetTilts[plan.day.rawValue])
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { onOpenWeek?() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Opens the week plan"))
    }

    private func magnetLabel(for plan: DayPlan) -> String {
        let day = plan.day.short
        switch plan.kind {
        case .done: return "\(day) \(plan.meal?.displayKeyword ?? "?") ✓"
        case .tonight, .planned: return "\(day) \(plan.meal?.displayKeyword ?? "?")"
        case .kidCook:
            let cook = appState.household.first { $0.cookNight == plan.day }?.name ?? "kid"
            return "\(day): \(cook.uppercased()) 🍜"
        case .joyCook: return "\(day): JOY 🍲"
        case .open: return "\(day) ?"
        case .rest: return "\(day) rest"
        }
    }

    // MARK: - Pinned bottom (tank check + guarantee line)

    private var bottomPinned: some View {
        VStack(spacing: Theme.Space.s) {
            HStack(spacing: 8) {
                ForEach(Tank.allCases) { level in
                    Button(level.rawValue) { appState.setTank(level) }
                        .buttonStyle(FridgeHomeTankSegmentStyle(isSelected: appState.tank == level))
                }
            }
            Button { onOpenShopping?() } label: {
                Text(appState.guaranteeLine)   // "groceries covered thru Friday ✓" — quiet
                    .font(.nunito(11.5, .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    // Hit target law: full-width 48pt tap area, but the label
                    // top-aligns so its visual gap to the tank row stays ~8px.
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .top)
                    .contentShape(Rectangle())
            }
            .buttonStyle(FridgeHomePressStyle())
        }
    }

    // MARK: - Swap sheet (exactly 3 alternatives — law 2)

    private var swapSheet: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            SectionLabel(text: "SWAP TONIGHT · PICK ONE")
                .padding(.top, Theme.Space.l)
            ForEach(swapChoices) { meal in
                Button {
                    appState.commitTonight(meal)   // committing IS the confirmation
                    showSwapSheet = false
                } label: {
                    FridgeHomeSwapRow(meal: meal)
                }
                .buttonStyle(FridgeHomePressStyle())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationBackground(Theme.shelf)
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.Radius.cardLarge)
    }
}

// MARK: - Week magnet chip

private struct FridgeHomeWeekMagnet: View {
    var label: String
    var kind: DayKind
    var rotation: Double

    var body: some View {
        Text(label)
            .font(.nunito(11.5, .black))
            .foregroundStyle(kind == .open ? Theme.textSecondary : Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 30)               // mockup chip fill is 30px tall
            .inkCard(background: background,
                     radius: Theme.Radius.sticker,
                     borderColor: kind == .open ? Theme.textDisabled : Theme.ink,
                     dashed: kind == .open)
            .hardShadow(kind == .tonight ? Theme.ink : .clear, x: 2, y: 2)
            .rotationEffect(.degrees(kind == .open ? 0 : rotation))
    }

    private var background: Color {
        switch kind {
        case .tonight: return Palette.yellow.color   // current — yellow + ink shadow
        case .kidCook: return Palette.green.tint
        case .joyCook: return Palette.pink.tint
        case .rest: return Palette.blue.tint         // rest day, never a "miss"
        case .open: return .clear
        case .done, .planned: return Theme.paper
        }
    }
}

// MARK: - Swap option row (system style: ink border, effort dots, safety badges)

private struct FridgeHomeSwapRow: View {
    var meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(meal.name)
                    .font(.nunito(14.5, .black))
                    .foregroundStyle(Theme.ink)
                Spacer()
                EffortDots(effort: meal.effort)   // drawn, never "●○○" text (Nunito lacks the glyphs)
            }
            HStack(spacing: 6) {
                ForEach(meal.badges) { badge in
                    SafetyBadge(text: badge.text, slot: badge.slot)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .inkCard(radius: Theme.Radius.tankSegment)
    }
}

// MARK: - Tank segment (r16; selected = yellow + 3pt ink shadow)

private struct FridgeHomeTankSegmentStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nunito(13, .black))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .inkCard(background: isSelected ? Palette.yellow.color : Theme.paper,
                     radius: Theme.Radius.tankSegment)
            .hardShadow(isSelected ? Theme.ink : .clear)
            .offset(x: configuration.isPressed && isSelected ? 2 : 0,
                    y: configuration.isPressed && isSelected ? 2 : 0)
            .opacity(configuration.isPressed && !isSelected ? 0.85 : 1)
            .accessibilityAddTraits(isSelected ? .isSelected : [])   // VoiceOver: "selected, Fumes"
    }
}

// MARK: - Quiet press style (content-defined buttons: notes, rows, footer)

private struct FridgeHomePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Wrapping row layout for the week magnets

private struct FridgeHomeWrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    FridgeHomeView()
        .environmentObject(AppState())
}
