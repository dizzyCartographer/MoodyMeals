import SwiftUI

// MEAL FORM (D-56 native) — create/edit. Engine vocabulary shown truthfully;
// MealDraft keeps engine enums out of views.

struct MealFormView: View {
    enum Mode { case create, edit(UUID) }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    @State var initial = MealDraft()
    @State private var draft = MealDraft()
    @State private var editingItem: LibraryRecipeItem?

    private var editID: UUID? { if case .edit(let id) = mode { id } else { nil } }
    private var directItems: [LibraryRecipeItem] {
        guard let editID else { return [] }
        return appState.library.first { $0.id == editID }?.directItems ?? []
    }

    private static let efforts: [(raw: Int, label: String)] =
        [(0, "no cook"), (1, "assembly"), (2, "simple"), (3, "involved")]
    private static let slotOptions = ["dinner", "breakfast", "lunch"]

    private var isCreate: Bool { if case .create = mode { true } else { false } }
    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.title)
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Effort") {
                    Picker("Effort", selection: $draft.effortRaw) {
                        ForEach(Self.efforts, id: \.raw) { option in
                            Text(option.label).tag(option.raw)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Slots") {
                    ForEach(Self.slotOptions, id: \.self) { slot in
                        Toggle(slot.capitalized, isOn: Binding(
                            get: { draft.slots.contains(slot) },
                            set: { on in
                                if on { draft.slots.insert(slot) }
                                else { draft.slots.remove(slot) }
                            }))
                    }
                }

                Section {
                    TextField("Tags (comma-separated)", text: $draft.tagsText)
                        .autocorrectionDisabled()
                    Toggle("All-time favorite", isOn: $draft.isAllTimer)
                    Toggle("Eating out (never auto-scheduled)", isOn: $draft.isEatingOut)
                    Toggle("Calm days only", isOn: $draft.requiresCalmDay)
                }

                // Only reachable once the meal exists (needs an id to hang
                // items off of) — same add/tap-to-edit/swipe-to-remove as
                // the meal detail page's own Extra items section, so
                // there's no dead end for anyone editing straight from here.
                if let editID {
                    Section {
                        // Add controls first — same reasoning as the meal
                        // detail page: a bottom-anchored add row can end up
                        // off-screen behind however many items already exist.
                        AddItemFields(target: .direct(editID),
                                     placeholder: "add an item — e.g. a wine pairing")
                        if directItems.isEmpty {
                            Text("none yet")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                        ForEach(directItems) { item in
                            Button {
                                editingItem = item
                            } label: {
                                IngredientLine(item: item)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button("Remove", role: .destructive) {
                                    appState.removeItem(item.id)
                                }
                                Button("Edit") { editingItem = item }
                                    .tint(Palette.pink.color)
                            }
                        }
                    } header: {
                        Text("Extra items")
                    } footer: {
                        Text("anything that isn't a recipe of its own — a wine pairing, a side you're grabbing pre-made, a garnish")
                    }
                }
            }
            .navigationTitle(isCreate ? "New meal" : "Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreate ? "Add" : "Save") {
                        switch mode {
                        case .create: appState.createMeal(from: draft)
                        case .edit(let id): appState.updateMeal(id, from: draft)
                        }
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { draft = initial }
            .sheet(item: $editingItem) { item in
                EditItemSheet(item: item)
            }
        }
    }
}
