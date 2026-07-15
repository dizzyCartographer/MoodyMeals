import SwiftUI

// RECIPE DETAIL — the read screen: ingredients, steps, band, all read-only.
// The doorway to the two things you can't do from the edit form: share it
// out (native share sheet) and start cooking (full-screen step mode).

struct RecipeDetailView: View {
    @EnvironmentObject var appState: AppState
    let recipeID: UUID

    @State private var showCookMode = false
    @State private var showEdit = false

    private var recipe: LibraryRecipe? { appState.libraryRecipe(recipeID) }

    var body: some View {
        Group {
            if let recipe {
                List {
                    Section {
                        HStack {
                            Text(BandStyle.label(recipe.bandRaw))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle((BandStyle.isGreen(recipe.bandRaw)
                                    ? Palette.green : Palette.yellow).label)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background((BandStyle.isGreen(recipe.bandRaw)
                                    ? Palette.green : Palette.yellow).tint, in: Capsule())
                            Spacer()
                            Text(recipe.kindLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Ingredients") {
                        if recipe.items.isEmpty {
                            Text("no ingredient lines yet")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                        ForEach(recipe.items) { item in
                            IngredientLine(item: item)
                        }
                    }

                    if !recipe.steps.isEmpty {
                        Section("Steps") {
                            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(Palette.pink.label)
                                        .frame(width: 20, alignment: .trailing)
                                    Text(step)
                                }
                            }
                        }
                    }

                    if !recipe.standardModification.isEmpty {
                        Section("Substitution on file") {
                            Text(recipe.standardModification)
                        }
                    }
                }
                .navigationTitle(recipe.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: Self.shareText(for: recipe))
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Edit") { showEdit = true }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        showCookMode = true
                    } label: {
                        Label("Start cooking", systemImage: "flame.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.pink.color)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                }
                .fullScreenCover(isPresented: $showCookMode) {
                    CookModeView(recipe: recipe)
                }
                .sheet(isPresented: $showEdit) {
                    RecipeFormView(mealID: nil, recipeID: recipe.id)
                }
            } else {
                ContentUnavailableView("this recipe isn't on file anymore",
                                       systemImage: "questionmark.folder")
            }
        }
    }

    /// Plain-text form for the share sheet — mirrors the markdown export's
    /// shape (SL-6 spirit: readable, one item per line) without depending
    /// on it.
    static func shareText(for recipe: LibraryRecipe) -> String {
        var lines = [recipe.title, ""]
        if !recipe.items.isEmpty {
            lines.append("Ingredients:")
            lines += recipe.items.map {
                $0.amountText.isEmpty ? "- \($0.name)" : "- \($0.name) — \($0.amountText)"
            }
            lines.append("")
        }
        if !recipe.steps.isEmpty {
            lines.append("Steps:")
            lines += recipe.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }
        }
        return lines.joined(separator: "\n")
    }
}
