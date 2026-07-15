import SwiftUI

// MEAL DETAIL (D-56 native) — truthful, engine-backed: per-member badges,
// full recipes with per-line GF chips, editable composition. Retire never
// deletes (D-39 spirit; D-37 rails keep planned entries flagged).

struct MealDetailView: View {
    @EnvironmentObject var appState: AppState
    let id: UUID

    private struct RecipeSheetTarget: Identifiable { let id: UUID }

    @State private var showEdit = false
    @State private var confirmRetire = false
    @State private var showNewRecipe = false
    @State private var showAttach = false
    @State private var editingRecipe: RecipeSheetTarget?

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

                ForEach(meal.recipes) { recipe in
                    Section {
                        if recipe.items.isEmpty {
                            Text("no ingredient lines yet")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                        ForEach(recipe.items) { item in
                            IngredientLine(item: item)
                        }
                    } header: {
                        HStack {
                            NavigationLink(value: RecipeRoute(id: recipe.id)) {
                                HStack {
                                    Text("\(recipe.title) · \(recipe.kindLabel)")
                                    Text(BandStyle.label(recipe.bandRaw))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle((BandStyle.isGreen(recipe.bandRaw)
                                            ? Palette.green : Palette.yellow).label)
                                        .textCase(nil)
                                }
                            }
                            .textCase(nil)
                            Spacer()
                            Button("Edit") { editingRecipe = .init(id: recipe.id) }
                                .font(.caption.weight(.semibold))
                                .textCase(nil)
                        }
                    } footer: {
                        if !recipe.steps.isEmpty {
                            Text(recipe.steps.enumerated()
                                .map { "\($0.offset + 1). \($0.element)" }
                                .joined(separator: "\n"))
                        }
                    }
                }

                Section("Extra items (no recipe)") {
                    if meal.directItems.isEmpty {
                        Text("none")
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
                    AddItemFields(target: .direct(meal.id))
                }

                Section {
                    Menu {
                        Button("New recipe") { showNewRecipe = true }
                        Button("Attach an existing recipe") { showAttach = true }
                    } label: {
                        Label("Add a recipe", systemImage: "plus")
                    }
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
            .sheet(item: $editingRecipe) { target in
                RecipeFormView(mealID: id, recipeID: target.id)
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
