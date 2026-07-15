import SwiftUI

// MEAL DETAIL (D-56 native) — truthful, engine-backed: per-member badges,
// full recipes with per-line GF chips, editable composition. Retire never
// deletes (D-39 spirit; D-37 rails keep planned entries flagged).

struct MealDetailView: View {
    @EnvironmentObject var appState: AppState
    let id: UUID

    @State private var showEdit = false
    @State private var confirmRetire = false
    @State private var showNewRecipe = false
    @State private var showAttach = false

    private var meal: LibraryMeal? { appState.library.first { $0.id == id } }

    var body: some View {
        if let meal {
            List {
                if !meal.badges.isEmpty {
                    Section("For this house") {
                        BadgeRow(badges: meal.badges)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16,
                                                      bottom: 8, trailing: 16))
                    }
                }

                Section("About") {
                    LabeledContent("Effort", value: meal.effortLabel)
                    LabeledContent("Slots", value: meal.slots.joined(separator: ", "))
                    if !meal.tags.isEmpty {
                        LabeledContent("Tags", value: meal.tags.joined(separator: ", "))
                    }
                    if meal.requiresCalmDay { LabeledContent("Calm days only", value: "yes") }
                    if meal.isEatingOut { LabeledContent("Eating out", value: "yes") }
                    if meal.isRetired { LabeledContent("Retired", value: "yes") }
                    if !meal.notes.isEmpty {
                        Text(meal.notes)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                // Collapsed on purpose: a recipe's full ingredients/steps
                // live on its own read screen (RecipeDetailView) — the meal
                // page shows what recipes make up this meal, not their
                // entire contents. A meal can hold more than one (a main
                // plus a side), which is exactly why this is a list of
                // doors, not an inline dump.
                Section("Recipes") {
                    if meal.recipes.isEmpty {
                        Text("no recipes yet")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    ForEach(meal.recipes) { recipe in
                        NavigationLink(value: RecipeRoute(id: recipe.id)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recipe.title)
                                    Text("\(recipe.items.count) ingredient\(recipe.items.count == 1 ? "" : "s") · \(recipe.kindLabel)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(BandStyle.label(recipe.bandRaw))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle((BandStyle.isGreen(recipe.bandRaw)
                                        ? Palette.green : Palette.yellow).label)
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background((BandStyle.isGreen(recipe.bandRaw)
                                        ? Palette.green : Palette.yellow).tint, in: Capsule())
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Remove from meal", role: .destructive) {
                                appState.detachRecipe(recipe.id, fromMeal: id)
                            }
                        }
                    }
                    Menu {
                        Button("New recipe") { showNewRecipe = true }
                        Button("Attach an existing recipe") { showAttach = true }
                    } label: {
                        Label("Add a recipe", systemImage: "plus")
                    }
                }

                Section {
                    if meal.directItems.isEmpty {
                        Text("none yet")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    ForEach(meal.directItems) { item in
                        IngredientLine(item: item)
                            .swipeActions(edge: .trailing) {
                                Button("Remove", role: .destructive) {
                                    appState.removeItem(item.id)
                                }
                            }
                    }
                    AddItemFields(target: .direct(meal.id), placeholder: "add an item — e.g. a wine pairing")
                } header: {
                    Text("Extra items")
                } footer: {
                    Text("anything that isn't a recipe of its own — a wine pairing, a side you're grabbing pre-made, a garnish")
                }

                Section {
                    Button(meal.isRetired ? "Bring back into rotation" : "Retire this meal") {
                        if meal.isRetired {
                            appState.setMealRetired(id, false)
                        } else {
                            confirmRetire = true
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(meal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showEdit = true }
                }
            }
            .sheet(isPresented: $showEdit) {
                if let draft = appState.draft(for: id) {
                    MealFormView(mode: .edit(id), initial: draft)
                }
            }
            .sheet(isPresented: $showNewRecipe) {
                RecipeFormView(mealID: id, recipeID: nil)
            }
            .sheet(isPresented: $showAttach) {
                AttachRecipeSheet(mealID: id,
                                  attachedIDs: Set(meal.recipes.map(\.id)))
            }
            .confirmationDialog("Retire this meal?", isPresented: $confirmRetire,
                                titleVisibility: .visible) {
                Button("Retire — hides from pickers, keeps history") {
                    appState.setMealRetired(id, true)
                }
                Button("Cancel", role: .cancel) {}
            }
        } else {
            Text("this meal isn't on file anymore")
                .foregroundStyle(.secondary)
        }
    }
}

/// Attach an existing first-class recipe to this meal.
private struct AttachRecipeSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let mealID: UUID
    let attachedIDs: Set<UUID>

    private var candidates: [RecipeSummary] {
        appState.recipesAll.filter { !attachedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if candidates.isEmpty {
                    Text("every recipe on file is already in this meal")
                        .foregroundStyle(.secondary)
                }
                ForEach(candidates) { recipe in
                    Button {
                        appState.attachRecipe(recipe.id, toMeal: mealID)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recipe.title).foregroundStyle(.primary)
                            Text(recipe.usedIn.isEmpty
                                 ? "\(recipe.kindLabel) · not in a meal yet"
                                 : "\(recipe.kindLabel) · in \(recipe.usedIn.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Attach a recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct IngredientLine: View {
    var item: LibraryRecipeItem

    var body: some View {
        HStack(spacing: 8) {
            Text(item.name)
            if !item.amountText.isEmpty {
                Text(item.amountText)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            Spacer(minLength: 4)
            Text(item.gfLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle((item.gfSafe ? Palette.green : Palette.yellow).label)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background((item.gfSafe ? Palette.green : Palette.yellow).tint, in: Capsule())
        }
    }
}
