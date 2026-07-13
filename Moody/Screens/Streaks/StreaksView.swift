import SwiftUI

// Streaks — pixel-faithful build of design_refs/2d-streaks.html (README §Screens.4).
// Law 4 lives here: the headline day count comes from Streak.displayDay and can
// never render "0"; planned skips are "rest days", misses get no aesthetics at all.

struct StreaksView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Streaks")
                .font(.baloo(30, .heavy))
                .foregroundStyle(Theme.ink)

            StreaksHeroCard(streak: appState.streak)

            StreaksWeekStrip(week: appState.week)

            StreaksFreezePopsCard(tokens: appState.streak.freezeTokens)

            Spacer(minLength: 0)

            StreaksReturnCard()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.m)
        .padding(.bottom, Theme.Space.m)
        .background(Theme.shelf.ignoresSafeArea())
    }
}

// MARK: - Hero card (pink tint, pink hard shadow, PB sticker)

private struct StreaksHeroCard: View {
    var streak: Streak

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // D-13: ANY dinner counts — fallback, leftovers, even the nuclear
            // option. The hero counts dinners that HAPPENED, not dinners cooked.
            Text("DINNERS THAT HAPPENED")
                .font(.nunito(12, .black))
                .kerning(0.96)   // .08em of 12px
                .foregroundStyle(Palette.pink.labelMuted)

            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                Text(streak.displayDay)   // "day 2" — NEVER a raw zero (law 4)
                    .font(.baloo(44, .heavy))
                    .foregroundStyle(Theme.ink)
                Text("of the rebuild")
                    .font(.nunito(15, .black))
                    .foregroundStyle(Palette.pink.labelMuted)
            }
            .padding(.top, 2)

            Text("not starting over — picking back up. there's a difference.")
                .font(.nunito(12.5, .heavy))
                .foregroundStyle(Palette.pink.labelMuted)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .inkCard(background: Palette.pink.tintAlt, radius: Theme.Radius.cardLarge)
        .hardShadow(Palette.pink.color, x: 5, y: 5)
        .overlay(alignment: .topTrailing) {
            // The screen's ONE sticker moment. Ref styling: full yellow fill,
            // ink shadow 2px, rotate 3°, poking 12px above the card edge.
            // pbBadge is nil until a PB exists — "PB: 0" never renders (law 4).
            if let badge = streak.pbBadge {
                StreaksPBSticker(text: badge)
                    .offset(x: -14, y: -12)
            }
        }
    }
}

private struct StreaksPBSticker: View {
    var text: String   // Streak.pbBadge, e.g. "PB: 23"

    var body: some View {
        Text(text)
            .font(.nunito(10.5, .black))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .inkCard(background: Palette.yellow.color, radius: Theme.Radius.sticker)
            .hardShadow(Theme.ink, x: 2, y: 2)
            .rotationEffect(.degrees(3))
    }
}

// MARK: - Week strip (7 tiles from appState.week)

private struct StreaksWeekStrip: View {
    var week: [DayPlan]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THIS WEEK")
                .font(.nunito(11, .black))
                .kerning(0.88)   // .08em of 11px
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 7)

            HStack(alignment: .top, spacing: 7) {
                ForEach(week) { plan in
                    StreaksDayTile(plan: plan)
                }
            }

            Text("Wednesday was a rest day, not a miss. the math agrees: streak intact.")
                .font(.nunito(11.5, .bold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 6)
        }
    }
}

private struct StreaksDayTile: View {
    var plan: DayPlan

    // Done days fill from her palette slots (ref: Mon green ✓, Tue pink ✓,
    // Thu yellow ✓). Yellow is the one fill whose ✓ stays ink, not white.
    private static let fills: [PaletteSlot] = [
        Palette.green, Palette.pink, Palette.purple, Palette.yellow,
        Palette.blue, Palette.pink, Palette.green,
    ]

    var body: some View {
        VStack(spacing: 3) {
            tile
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            Text(String(plan.day.short.prefix(1)))
                .font(.nunito(10, .black))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var tile: some View {
        switch plan.kind {
        case .done:
            let slot = Self.fills[plan.day.rawValue % Self.fills.count]
            // Ink ✓ on every fill (white measured ~2:1 on the mid-tone slots) —
            // readability adjudication, 2026-07-08.
            Text("✓")
                .font(.nunito(15, .black))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .inkCard(background: slot.color, radius: 12)
        case .rest:
            // A planned skip: blue tint, streak intact, zero shame.
            Text("rest\nday")
                .font(.nunito(9.5, .black))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.blue.label)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .inkCard(background: Palette.blue.tint, radius: 12)
        case .tonight:
            // Nearest undecided day: solid ink border on paper (ref's "F" tile).
            Text("tbd")
                .font(.nunito(10, .black))
                .foregroundStyle(Theme.textDisabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .inkCard(background: Theme.paper, radius: 12)
        default:
            // Future days: empty dashed outline — no text (ref shows "tbd"
            // only on the next-undecided .tonight tile).
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .inkCard(background: .clear, radius: 12,
                         borderColor: Theme.textDisabled, dashed: true)
        }
    }
}

// MARK: - Freeze pops (blue tint card)

private struct StreaksFreezePopsCard: View {
    var tokens: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center) {
                // Law 4 guardrail: never print "× 0".
                Text(tokens > 0 ? "Freeze pops × \(tokens)" : "Freeze pops")
                    .font(.nunito(14, .black))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: Theme.Space.s)
                HStack(spacing: 6) {
                    ForEach(0..<max(tokens, 0), id: \.self) { i in
                        StreaksFreezePop(color: i.isMultiple(of: 2)
                                         ? Palette.blue.color : Palette.purple.color)
                    }
                }
            }
            // D-13: the earn rate is tunable (TuningDefaults) — copy never
            // states a number. D-48: how they trigger is the whole sentence;
            // "no confessions required" narrated the non-judgment and is gone.
            Text("auto-protects a wild day. you earn them by showing up.")
                .font(.nunito(12, .heavy))
                .foregroundStyle(Palette.blue.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .inkCard(background: Palette.blue.tint, radius: 18)
    }
}

private struct StreaksFreezePop: View {
    var color: Color

    private var pop: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 4,
                               bottomTrailingRadius: 4, topTrailingRadius: 8)
    }

    var body: some View {
        pop.fill(color)
            .overlay(pop.strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
            .frame(width: 22, height: 34)
    }
}

// MARK: - THE RETURN (ink card, tri-color progress)

private struct StreaksReturnCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INBOUND")
                .font(.nunito(11, .black))
                .kerning(1.32)   // .12em of 11px
                .foregroundStyle(Palette.yellow.color)

            Text("THE RETURN — 1 dinner away")
                .font(.baloo(23, .heavy))
                .foregroundStyle(.white)
                .padding(.top, 1)

            StreaksReturnProgressBar(progress: 0.66)
                .padding(.top, 9)

            // D-13 framing: dinner has to HAPPEN, not be cooked from scratch.
            // D-55: no demands, no pressure jokes — state what's waiting.
            Text("one dinner completes the return. the parade is already built.")
                .font(.nunito(11.5, .heavy))
                .foregroundStyle(Theme.textDisabled)
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .inkCard(background: Theme.ink, radius: Theme.Radius.cardLarge)
    }
}

private struct StreaksReturnProgressBar: View {
    var progress: CGFloat   // 0…1

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(LinearGradient(
                    colors: [Palette.pink.color, Palette.yellow.color, Palette.green.color],
                    startPoint: .leading, endPoint: .trailing))
                .frame(width: geo.size.width * min(max(progress, 0), 1))
        }
        .frame(height: 12)
        .background(Color.white.opacity(0.18), in: Capsule())
    }
}

#Preview {
    StreaksView()
        .environmentObject(AppState())
}
