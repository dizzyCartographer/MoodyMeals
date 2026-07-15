import SwiftUI

// RECIPE EDITOR (D-56 native) — live-edit model: item adds/removes hit the
// engine immediately; title/kind/steps apply on save. New ingredients enter
// the catalog UNVERIFIED per HC-7 — the form says so before you add one.

struct RecipeFormView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// nil = a standalone recipe (first-class, not attached to a meal yet).
    let mealID: UUID?
    /// nil = creating; set once saved (the form transitions to item editing).
    @State var recipeID: UUID?

    @State private var title = ""
    @State private var precise = false
    @State private var stepsText = ""
    @State private var modificationText = ""
    @State private var sourceText = ""
    @State private var confirmDelete = false

    private func bandFooter(_ recipe: LibraryRecipe) -> String {
        var parts: [String] = []
        switch recipe.bandSourceRaw {
        case "manualOverride": parts.append("you set this — it stays until you change it")
        case "assessment": parts.append("checked automatically when this was imported")
        default: parts.append("based on the ingredients below")
        }
        if !recipe.standardModification.isEmpty {
            parts.append("with that swap on file, this recipe is GF")
        }
        return parts.joined(separator: " · ")
    }

    /// True when any ingredient still reads "check label" and might
    /// actually be a plain whole food the deterministic check would clear —
    /// this only ever happens on recipes captured before that check ran.
    private var hasUncheckedItems: Bool {
        recipe?.items.contains { $0.gfLabel == "check label" } ?? false
    }

    private var recipe: LibraryRecipe? {
        guard let recipeID else { return nil }
        return appState.libraryRecipe(recipeID)   // attached or standalone
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
                    // FR-1 (D-44): the band, its provenance, and the quiche
                    // move. Display truth today; gates arrive with D-57.
                    Section {
                        HStack {
                            Text("Gluten-free status")
                            Spacer()
                            Text(BandStyle.label(recipe.bandRaw))
                                .font(.callout.weight(.semibold))
                                .foregroundStyle((BandStyle.isGreen(recipe.bandRaw)
                                    ? Palette.green : Palette.yellow).label)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background((BandStyle.isGreen(recipe.bandRaw)
                                    ? Palette.green : Palette.yellow).tint, in: Capsule())
                        }
                        Menu("Change status") {
                            Button("GF safe") { appState.setRecipeBand(recipe.id, bandRaw: "safe") }
                            Button("Awaiting substitution") {
                                appState.setRecipeBand(recipe.id, bandRaw: "awaitingSubstitution")
                            }
                            Button("Unsafe for GF") { appState.setRecipeBand(recipe.id, bandRaw: "unsafe") }
                            Button("Not checked yet") {
                                appState.setRecipeBand(recipe.id, bandRaw: "notCheckedYet")
                            }
                        }
                        if hasUncheckedItems {
                            Button("Recheck ingredients") {
                                appState.recheckGlutenCarriers(inRecipe: recipe.id)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GF substitute (optional)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                TextField("e.g. King Arthur gf pie crust mix",
                                          text: $modificationText, axis: .vertical)
                                    .lineLimit(1...2)
                                Button("Save") {
                                    appState.setStandardModification(recipe.id,
                                                                     text: modificationText)
                                }
                                .disabled(modificationText == recipe.standardModification)
                            }
                        }
                    } footer: {
                        Text(bandFooter(recipe))
                    }

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

                    Section("Source (optional)") {
                        TextField("a URL or cookbook title", text: $sourceText)
                            .autocorrectionDisabled()
                    }

                    Section {
                        Button(mealID == nil ? "Delete this recipe"
                               : "Remove this recipe from the meal",
                               role: .destructive) {
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
                                                  precise: precise, stepsText: stepsText,
                                                  sourceText: sourceText)
                            dismiss()
                        } else if let mealID {
                            recipeID = appState.addRecipe(toMeal: mealID,
                                                          title: title, precise: precise)
                        } else {
                            recipeID = appState.createStandaloneRecipe(
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
                    modificationText = recipe.standardModification
                    sourceText = recipe.source
                }
            }
            .confirmationDialog(mealID == nil ? "Delete this recipe?" : "Remove this recipe from the meal?",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                if let mealID {
                    Button("Remove — the recipe itself stays, still usable elsewhere", role: .destructive) {
                        if let recipeID { appState.detachRecipe(recipeID, fromMeal: mealID) }
                        dismiss()
                    }
                } else {
                    Button("Delete", role: .destructive) {
                        if let recipeID { appState.deleteRecipe(recipeID) }
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

/// Name (with catalog suggestions), optional amount + unit, and — only when
/// the name is new — a storage picker plus the honest HC-7 note. `placeholder`
/// lets each call site say what kind of thing goes here (an ingredient, or —
/// on a meal's "Extra items" — anything from a wine pairing to a side).
struct AddItemFields: View {
    @EnvironmentObject var appState: AppState
    var target: AppState.ItemTarget
    var placeholder: String = "add an ingredient"

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
            TextField(placeholder, text: $name)
                .autocorrectionDisabled()
                .accessibilityIdentifier("addItemName")
            HStack {
                TextField("amount", text: $amountText)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("addItemAmount")
                TextField("unit", text: $unit)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("addItemUnit")
                Button("Add") { add() }
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedName.isEmpty)
                    .accessibilityIdentifier("addItemAddButton")
            }
            Text("amount and unit are both optional")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
