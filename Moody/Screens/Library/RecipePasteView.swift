import SwiftUI
import PhotosUI

// RECIPE PASTE (M3-2 parse-only slice) — paste a recipe from a website or
// her own notes, or add one or more photos/screenshots of it (on-device
// Vision OCR reads the text first); MoodyBrain turns whichever text she
// ends up with into a title, ingredient lines, and steps. Nothing saves
// until she reviews the preview and taps Add — the GF band starts
// notCheckedYet either way, same as typing it in by hand. Ingredient lines
// that match a known gluten carrier (flour, soy sauce, breadcrumbs, …)
// carry a calm substitute suggestion in the preview — never applied on
// its own.
//
// Adding creates a RECIPE, matching every other recipe-creation door in
// the app (a meal is a collection of recipes, per Ria 2026-07-13) — it
// does NOT silently also create a meal. The very next screen offers that
// as an explicit choice: "Create a schedulable meal from it."

struct RecipePasteView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var sourceText = ""
    @State private var isParsing = false
    @State private var isReadingPhotos = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var preview: RecipePastePreview?
    @State private var addedRecipe: (id: UUID, title: String)?
    @State private var errorMessage: String?

    private var canParse: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isParsing && !isReadingPhotos
    }

    var body: some View {
        NavigationStack {
            Form {
                if let addedRecipe {
                    addedSection(addedRecipe)
                } else if let preview {
                    previewSection(preview)
                } else {
                    Section {
                        TextEditor(text: $text)
                            .frame(minHeight: 200)
                        PhotosPicker(selection: $selectedPhotos, matching: .images) {
                            Label("Add from photos", systemImage: "camera.viewfinder")
                        }
                        .onChange(of: selectedPhotos) { _, newValue in
                            guard !newValue.isEmpty else { return }
                            Task { await readPhotos(newValue) }
                        }
                    } footer: {
                        Text("paste a recipe, or add photos of one — a title, ingredient lines, and steps if it has them")
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Palette.yellow.label)
                    }
                }
            }
            .navigationTitle("Paste a recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(addedRecipe == nil ? "Cancel" : "Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if addedRecipe != nil {
                        EmptyView()
                    } else if preview != nil {
                        Button("Add") { addRecipe() }
                    } else {
                        Button("Parse") { Task { await parse() } }
                            .disabled(!canParse)
                    }
                }
            }
            .overlay {
                if isParsing || isReadingPhotos {
                    ProgressView(isReadingPhotos ? "reading the photos…" : "reading it…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func previewSection(_ preview: RecipePastePreview) -> some View {
        Section {
            Text(preview.title)
                .font(.headline)
            if preview.items.isEmpty {
                Text("no ingredient lines found — you can add them after")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(preview.items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.name)
                        Spacer()
                        if let amount = item.amount {
                            Text([Self.formatted(amount), item.unit].compactMap { $0 }.joined(separator: " "))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let suggestion = item.substituteSuggestion {
                        Text("may need a GF substitute — \(suggestion)")
                            .font(.caption)
                            .foregroundStyle(Palette.yellow.label)
                    }
                }
            }
            if !preview.steps.isEmpty {
                ForEach(Array(preview.steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)")
                        .font(.callout)
                }
            }
            TextField("Source — a URL or cookbook title (optional)", text: $sourceText)
                .autocorrectionDisabled()
        } header: {
            Text("Looks like this — edit anything after adding")
        }
    }

    private func addedSection(_ added: (id: UUID, title: String)) -> some View {
        Section {
            Label("\(added.title) added to your recipes", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Palette.green.label)
            Button {
                appState.createMeal(wrappingRecipe: added.id)
                dismiss()
            } label: {
                Label("Create a schedulable meal from it", systemImage: "calendar.badge.plus")
            }
        } footer: {
            Text("a recipe on its own can't go on the plan — this wraps it in a meal that can")
        }
    }

    private func readPhotos(_ items: [PhotosPickerItem]) async {
        isReadingPhotos = true
        errorMessage = nil
        defer { isReadingPhotos = false; selectedPhotos = [] }
        var datas: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                datas.append(data)
            }
        }
        switch await appState.recognizeRecipeText(fromImageData: datas) {
        case .success(let recognized):
            text = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? recognized : text + "\n\n" + recognized
        case .failure:
            errorMessage = "couldn't find any text in those photos — try again, or type the recipe instead"
        }
    }

    private func parse() async {
        isParsing = true
        errorMessage = nil
        defer { isParsing = false }
        switch await appState.parsePastedRecipe(text) {
        case .success(let result):
            preview = result
        case .failure(.notConfigured):
            errorMessage = "no Claude API key on file — add one in Settings, or add this recipe by typing instead"
        case .failure(.failed):
            errorMessage = "couldn't read that — try again, or add it by typing instead"
        }
    }

    private func addRecipe() {
        guard var preview else { return }
        preview.source = sourceText
        guard let id = appState.createStandaloneRecipe(fromPastedRecipe: preview) else { return }
        addedRecipe = (id: id, title: preview.title)
    }

    private static func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }
}
