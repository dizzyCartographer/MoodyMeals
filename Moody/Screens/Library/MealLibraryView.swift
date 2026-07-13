import SwiftUI

// MEAL LIBRARY (D-56 native) — every engine meal, searchable, editable.

struct MealLibraryView: View {
    @EnvironmentObject var appState: AppState

    @State private var search = ""
    @State private var showNew = false

    private var active: [LibraryMeal] { filtered.filter { !$0.isRetired } }
    private var retired: [LibraryMeal] { filtered.filter(\.isRetired) }

    private var filtered: [LibraryMeal] {
        let all = appState.library.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        guard !search.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(search)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(search) }
        }
    }

    var body: some View {
        List {
            if active.isEmpty && retired.isEmpty {
                Text(search.isEmpty ? "no meals on file" : "nothing matches “\(search)”")
                    .foregroundStyle(.secondary)
            }
            Section {
                ForEach(active) { meal in
                    NavigationLink(value: meal.id) { MealRow(meal: meal) }
                }
            }
            if !retired.isEmpty {
                Section("Retired") {
                    ForEach(retired) { meal in
                        NavigationLink(value: meal.id) {
                            MealRow(meal: meal).opacity(0.6)
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "search meals or tags")
        .navigationTitle("Meals")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNew = true } label: {
                    Label("New meal", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showNew) {
            MealFormView(mode: .create)
        }
    }
}

private struct MealRow: View {
    var meal: LibraryMeal

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(meal.name)
                    if meal.isAllTimer {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Palette.yellow.color)
                            .accessibilityLabel("all-time favorite")
                    }
                }
                HStack(spacing: 6) {
                    Text(meal.effortLabel)
                    if meal.isEatingOut { Text("· eating out") }
                    if !meal.tags.isEmpty { Text("· \(meal.tags.joined(separator: ", "))") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(meal.gfLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle((meal.gfSafe ? Palette.green : Palette.yellow).label)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background((meal.gfSafe ? Palette.green : Palette.yellow).tint, in: Capsule())
        }
    }
}
