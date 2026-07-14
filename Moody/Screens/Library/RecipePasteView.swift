import SwiftUI

// RECIPE PASTE (M3-2 parse-only slice) — paste a recipe from a website or
// her own notes; MoodyBrain turns it into a title, ingredient lines, and
// steps. Nothing saves until she reviews the preview and taps Add — the
// GF band starts notCheckedYet either way, same as typing it in by hand.

struct RecipePasteView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var isParsing = false
    @State private var preview: RecipePastePreview?
    @State private var errorMessage: String?

    private var canParse: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isParsing
    }

    var body: some View {
        NavigationStack {
            Form {
                if let preview {
                    previewSection(preview)
                } else {
                    Section {
                        TextEditor(text: $text)
                            .frame(minHeight: 220)
                    } footer: {
                        Text("paste a recipe — a title, ingredient lines, and steps if it has them")
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if preview != nil {
                        Button("Add") { addAndDismiss() }
                    } else {
                        Button("Parse") { Task { await parse() } }
                            .disabled(!canParse)
                    }
                }
            }
            .overlay {
                if isParsing {
                    ProgressView("reading it…")
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
                HStack {
                    Text(item.name)
                    Spacer()
                    if let amount = item.amount {
                        Text([Self.formatted(amount), item.unit].compactMap { $0 }.joined(separator: " "))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !preview.steps.isEmpty {
                ForEach(Array(preview.steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)")
                        .font(.callout)
                }
            }
        } header: {
            Text("Looks like this — edit anything after adding")
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
            errorMessage = "recipe paste isn't set up yet — add this one by typing instead"
        case .failure(.failed):
            errorMessage = "couldn't read that — try again, or add it by typing instead"
        }
    }

    private func addAndDismiss() {
        guard let preview else { return }
        appState.createMeal(fromPastedRecipe: preview)
        dismiss()
    }

    private static func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }
}
