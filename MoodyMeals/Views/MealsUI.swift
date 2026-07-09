import SwiftUI
import SwiftData

// ── M0-7: basic meal CRUD (list + edit). Functional only — visual design
// is a review-window task (CLAUDE.md: no autonomous aesthetic iteration). ──

struct MealListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meal.title) private var meals: [Meal]
    @State private var newMeal: Meal?

    var body: some View {
        NavigationStack {
            List {
                ForEach(meals) { meal in
                    NavigationLink(value: meal.id) {
                        MealRow(meal: meal)
                    }
                }
                .onDelete(perform: deleteMeals)
            }
            .navigationTitle("Meals")
            .navigationDestination(for: UUID.self) { id in
                if let meal = meals.first(where: { $0.id == id }) {
                    MealEditView(meal: meal)
                }
            }
            .toolbar {
                Button("Add", systemImage: "plus") {
                    let meal = Meal(title: "")
                    modelContext.insert(meal)
                    newMeal = meal
                }
            }
            .sheet(item: $newMeal) { meal in
                NavigationStack { MealEditView(meal: meal, isNew: true) }
            }
        }
    }

    private func deleteMeals(at offsets: IndexSet) {
        // Safe by D-37: scores cascade, plan entries flag, breakfasts nil.
        for index in offsets { modelContext.delete(meals[index]) }
        try? modelContext.save()
    }
}

private struct MealRow: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(meal.title.isEmpty ? "Untitled" : meal.title)
                if meal.isAllTimeFavorite { Image(systemName: "star.fill") }
                if meal.isEatingOut { Image(systemName: "takeoutbag.and.cup.and.straw") }
            }
            HStack(spacing: 8) {
                Text(meal.effort.label)
                if meal.rotationState != .active {
                    Text(meal.rotationState.rawValue)
                }
                if !meal.themeTags.isEmpty {
                    Text(meal.themeTags.joined(separator: " · "))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct MealEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var meal: Meal
    var isNew = false

    @State private var tagsText = ""

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Title", text: $meal.title)
                TextField("Notes (commentary — D-38)", text: $meal.freeformNotes,
                          axis: .vertical)
                Picker("Effort", selection: $meal.effort) {
                    ForEach(EffortLevel.allCases, id: \.self) { Text($0.label) }
                }
            }
            Section("Slots") {
                Toggle("Dinner", isOn: slotBinding(.dinner))
                Toggle("Lunch", isOn: slotBinding(.lunch)) // D-40
                Toggle("Breakfast", isOn: slotBinding(.breakfast))
                Toggle("Needs a calm day", isOn: $meal.requiresCalmDay)
            }
            Section("Tags") {
                TextField("Theme tags (comma-separated)", text: $tagsText)
                    .onSubmit { meal.themeTags = parseTags(tagsText) }
            }
            Section("Rotation") {
                Picker("Frequency target", selection: $meal.frequencyTarget) {
                    Text("No target").tag(FrequencyTarget?.none)
                    ForEach([FrequencyTarget.weekly, .biweekly, .monthly,
                             .quarterly, .occasionally], id: \.self) {
                        Text($0.rawValue).tag(FrequencyTarget?.some($0))
                    }
                }
                Toggle("All-time favorite", isOn: $meal.isAllTimeFavorite)
                Toggle("Eating out (never auto-scheduled)", isOn: $meal.isEatingOut)
            }
            Section("Composition") {
                ForEach(meal.recipes) { recipe in
                    LabeledContent(recipe.title, value: recipe.kind.rawValue)
                }
                if meal.recipes.isEmpty && meal.directItems.isEmpty {
                    Text("Freeform meal — no listed ingredients")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Caddie-safe (GF verified)",
                               value: meal.isGFVerifiedForCeliac ? "Yes" : "Not verified")
            }
        }
        .navigationTitle(isNew ? "New Meal" : "Edit Meal")
        .toolbar {
            if isNew {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveAndClose() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        modelContext.delete(meal)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .onAppear { tagsText = meal.themeTags.joined(separator: ", ") }
        .onDisappear {
            meal.themeTags = parseTags(tagsText)
            meal.updatedAt = .now // F15 interim: touch on edit-screen exit
            try? modelContext.save()
        }
    }

    private func saveAndClose() {
        meal.themeTags = parseTags(tagsText)
        meal.updatedAt = .now
        try? modelContext.save()
        dismiss()
    }

    private func slotBinding(_ slot: SlotKind) -> Binding<Bool> {
        Binding(
            get: { meal.slots.contains(slot) },
            set: { on in
                if on, !meal.slots.contains(slot) { meal.slots.append(slot) }
                if !on { meal.slots.removeAll { $0 == slot } }
            }
        )
    }

    private func parseTags(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }
}

extension EffortLevel: CaseIterable {
    public static var allCases: [EffortLevel] { [.noCook, .assembly, .simple, .involved] }

    var label: String {
        switch self {
        case .noCook: "no-cook"
        case .assembly: "assembly"
        case .simple: "simple"
        case .involved: "involved"
        }
    }
}
