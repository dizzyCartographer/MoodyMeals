import SwiftUI

// MEALS | RECIPES (Ria 2026-07-13: "a meal is a collection of recipes,
// even if they are loose recipes") — one tab, two first-class lists.

struct MealLibraryView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case meals = "Meals", recipes = "Recipes"
        var id: String { rawValue }
    }

    @EnvironmentObject var appState: AppState
    @State private var segment: Segment = .meals
    @State private var search = ""
    @State private var showNewMeal = false
    @State private var newRecipeSheet = false
    @State private var showPasteRecipe = false

    var body: some View {
        Group {
            switch segment {
            case .meals: mealsList
            case .recipes: recipesList
            }
        }
        .searchable(text: $search, prompt: segment == .meals
            ? "search meals or tags" : "search recipes")
        .navigationTitle(segment.rawValue)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Kind", selection: $segment) {
                    ForEach(Segment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
            ToolbarItem(placement: .primaryAction) {
                if segment == .meals {
                    Menu {
                        Button {
                            showNewMeal = true
                        } label: {
                            Label("New meal", systemImage: "plus")
                        }
                        Button {
                            showPasteRecipe = true
                        } label: {
                            Label("Paste a recipe", systemImage: "doc.on.clipboard")
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                } else {
                    Button {
                        newRecipeSheet = true
                    } label: {
                        Label("New recipe", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showNewMeal) {
            MealFormView(mode: .create)
        }
        .sheet(isPresented: $newRecipeSheet) {
            RecipeFormView(mealID: nil, recipeID: nil)   // standalone
        }
        .sheet(isPresented: $showPasteRecipe) {
            RecipePasteView()
        }
    }

    // MARK: Meals

    private var activeMeals: [LibraryMeal] { filteredMeals.filter { !$0.isRetired } }
    private var retiredMeals: [LibraryMeal] { filteredMeals.filter(\.isRetired) }

    private var filteredMeals: [LibraryMeal] {
        let all = appState.library.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        guard !search.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(search)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(search) }
        }
    }

    private var mealsList: some View {
        List {
            if activeMeals.isEmpty && retiredMeals.isEmpty {
                Text(search.isEmpty ? "no meals on file" : "nothing matches “\(search)”")
                    .foregroundStyle(.secondary)
            }
            Section {
                ForEach(activeMeals) { meal in
                    NavigationLink(value: meal.id) { MealRow(meal: meal) }
                }
            }
            if !retiredMeals.isEmpty {
                Section("Retired") {
                    ForEach(retiredMeals) { meal in
                        NavigationLink(value: meal.id) {
                            MealRow(meal: meal).opacity(0.6)
                        }
                    }
                }
            }
        }
    }

    // MARK: Recipes

    private var filteredRecipes: [RecipeSummary] {
        guard !search.isEmpty else { return appState.recipesAll }
        return appState.recipesAll.filter {
            $0.title.localizedCaseInsensitiveContains(search)
        }
    }

    private var recipesList: some View {
        List {
            if filteredRecipes.isEmpty {
                Text(search.isEmpty
                     ? "no recipes yet — they also appear here when added to a meal"
                     : "nothing matches “\(search)”")
                    .foregroundStyle(.secondary)
            }
            ForEach(filteredRecipes) { recipe in
                RecipeSummaryRow(recipe: recipe)
            }
        }
    }
}

private struct RecipeSummaryRow: View {
    var recipe: RecipeSummary
    @State private var editing = false

    var body: some View {
        Button {
            editing = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(recipe.title).foregroundStyle(.primary)
                    Spacer()
                    Text("\(recipe.itemCount) ingredient\(recipe.itemCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(recipe.usedIn.isEmpty
                     ? "\(recipe.kindLabel) · not in a meal yet"
                     : "\(recipe.kindLabel) · in \(recipe.usedIn.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .sheet(isPresented: $editing) {
            RecipeFormView(mealID: nil, recipeID: recipe.id)
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
