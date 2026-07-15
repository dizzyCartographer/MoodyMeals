import SwiftUI

// TODAY (D-56 native) — tonight's dinner, the two levers (decide / swap),
// and capacity. Nothing else: the shopping guarantee line lived here too
// once, but it's the exact same line the Shopping tab already shows, and
// on Today — with no inventory system behind it — it read as status for
// something that doesn't exist. Removed (Ria 2026-07-14: "clean up the
// main page so it only shows things that actually work and make sense").

struct TodayView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPicker = false

    private var tonight: DayPlan { appState.tonight }

    /// Capacity is real, not decorative — it caps decide-for-me/swap's
    /// effort pool (AppState.decideForMe/swapOptions) and, on a drop to
    /// Fumes, recommits tonight down to that cap if it's currently above
    /// it. The footer says what THIS choice does, not a fixed line about
    /// one of the three.
    private var capacityFooter: String {
        switch appState.tank {
        case .fumes: "tonight (and swap) stay at the lowest-effort picks"
        case .steady: "tonight (and swap) can go up to simple effort"
        case .full: "no effort limit — anything's in play"
        }
    }

    var body: some View {
        List {
            Section("Tonight") {
                if let meal = tonight.meal {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(meal.name)
                            .font(.title2.weight(.semibold))
                        if !meal.badges.isEmpty {
                            BadgeRow(badges: meal.badges)
                        }
                    }
                    .padding(.vertical, 2)
                } else {
                    Text("nothing picked yet")
                        .foregroundStyle(.secondary)
                }

                Button {
                    appState.decideForMe()
                } label: {
                    Label("Decide for me", systemImage: "sparkles")
                        .font(.body.weight(.semibold))
                }

                // Review pass 1: "I know what I want" needs a door too —
                // decide-for-me can't be the only way onto tonight.
                Button {
                    showPicker = true
                } label: {
                    Label(tonight.meal == nil ? "Choose tonight's dinner" : "Choose different",
                          systemImage: "list.bullet")
                }

                if tonight.meal != nil {
                    Menu {
                        ForEach(appState.swapOptions()) { option in
                            Button(option.name) { appState.commitTonight(option) }
                        }
                    } label: {
                        Label("Swap", systemImage: "arrow.2.squarepath")
                    }
                }
            }

            Section {
                Picker("Capacity", selection: Binding(
                    get: { appState.tank },
                    set: { appState.setTank($0) })) {
                    ForEach(Tank.allCases, id: \.self) { tank in
                        Text(tank.rawValue).tag(tank)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Capacity")
            } footer: {
                Text(capacityFooter)
            }
        }
        .navigationTitle("Today")
        .sheet(isPresented: $showPicker) {
            MealPickerSheet(date: .now, slotRaw: "dinner")
        }
    }
}

/// Truthful per-member badges, native dress: palette tints stay because the
/// COLORS carry meaning (green = verified guarantee, yellow = attention).
struct BadgeRow: View {
    var badges: [SafetyBadgeInfo]

    var body: some View {
        FlowChips(items: badges.map { ($0.text, $0.slot) })
    }
}

struct FlowChips: View {
    var items: [(text: String, slot: PaletteSlot)]

    var body: some View {
        // Simple wrapping row — native type, palette tints.
        FlexibleChipLayout(spacing: 5) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(item.text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.slot.label)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(item.slot.tint, in: Capsule())
            }
        }
    }
}

/// Minimal wrapping layout (Layout protocol) — no kit dependency.
struct FlexibleChipLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
