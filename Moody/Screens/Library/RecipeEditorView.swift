import SwiftUI

// RECIPE EDITOR (B-2) — create/edit a recipe and its ingredient lines.
// Live-edit model: item adds/removes hit the engine immediately (undo = the
// ✕ on the line); title/kind/steps apply on SAVE. New ingredients enter the
// catalog UNVERIFIED per HC-7 — the form says so before you add one.

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
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(recipeID == nil ? "New recipe" : "Edit recipe")
                    .font(.baloo(26, .heavy))
                    .foregroundStyle(Theme.ink)

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "NAME")
                    TextField("what's this component called?", text: $title)
                        .font(.nunito(13, .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 13).padding(.vertical, 12)
                        .background(Theme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
                }

                SectionLabel(text: "KIND")
                HStack(spacing: 6) {
                    RecipeSelectChip(text: "loose — amounts optional", selected: !precise) {
                        precise = false
                    }
                    RecipeSelectChip(text: "precise", selected: precise) {
                        precise = true
                    }
                }
                // D-36: precise recipes may still carry amount-less lines
                // ("all seasoning by taste") — no validation gate either way.

                if let recipe {
                    VStack(alignment: .leading, spacing: 7) {
                        SectionLabel(text: "INGREDIENTS")
                        if recipe.items.isEmpty {
                            Text("no lines yet — add the first below")
                                .font(.nunito(12, .heavy))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        ForEach(recipe.items) { item in
                            IngredientLineRow(item: item) {
                                appState.removeItem(item.id)
                            }
                        }
                    }
                    .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .inkCard(background: Theme.paper, radius: 16)

                    AddItemArea(target: .recipe(recipe.id))

                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "STEPS (one per line, optional)")
                        TextField("chop · sizzle · serve", text: $stepsText, axis: .vertical)
                            .font(.nunito(13, .bold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(3...8)
                            .padding(.horizontal, 13).padding(.vertical, 12)
                            .background(Theme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
                    }
                }

                Button(recipeID == nil ? "CREATE — THEN ADD INGREDIENTS" : "SAVE") {
                    if let recipeID {
                        appState.updateRecipe(recipeID, title: title,
                                              precise: precise, stepsText: stepsText)
                        dismiss()
                    } else {
                        recipeID = appState.addRecipe(toMeal: mealID,
                                                      title: title, precise: precise)
                    }
                }
                .buttonStyle(PillButtonStyle(background: Palette.yellow.color, emphasis: true))
                .frame(height: 48)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)

                if recipeID != nil {
                    Button("remove this recipe from the meal") { confirmDelete = true }
                        .font(.nunito(12, .heavy))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                Button("close") { dismiss() }
                    .font(.nunito(12, .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .padding(20)
        }
        .background(Theme.shelf.ignoresSafeArea())
        .onAppear {
            if let recipe {
                title = recipe.title
                precise = recipe.kindLabel == "precise"
                stepsText = recipe.steps.joined(separator: "\n")
            }
        }
        .confirmationDialog("Remove this recipe?", isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("remove — the meal itself stays", role: .destructive) {
                if let recipeID { appState.deleteRecipe(recipeID) }
                dismiss()
            }
            Button("cancel", role: .cancel) {}
        }
    }
}

// MARK: - Shared pieces (also used for direct items from the meal detail)

struct IngredientLineRow: View {
    var item: LibraryRecipeItem
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.nunito(12.5, .heavy))
                    .foregroundStyle(Theme.ink)
                if !item.amountText.isEmpty {
                    Text(item.amountText)
                        .font(.nunito(11, .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            Text(item.gfLabel)
                .font(.nunito(10, .black))
                .foregroundStyle((item.gfSafe ? Palette.green : Palette.yellow).label)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background((item.gfSafe ? Palette.green : Palette.yellow).tint, in: Capsule())
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 40)   // comfortable target
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(item.name)")
        }
    }
}

/// Name (with catalog suggestions), optional amount + unit, and — only when
/// the name is new to the catalog — a storage picker plus the honest HC-7
/// note that it enters as check-label.
struct AddItemArea: View {
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
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: "ADD INGREDIENT")
            TextField("ingredient", text: $name)
                .font(.nunito(13, .bold))
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .padding(.horizontal, 13).padding(.vertical, 11)
                .background(Theme.shelf)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: 1))

            if !suggestions.isEmpty {
                ShoppingFlowLayout(spacing: 5) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) { name = suggestion }
                            .font(.nunito(11, .black))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Theme.shelf, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1))
                            .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 6) {
                TextField("amount", text: $amountText)
                    .keyboardType(.decimalPad)
                    .frame(width: 76)
                TextField("unit", text: $unit)
                    .autocorrectionDisabled()
                    .frame(width: 86)
                Spacer(minLength: 0)
                Button("ADD") { add() }
                    .buttonStyle(PillButtonStyle(background: Palette.green.color))
                    .disabled(trimmedName.isEmpty)
                    .opacity(trimmedName.isEmpty ? 0.45 : 1)
            }
            .font(.nunito(13, .bold))
            .textFieldStyle(.roundedBorder)

            if isNew {
                Text("new ingredient — enters the catalog as check-label")
                    .font(.nunito(10.5, .heavy))
                    .foregroundStyle(Palette.yellow.label)
                HStack(spacing: 5) {
                    ForEach(Self.storage, id: \.raw) { option in
                        RecipeSelectChip(text: option.label,
                                         selected: perishability == option.raw) {
                            perishability = option.raw
                        }
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .inkCard(background: Theme.paper, radius: 16)
    }

    private func add() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: "."))
        appState.addItem(target, name: trimmedName,
                         amount: amount, unit: unit, perishabilityRaw: perishability)
        name = ""; amountText = ""; unit = ""; perishability = "pantry"
    }
}

struct RecipeSelectChip: View {
    var text: String
    var selected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.nunito(11, .black))
                .foregroundStyle(selected ? Theme.paper : Theme.ink)
                .padding(.horizontal, 10)
                .frame(minHeight: 38)
                .background(selected ? Theme.ink : Theme.paper, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
        }
        .buttonStyle(.plain)
    }
}
