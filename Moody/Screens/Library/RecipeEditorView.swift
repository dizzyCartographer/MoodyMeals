import SwiftUI

// RECIPE EDITOR (D-56 native) — live-edit model: item adds/removes hit the
// engine immediately; title/kind/steps apply on save. New ingredients enter
// the catalog UNVERIFIED per HC-7 — the form says so before you add one.

struct RecipeFormView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mealID: UUID
    /// nil = creating; set once saved (the form transitions to item editing).
    @State var recipeID: UUID?

    @State private var title = ""
    @State private var precise = false
    @State private var stepsText = ""
    @State private var confirmDelete = false

    private var recipe: LibraryRecipe? {
        guard let recipeID else { return nil }
        return appState.library.first { $0.id == mealID }?
            .recipes.first { $0.id == recipeID }
    }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Recipe name", text: $title)
                    Picker("Kind", selection: $precise) {
                        Text("loose — amounts optional").tag(false)
                        Text("precise").tag(true)
                    }
                    .pickerStyle(.segmented)
                    // D-36: precise recipes may still carry amount-less lines.
                }

                if let recipe {
                    Section("Ingredients") {
                        if recipe.items.isEmpty {
                            Text("no lines yet — add the first below")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                        ForEach(recipe.items) { item in
                            IngredientLine(item: item)
                                .swipeActions(edge: .trailing) {
                                    Button("Remove", role: .destructive) {
                                        appState.removeItem(item.id)
                                    }
                                }
                        }
                        AddItemFields(target: .recipe(recipe.id))
                    }

                    Section("Steps (one per line, optional)") {
                        TextField("chop · sizzle · serve", text: $stepsText, axis: .vertical)
                            .lineLimit(3...8)
                    }

                    Section {
                        Button("Remove this recipe from the meal", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .navigationTitle(recipeID == nil ? "New recipe" : "Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(recipeID == nil ? "Cancel" : "Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(recipeID == nil ? "Create" : "Save") {
                        if let recipeID {
                            appState.updateRecipe(recipeID, title: title,
                                                  precise: precise, stepsText: stepsText)
                            dismiss()
                        } else {
                            recipeID = appState.addRecipe(toMeal: mealID,
                                                          title: title, precise: precise)
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let recipe {
                    title = recipe.title
                    precise = recipe.kindLabel == "precise"
                    stepsText = recipe.steps.joined(separator: "\n")
                }
            }
            .confirmationDialog("Remove this recipe?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Remove — the meal itself stays", role: .destructive) {
                    if let recipeID { appState.deleteRecipe(recipeID) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

/// Name (with catalog suggestions), optional amount + unit, and — only when
/// the name is new — a storage picker plus the honest HC-7 note.
struct AddItemFields: View {
    @EnvironmentObject var appState: AppState
    var target: AppState.ItemTarget

    @State private var name = ""
    @State private var amountText = ""
    @State private var unit = ""
    @State private var perishability = "pantry"

    private static let storage: [(raw: String, label: String)] = [
        ("pantry", "pantry"), ("freezer", "freezer"),
        ("refrigeratedLong", "fridge"), ("freshShort", "fresh"),
    ]

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var isNew: Bool { !trimmedName.isEmpty && !appState.isKnownIngredient(trimmedName) }
    private var suggestions: [String] {
        let s = appState.ingredientSuggestions(for: trimmedName)
        return s == [trimmedName] ? [] : s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("add ingredient", text: $name)
                    .autocorrectionDisabled()
                TextField("amt", text: $amountText)
                    .keyboardType(.decimalPad)
                    .frame(width: 52)
                TextField("unit", text: $unit)
                    .autocorrectionDisabled()
                    .frame(width: 64)
                Button("Add") { add() }
                    .disabled(trimmedName.isEmpty)
            }
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) { name = suggestion }
                                .font(.caption)
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            if isNew {
                Text("new ingredient — enters the catalog as check-label")
                    .font(.caption)
                    .foregroundStyle(Palette.yellow.label)
                Picker("Storage", selection: $perishability) {
                    ForEach(Self.storage, id: \.raw) { option in
                        Text(option.label).tag(option.raw)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func add() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: "."))
        appState.addItem(target, name: trimmedName,
                         amount: amount, unit: unit, perishabilityRaw: perishability)
        name = ""; amountText = ""; unit = ""; perishability = "pantry"
    }
}
