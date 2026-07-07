import SwiftUI
import SwiftData

// ── M0-7: basic recipe CRUD (list + edit). Functional only. ──

struct RecipeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    @State private var newRecipe: Recipe?

    var body: some View {
        NavigationStack {
            List {
                ForEach(recipes) { recipe in
                    NavigationLink(value: recipe.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recipe.title.isEmpty ? "Untitled" : recipe.title)
                            Text("\(recipe.kind.rawValue) · \(recipe.items.count) ingredients")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteRecipes)
            }
            .navigationTitle("Recipes")
            .navigationDestination(for: UUID.self) { id in
                if let recipe = recipes.first(where: { $0.id == id }) {
                    RecipeEditView(recipe: recipe)
                }
            }
            .toolbar {
                Button("Add", systemImage: "plus") {
                    let recipe = Recipe(title: "", kind: .loose)
                    modelContext.insert(recipe)
                    newRecipe = recipe
                }
            }
            .sheet(item: $newRecipe) { recipe in
                NavigationStack { RecipeEditView(recipe: recipe, isNew: true) }
            }
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(recipes[index]) }
        try? modelContext.save()
    }
}

struct RecipeEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var recipe: Recipe
    var isNew = false

    @Query(sort: \Ingredient.name) private var catalog: [Ingredient]
    @State private var newIngredientName = ""

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Title", text: $recipe.title)
                Picker("Kind", selection: $recipe.kind) {
                    Text("Loose — no amounts needed").tag(RecipeKind.loose)
                    Text("Precise — amounts where you want them").tag(RecipeKind.precise)
                }
            }
            Section("Ingredients") {
                ForEach(recipe.items) { item in
                    RecipeItemRow(item: item, showAmount: recipe.kind == .precise)
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(recipe.items[index]) }
                    try? modelContext.save()
                }
                HStack {
                    TextField("Add ingredient", text: $newIngredientName)
                    Button("Add", systemImage: "plus.circle.fill") { addIngredient() }
                        .labelStyle(.iconOnly)
                        .disabled(newIngredientName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section("Steps (optional)") {
                ForEach(recipe.steps.indices, id: \.self) { index in
                    TextField("Step \(index + 1)", text: Binding(
                        get: { recipe.steps[index] },
                        set: { recipe.steps[index] = $0 }
                    ), axis: .vertical)
                }
                .onDelete { recipe.steps.remove(atOffsets: $0) }
                Button("Add step", systemImage: "plus") {
                    recipe.steps.append("")
                }
            }
        }
        .navigationTitle(isNew ? "New Recipe" : "Edit Recipe")
        .toolbar {
            if isNew {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        recipe.updatedAt = .now
                        try? modelContext.save()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        modelContext.delete(recipe)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            recipe.steps.removeAll { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            recipe.updatedAt = .now // F15 interim: touch on edit-screen exit
            try? modelContext.save()
        }
    }

    /// Reuses a catalog ingredient by name, else creates one UNVERIFIED —
    /// HC-7's rule: new food is never silently GF-verified.
    private func addIngredient() {
        let name = newIngredientName.trimmingCharacters(in: .whitespaces)
        let ingredient: Ingredient
        if let existing = catalog.first(where: { $0.name.lowercased() == name.lowercased() }) {
            ingredient = existing
        } else {
            ingredient = Ingredient(name: name, perishability: .pantry,
                                    isGlutenFreeVerified: nil) // unverified until checked
            modelContext.insert(ingredient)
        }
        let item = RecipeItem(ingredient: ingredient)
        modelContext.insert(item)
        recipe.items.append(item)
        newIngredientName = ""
        try? modelContext.save()
    }
}

private struct RecipeItemRow: View {
    @Bindable var item: RecipeItem
    let showAmount: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.ingredient.name)
                GFBadge(state: item.ingredient.isGlutenFreeVerified)
            }
            Spacer()
            if showAmount {
                // D-36: amounts optional even on precise — seasoning by taste.
                TextField("amt", value: $item.amount, format: .number)
                    .keyboardType(.decimalPad)
                    .frame(width: 56)
                    .multilineTextAlignment(.trailing)
                TextField("unit", text: Binding(
                    get: { item.unit ?? "" },
                    set: { item.unit = $0.isEmpty ? nil : $0 }
                ))
                .frame(width: 64)
            }
        }
    }
}

/// The tri-state made visible: verified ✓ / contains gluten / unverified (HC-3).
struct GFBadge: View {
    let state: Bool?

    var body: some View {
        switch state {
        case true: Text("GF verified ✓").font(.caption2).foregroundStyle(.green)
        case false: Text("contains gluten").font(.caption2).foregroundStyle(.orange)
        case nil: Text("GF unverified — check label").font(.caption2).foregroundStyle(.red)
        }
    }
}
