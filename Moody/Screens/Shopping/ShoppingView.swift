import SwiftUI

// SHOPPING — tiered runs + the guarantee.
// Pixel reference: design_refs/2c-shopping.html (px → pt 1:1), README §Screens.3.
// The guarantee leads; runs are tiered by urgency. Urgent = yellow tint + the
// screen's single sticker moment — never red, never guilt — and every escalation
// carries a no-shame out ("can't — swap Thu to GF mac").

struct ShoppingView: View {
    @EnvironmentObject var appState: AppState

    /// Escalation actions — wiring happens later (AGENT_BRIEF §Navigation).
    var onRunAccepted: ((ShoppingRun) -> Void)? = nil
    var onSwapEscalation: ((ShoppingRun) -> Void)? = nil

    private var topUp: ShoppingRun? { appState.runs.first { $0.tier == .tonightTopUp } }
    private var weekly: ShoppingRun? { appState.runs.first { $0.tier == .weekly } }
    private var bulk: ShoppingRun? { appState.runs.first { $0.tier == .bulk } }
    private var atRiskNote: String? { appState.runs.compactMap(\.atRisk).first }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Shopping")
                .font(.baloo(30, .heavy))
                .foregroundStyle(Theme.ink)

            ShoppingGuaranteeBanner(headline: "Every dinner covered through Friday",
                                    atRisk: atRiskNote)

            if let topUp {
                ShoppingTopUpCard(run: topUp,
                                  onAccept: { onRunAccepted?(topUp) },
                                  onSwap: { onSwapEscalation?(topUp) })
            }
            if let weekly {
                ShoppingWeeklyCard(run: weekly)
            }
            if let bulk {
                ShoppingBulkCard(run: bulk)
            }

            Spacer(minLength: 0)

            ShoppingStockShelf(staples: appState.alwaysStocked)
        }
        .padding(EdgeInsets(top: 11, leading: 20, bottom: 10, trailing: 20))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.shelf.ignoresSafeArea())
    }
}

// MARK: - Guarantee banner (green tint, ink border, green hard shadow)

struct ShoppingGuaranteeBanner: View {
    var headline: String
    var atRisk: String?

    var body: some View {
        HStack(spacing: 9) {
            Text("✓")
                .font(.nunito(11, .black))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Palette.green.color, in: Circle())
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
            VStack(alignment: .leading, spacing: 0) {
                Text(headline)
                    .font(.nunito(14.5, .black))
                    .foregroundStyle(Theme.ink)
                if let atRisk {
                    Text(atRisk)
                        .font(.nunito(11.5, .heavy))
                        .foregroundStyle(Palette.green.labelMuted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14))
        .inkCard(background: Palette.green.tint, radius: 16)
        .hardShadow(Palette.green.color, x: 3, y: 3)
    }
}

// MARK: - Tonight top-up (urgent tier: yellow tint + the screen's one sticker)

struct ShoppingTopUpCard: View {
    var run: ShoppingRun
    var onAccept: () -> Void
    var onSwap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(shoppingRunDisplayTitle(run.title))
                    .font(.nunito(15, .black))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                // The single sticker moment on this screen (design law: max one).
                Text("\(run.items.count) ITEMS")
                    .font(.nunito(10.5, .black))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .inkCard(background: Palette.yellow.color, radius: 8)
                    .rotationEffect(.degrees(-2))
            }
            Text(run.protects)
                .font(.nunito(12.5, .heavy))
                .foregroundStyle(Palette.yellow.label)
                .padding(.top, 3)
            HStack(spacing: 7) {
                Button("on it", action: onAccept)
                    .buttonStyle(PillButtonStyle(background: Theme.ink,
                                                 foreground: .white,
                                                 font: .nunito(13, .black)))
                // Escalations ALWAYS carry a no-shame out (README §Interactions).
                Button("can't — swap Thu to GF mac", action: onSwap)
                    .buttonStyle(PillButtonStyle(background: Theme.paper,
                                                 foreground: Theme.ink,
                                                 font: .nunito(13, .black)))
            }
            .padding(.top, 9)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .inkCard(background: Palette.yellow.tint, radius: 18)
    }
}

// MARK: - Wednesday weekly (category count chips on palette tints)

struct ShoppingWeeklyCard: View {
    var run: ShoppingRun

    private static let chipTints: [Color] = [
        Palette.pink.tintAlt,   // #FFE3EE
        Palette.blue.tint,      // #E1F1FA
        Palette.purple.tint,    // #EFE8FA
        Palette.yellow.tint,    // #FFF4CE
        Palette.green.tint,     // #E9F5D3
    ]

    private var categoryCounts: [(name: String, count: Int)] {
        var firstIndex: [String: Int] = [:]
        var counts: [String: Int] = [:]
        for (i, item) in run.items.enumerated() {
            if firstIndex[item.category] == nil { firstIndex[item.category] = i }
            counts[item.category, default: 0] += 1
        }
        return counts
            .map { (name: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return firstIndex[$0.name]! < firstIndex[$1.name]!
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(shoppingRunDisplayTitle(run.title))
                    .font(.nunito(15, .black))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text("\(run.items.count) items · covers Wed→Fri")
                    .font(.nunito(11.5, .heavy))
                    .foregroundStyle(Theme.textSecondary)
            }
            ShoppingFlowLayout(spacing: 6) {
                ForEach(Array(categoryCounts.enumerated()), id: \.element.name) { i, entry in
                    Text("\(entry.name) \(entry.count)")
                        .font(.nunito(11.5, .black))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Self.chipTints[i % Self.chipTints.count], in: Capsule())
                }
            }
            .padding(.top, 8)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .inkCard(background: Theme.paper, radius: 18)
    }
}

// MARK: - Saturday Costco (bulk + project)

struct ShoppingBulkCard: View {
    var run: ShoppingRun

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(shoppingRunDisplayTitle(run.title))
                    .font(.nunito(15, .black))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text("\(run.items.count) items · bulk + birria")
                    .font(.nunito(11.5, .heavy))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text("chuck roast, dried chiles, the 900 granola bars Chad requires")
                .font(.nunito(12, .heavy))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 3)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .inkCard(background: Theme.paper, radius: 18)
    }
}

// MARK: - ALWAYS STOCKED shelf (the fallback guarantee, quiet)

struct ShoppingStockShelf: View {
    var staples: [ShoppingItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ALWAYS STOCKED")
                .font(.nunito(11, .black))
                .kerning(0.88) // .08em × 11
                .foregroundStyle(Theme.textSecondary)
            ShoppingFlowLayout(spacing: 6) {
                ForEach(staples) { item in
                    ShoppingStapleChip(item: item)
                }
            }
            .padding(.top, 7)
            Text("the fallback meal can ALWAYS be cooked from this shelf")
                .font(.nunito(11.5, .bold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .inkCard(background: Theme.fridge, radius: 18)
    }
}

struct ShoppingStapleChip: View {
    var item: ShoppingItem

    var body: some View {
        // Low stock is signalled by the " — low" suffix alone — chip styling
        // stays identical to stocked chips (mockup parity; never red, never urgent).
        Text(item.low ? "\(item.name) — low" : "\(item.name) ✓")
            .font(.nunito(11.5, .black))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .inkCard(background: Theme.paper,
                     radius: Theme.Radius.pill)
    }
}

// MARK: - Helpers

/// "Tonight top-up" → "Tonight · top-up" (mockup titles use a middot after the day).
private func shoppingRunDisplayTitle(_ title: String) -> String {
    guard let space = title.firstIndex(of: " ") else { return title }
    return title.replacingCharacters(in: space...space, with: " · ")
}

/// Minimal leading-aligned wrapping row for chips (flex-wrap equivalent).
struct ShoppingFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0, rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0, totalHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalWidth = max(totalWidth, rowWidth)
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        totalWidth = max(totalWidth, rowWidth)
        totalHeight += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ShoppingView()
        .environmentObject(AppState())
}
