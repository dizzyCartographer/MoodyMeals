import SwiftUI

// Week plan — pixel-faithful recreation of design_refs/2b-week-plan.html
// (README §Screens.2). Placeholder cast swapped for the authoritative cast:
// Juno→Caddie (GF), Milo→Elsie (plain/safe foods), Tas→Chad (Wed cook),
// Dev→Chuck. Screen background is Theme.shelf, so the paper surfaces (AM strip,
// day cards) carry the contrast the ref achieved on white.
//
// Interactions: tap any unlocked day to reveal exactly 3 swap candidates
// (law 2), tap one to commit it to that day; long-press toggles the lock flag
// on the row. Sunday's "deal me 3" pill deals the same 3 candidates.

struct WeekPlanView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Thursday's grocery note ("needs 2 items — on tonight's run ✓") taps
    /// through here. Wiring to the Shopping screen happens later.
    var onOpenShopping: (() -> Void)? = nil

    @State private var expandedDay: Weekday?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                amStrip
                dayList
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        // Ref's flex:1 list pins the hint to the viewport bottom — slack lives
        // above the hint, not 12pt under the SUN row.
        .safeAreaInset(edge: .bottom) {
            Text("tap any day to swap · long-press to lock")
                .font(.nunito(12, .heavy))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .padding(.bottom, 10)
                .background(Theme.shelf)
        }
        .background(Theme.shelf.ignoresSafeArea())
    }

    // MARK: Header — "This week" + tilted date chip (decorative, so tilt is OK)

    private var header: some View {
        HStack {
            Text("This week")
                .font(.baloo(30, .heavy))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text(appState.weekSpanLabel)   // derived — the literal went stale
                .font(.nunito(11, .black))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .inkCard(background: Palette.blue.tint, radius: Theme.Radius.sticker)
                .hardShadow(Palette.blue.color, x: 2, y: 2)
                .rotationEffect(.degrees(2))
        }
    }

    // MARK: Compact AM strip — per-person breakfast defaults, derived (D-35:
    // never hardcoded). No defaults on file ⇒ the strip hides — honest empty
    // until per-member breakfasts land (M7).

    @ViewBuilder private var amStrip: some View {
        if let line = appState.amBreakfastLine {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                Text("AM")
                    .font(.nunito(10.5, .black))
                    .kerning(0.8)
                    .foregroundStyle(Theme.textSecondary)
                Text(line)
                    .font(.nunito(12, .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
            .padding(.horizontal, Theme.Space.m)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: Day rows

    private var dayList: some View {
        VStack(spacing: 7) {
            ForEach(appState.week) { plan in
                WeekPlanDayRow(plan: plan,
                               onTap: { rowTapped(plan) },
                               onLongPress: { toggleLock(plan) },
                               onOpenShopping: onOpenShopping)
                if expandedDay == plan.day {
                    WeekPlanCandidateStrip(candidates: candidates(for: plan)) { meal in
                        commit(meal, to: plan.day)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: Interactions

    private func rowTapped(_ plan: DayPlan) {
        guard !plan.locked else { return }
        setExpanded(expandedDay == plan.day ? nil : plan.day)
    }

    private func toggleLock(_ plan: DayPlan) {
        guard let i = appState.week.firstIndex(where: { $0.day == plan.day }) else { return }
        appState.week[i].locked.toggle()
        if appState.week[i].locked, expandedDay == plan.day { setExpanded(nil) }
    }

    /// Commits a dealt/swapped meal to the day, locally in app state.
    private func commit(_ meal: Meal, to day: Weekday) {
        guard let i = appState.week.firstIndex(where: { $0.day == day }) else { return }
        appState.week[i].meal = meal
        if appState.week[i].kind == .open { appState.week[i].kind = .planned }
        setExpanded(nil)
    }

    /// Exactly 3 candidates (law 2), never including the day's current meal.
    private func candidates(for plan: DayPlan) -> [Meal] {
        Array(appState.candidates.filter { $0.id != plan.meal?.id }.prefix(3))
    }

    private func setExpanded(_ day: Weekday?) {
        if reduceMotion {
            expandedDay = day
        } else {
            withAnimation(.easeOut(duration: 0.22)) { expandedDay = day }
        }
    }
}

// MARK: - Day row

private struct WeekPlanDayRow: View {
    @EnvironmentObject var appState: AppState
    var plan: DayPlan
    var onTap: () -> Void
    var onLongPress: () -> Void
    var onOpenShopping: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Text(plan.day.short.uppercased())
                .font(.nunito(11, .black))
                .foregroundStyle(dayLabelColor)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 1) {
                if plan.kind == .open {
                    Text("still open")
                        .font(.nunito(14.5, .heavy))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text(plan.meal?.name ?? "—")
                        .font(.nunito(14.5, .black))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    meta
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.vertical, 9)
        .padding(.horizontal, Theme.Space.m)
        .frame(minHeight: 52) // ≥48pt hit target (law 1)
        .inkCard(background: background,
                 radius: 16,
                 borderColor: plan.kind == .open ? Theme.textDisabled : Theme.ink,
                 dashed: plan.kind == .open)
        .hardShadow(shadowColor, x: 3, y: 3)
        .overlay(alignment: .topTrailing) {
            if plan.locked { lockBadge }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.4, perform: onLongPress)
        // Gesture-driven row → give assistive tech one element with the tap
        // as the default action and the long-press lock as a named action.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Shows 3 swaps")
        .accessibilityAction(named: plan.locked ? "Unlock day" : "Lock day") {
            onLongPress()
        }
    }

    // MARK: Row styling per kind

    private var background: Color {
        switch plan.kind {
        case .tonight: return Palette.yellow.tint    // #FFF4CE
        case .joyCook: return Palette.pink.tintAlt   // #FFE3EE
        case .rest: return Palette.blue.tint
        case .open: return Theme.shelf
        default: return Theme.paper
        }
    }

    private var shadowColor: Color {
        switch plan.kind {
        case .tonight: return Palette.yellow.color
        case .joyCook: return Palette.pink.color
        default: return .clear
        }
    }

    private var dayLabelColor: Color {
        switch plan.kind {
        case .tonight: return Palette.yellow.label     // #8A6D1E
        case .joyCook: return Palette.pink.labelMuted  // #B04A72
        default: return Theme.textSecondary
        }
    }

    // MARK: Meta line — effort dots + attendance, with the ref's demo notes

    @ViewBuilder private var meta: some View {
        if let info = metaInfo {
            if info.opensShopping {
                // ≥48pt hit target (law 1) on a ~16pt text line: top-align the
                // text in a 48pt frame so the tappable shape extends downward,
                // then hand the extra 32pt back to layout with negative padding
                // so the visible row height/spacing doesn't grow.
                metaLine(info)
                    .frame(minHeight: 48, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .onTapGesture { onOpenShopping?() }
                    .padding(.bottom, -32)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Opens shopping")
            } else {
                metaLine(info)
            }
        }
    }

    /// Text segments around the (shape-based) effort dots; single-line so no
    /// row grows taller than its siblings.
    private func metaLine(_ info: MetaInfo) -> some View {
        HStack(spacing: 3.5) {
            if !info.lead.isEmpty {
                metaText(info.lead, color: info.color)
            }
            if info.showsDots {
                EffortDots(effort: plan.meal?.effort ?? 1, color: info.color)
            }
            if !info.trail.isEmpty {
                metaText(info.trail, color: info.color)
            }
        }
    }

    private func metaText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.nunito(11.5, .heavy))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
    }

    private struct MetaInfo {
        var lead: String = ""
        var showsDots = false
        var trail: String = ""
        var color: Color
        var opensShopping = false
    }

    private var metaInfo: MetaInfo? {
        switch plan.kind {
        case .done:
            return MetaInfo(lead: "effort", showsDots: true,
                            trail: "· \(plan.attendance)", color: Theme.textSecondary)
        case .tonight where plan.meal?.id == "tacos":
            return MetaInfo(lead: "TACO TUESDAY · pinned by you", color: Palette.yellow.label)
        case .tonight:
            return MetaInfo(lead: "tonight · effort", showsDots: true, color: Palette.yellow.label)
        case .kidCook:
            return MetaInfo(lead: "effort", showsDots: true,
                            trail: "for you · Chuck away", color: Theme.textSecondary)
        case .planned where plan.meal?.id == "gnocchi":
            return MetaInfo(lead: "needs 2 items — on tonight's run ✓",
                            color: Palette.pink.label, opensShopping: true)
        case .planned where plan.meal?.id == "pizza":
            return MetaInfo(lead: "GF crust for Caddie · Elsie: cheese wing",
                            color: Theme.textSecondary)
        case .planned:
            return MetaInfo(lead: "effort", showsDots: true,
                            trail: "· \(plan.attendance)", color: Theme.textSecondary)
        case .joyCook:
            return MetaInfo(lead: "clear kitchen + no rush = cook for real?",
                            color: Palette.pink.labelMuted)
        case .rest:
            return MetaInfo(lead: "rest day · streak intact", color: Palette.blue.label)
        case .open:
            return nil
        }
    }

    // MARK: Trailing accessory per kind

    @ViewBuilder private var trailing: some View {
        switch plan.kind {
        case .done:
            attendanceCluster
        case .tonight:
            WeekPlanInkSticker(text: "ANCHOR", accent: Palette.yellow.color, rotation: -2)
        case .kidCook:
            chadChip
        case .planned:
            EffortDots(effort: plan.meal?.effort ?? 1)
        case .joyCook:
            WeekPlanInkSticker(text: "JOY", accent: Palette.pink.color, rotation: 2)
        case .open:
            dealPill
        case .rest:
            EmptyView()
        }
    }

    /// Overlapping member dots — everyone home (colors from the cast's blobs).
    private var attendanceCluster: some View {
        HStack(spacing: -6) {
            ForEach(appState.household) { member in
                Circle()
                    .fill(member.blobColor)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            }
        }
    }

    private var chadChip: some View {
        let chad = appState.member("chad")
        return HStack(spacing: 5) {
            BlobAvatar(color: chad.blobColor, variant: chad.blobVariant, size: 18)
            Text("CHAD COOKS")
                .font(.nunito(10.5, .black))
                .foregroundStyle(Theme.ink)
        }
        .padding(.leading, 4)
        .padding(.trailing, 9)
        .padding(.vertical, 3)
        .inkCard(background: Palette.green.tint, radius: Theme.Radius.pill)
    }

    private var dealPill: some View {
        Text("deal me 3")
            .font(.nunito(12, .black))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .inkCard(background: Palette.yellow.color, radius: Theme.Radius.pill)
            .hardShadow(Theme.ink, x: 2, y: 2)
            .onTapGesture(perform: onTap)
    }

    private var lockBadge: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(Theme.ink, in: Circle())
            .offset(x: 6, y: -6)
            .accessibilityLabel("Locked")
    }
}

// MARK: - Ink sticker (ANCHOR / JOY — ink bg, accent text, tilted)

private struct WeekPlanInkSticker: View {
    var text: String
    var accent: Color
    var rotation: Double

    var body: some View {
        Text(text)
            .font(.nunito(10, .black))
            .foregroundStyle(accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Dealt candidates — exactly 3, tap commits instantly (no modal)

private struct WeekPlanCandidateStrip: View {
    var candidates: [Meal]
    var onPick: (Meal) -> Void

    var body: some View {
        HStack(spacing: 7) {
            ForEach(candidates) { meal in
                Button {
                    onPick(meal)
                } label: {
                    VStack(spacing: 2) {
                        Text(meal.name)
                            .font(.nunito(11.5, .black))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        EffortDots(effort: meal.effort)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 52) // ≥48pt targets
                    .inkCard(background: Theme.paper, radius: 12)
                    .softHardShadow(x: 2, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    WeekPlanView()
        .environmentObject(AppState())
}
