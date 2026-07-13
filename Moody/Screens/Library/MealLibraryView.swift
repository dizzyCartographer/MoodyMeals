import SwiftUI

// MEAL LIBRARY (B-1) — every engine meal, browsable and editable. Plain-but-kit
// register (M0-7's rule: no aesthetic invention, the design pass replaces this).
// D-54: this is a door to data that already existed — the engine was never
// the gap, the surface was.

struct MealLibraryView: View {
    @EnvironmentObject var appState: AppState
    var onOpenMeal: ((UUID) -> Void)?

    @State private var search = ""
    @State private var showNew = false

    private var meals: [LibraryMeal] {
        var all = appState.library
        if !search.isEmpty {
            all = all.filter {
                $0.name.localizedCaseInsensitiveContains(search)
                    || $0.tags.contains { $0.localizedCaseInsensitiveContains(search) }
            }
        }
        // retired sink to the bottom, everything else alphabetical
        return all.sorted {
            if $0.isRetired != $1.isRetired { return $1.isRetired }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Meals")
                        .font(.baloo(30, .heavy))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(appState.library.count)")
                        .font(.nunito(11.5, .heavy))
                        .foregroundStyle(Theme.textSecondary)
                }

                TextField("search meals or tags", text: $search)
                    .font(.nunito(13, .bold))
                    .foregroundStyle(Theme.ink)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .frame(height: 48)   // law 1: full-size target
                    .background(Theme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))

                Button("+ NEW MEAL") { showNew = true }
                    .buttonStyle(PillButtonStyle(background: Palette.yellow.color, emphasis: true))
                    .frame(height: 48)

                if meals.isEmpty {
                    Text(search.isEmpty ? "no meals on file" : "nothing matches “\(search)”")
                        .font(.nunito(12.5, .heavy))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(meals) { meal in
                            MealLibraryRow(meal: meal) { onOpenMeal?(meal.id) }
                        }
                    }
                }
            }
            .padding(EdgeInsets(top: 11, leading: 20, bottom: 20, trailing: 20))
        }
        .background(Theme.shelf.ignoresSafeArea())
        .sheet(isPresented: $showNew) {
            MealFormView(mode: .create)
        }
    }
}

private struct MealLibraryRow: View {
    var meal: LibraryMeal
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(meal.name)
                            .font(.nunito(14.5, .black))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        if meal.isAllTimer {
                            Text("★")
                                .font(.nunito(12, .black))
                                .foregroundStyle(Palette.yellow.label)
                                .accessibilityLabel("all-time favorite")
                        }
                    }
                    HStack(spacing: 6) {
                        if meal.isRetired {
                            Text("retired")
                                .font(.nunito(10.5, .black))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Theme.shelf, in: Capsule())
                        }
                        if meal.isEatingOut {
                            Text("eating out")
                                .font(.nunito(10.5, .black))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        if !meal.tags.isEmpty {
                            Text(meal.tags.joined(separator: " · "))
                                .font(.nunito(10.5, .heavy))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 8)
                EffortDots(effort: meal.effortDots)
                Text(meal.gfLabel)
                    .font(.nunito(10.5, .black))
                    .foregroundStyle((meal.gfSafe ? Palette.green : Palette.yellow).label)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((meal.gfSafe ? Palette.green : Palette.yellow).tint,
                                in: Capsule())
            }
            .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .inkCard(background: Theme.paper, radius: 16)
            .opacity(meal.isRetired ? 0.55 : 1)
        }
        .buttonStyle(.plain)
    }
}
