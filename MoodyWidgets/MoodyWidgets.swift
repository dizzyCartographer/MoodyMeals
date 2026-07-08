import WidgetKit
import SwiftUI

// The "Tonight" widget — object permanence off-app (design law 3): tonight's
// meal and the three safety GUARANTEES are visible at a glance, at every size.
// Reference render: design_refs/2h-widgets.html (small + medium).
//
// Note on chrome: the mockup draws a 4px hard slot-colored shadow OUTSIDE the
// widget frame. iOS clips everything at the widget bounds, so the outer shadow
// is dropped; the 2px ink border rides the system container shape and inner
// element shadows (decide pill) stay inset via the default content margins.

// MARK: - Widget bundle

@main
struct MoodyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TonightWidget()
        #if canImport(ActivityKit)
        CookModeActivityWidget()
        #endif
    }
}

// MARK: - Timeline

/// Static demo entry mirroring `AppState`'s demo data (Taco Tuesday,
/// groceries covered thru Friday).
struct TonightEntry: TimelineEntry {
    let date: Date
    var label = "TONIGHT · TACO TUESDAY"
    var mealName = "Build-your-own tacos"
    /// The guarantees. Derived from the meal exactly like the app does —
    /// never dropped from any widget size.
    var badges: [SafetyBadgeInfo] = Meal(id: "tacos", name: "Build-your-own tacos", effort: 2).badges
    var badgeSummary = "GF ✓ · plain ✓ · ×2 ✓"
    var coveredLine = "covered thru FRI ✓"

    static let demo = TonightEntry(date: .now)
}

struct TonightProvider: TimelineProvider {
    func placeholder(in context: Context) -> TonightEntry { .demo }

    func getSnapshot(in context: Context, completion: @escaping (TonightEntry) -> Void) {
        completion(.demo)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TonightEntry>) -> Void) {
        completion(Timeline(entries: [.demo], policy: .never))
    }
}

// MARK: - Widget

struct TonightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MoodyTonight", provider: TonightProvider()) { entry in
            TonightWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        Theme.paper
                        ContainerRelativeShape()
                            .strokeBorder(Theme.ink, lineWidth: Theme.borderWidth)
                    }
                }
        }
        .configurationDisplayName("Tonight")
        .description("Tonight's dinner, the guarantees, and one-tap decide.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TonightWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TonightEntry

    var body: some View {
        switch family {
        case .systemMedium:
            TonightMediumView(entry: entry)
        default:
            TonightSmallView(entry: entry)
        }
    }
}

// MARK: - Small · glance + open

// systemSmall gets ONE url for the whole face — no per-element Links — so a
// glance at the meal name must never silently re-plan dinner. The whole
// widget opens the app on Tonight (matching the medium container);
// moody://decide is reserved for taps that mean it (the medium pill).
struct TonightSmallView: View {
    var entry: TonightEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TONIGHT")
                    .font(.nunito(9.5, .black))
                    .kerning(0.76)
                    .foregroundStyle(Palette.pink.label)
                Spacer(minLength: 0)
                Circle()
                    .fill(Palette.green.color)
                    .frame(width: 8, height: 8)
            }
            Text(entry.mealName)
                .font(.baloo(19, .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.top, 4)
            Text(entry.badgeSummary)
                .font(.nunito(10, .heavy))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .padding(.top, 3)
            Spacer(minLength: 6)
            // The mockup's pill, kept as a visual affordance — not a separate
            // button here. The arrow says "this takes you somewhere": the tap
            // opens the app, and deciding happens there.
            Text("decide for me →")
                .font(.nunito(11, .black))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .inkCard(background: Palette.pink.tintAlt, radius: Theme.Radius.pill)
        }
        .widgetURL(URL(string: "moody://tonight"))
    }
}

// MARK: - Medium · plan + tank check without opening the app

struct TonightMediumView: View {
    var entry: TonightEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(entry.label)
                    .font(.nunito(9.5, .black))
                    .kerning(0.76)
                    .foregroundStyle(Palette.pink.label)
                Spacer(minLength: 8)
                Text(entry.coveredLine)
                    .font(.nunito(9.5, .black))
                    .foregroundStyle(Palette.green.labelMuted)
            }
            Text(entry.mealName)
                .font(.baloo(22, .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 2)
            HStack(spacing: 5) {
                ForEach(entry.badges) { badge in
                    SafetyBadge(text: badge.text, slot: badge.slot)
                }
            }
            .padding(.top, 4)
            Spacer(minLength: 4)
            actionRow
        }
        .widgetURL(URL(string: "moody://tonight"))
    }

    // 1.4 : 1 : 1 like the reference grid. 40pt tall so the three Links are
    // real fingertip targets, not 32pt squints — the spacer above pays for it.
    private var actionRow: some View {
        GeometryReader { geo in
            let gap: CGFloat = 7
            let unit = (geo.size.width - gap * 2) / 3.4
            HStack(spacing: gap) {
                Link(destination: URL(string: "moody://decide")!) {
                    actionPill("decide for me", background: Palette.pink.color)
                        .hardShadow(Theme.ink, x: 2, y: 2)
                }
                .frame(width: unit * 1.4)
                Link(destination: URL(string: "moody://tank/fumes")!) {
                    actionPill("fumes", background: Theme.paper)
                }
                .frame(width: unit)
                Link(destination: URL(string: "moody://tank/steady")!) {
                    actionPill("steady", background: Palette.yellow.color)
                }
                .frame(width: unit)
            }
        }
        .frame(height: 40)
    }

    private func actionPill(_ title: String, background: Color) -> some View {
        Text(title)
            .font(.nunito(11.5, .black))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity) // fill the 40pt row
            .inkCard(background: background, radius: Theme.Radius.pill)
    }
}

// MARK: - Previews

#Preview("small", as: .systemSmall) {
    TonightWidget()
} timeline: {
    TonightEntry.demo
}

#Preview("medium", as: .systemMedium) {
    TonightWidget()
} timeline: {
    TonightEntry.demo
}
