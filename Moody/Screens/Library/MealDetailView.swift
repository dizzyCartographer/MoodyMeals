import SwiftUI

// MEAL DETAIL (B-1) — the "tap a meal" destination. Truthful, engine-backed:
// per-member badges derive live (D-35), composition is read-only until the
// recipe editor lands (B-2). Retire never deletes (D-39 spirit; D-37 rails
// keep planned entries flagged, never vanished).

struct MealDetailView: View {
    @EnvironmentObject var appState: AppState
    let id: UUID

    @State private var showEdit = false
    @State private var confirmRetire = false

    private var meal: LibraryMeal? { appState.library.first { $0.id == id } }

    var body: some View {
        ScrollView {
            if let meal {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(meal.name)
                            .font(.baloo(28, .heavy))
                            .foregroundStyle(Theme.ink)
                        if meal.isAllTimer {
                            Text("★ all-timer")
                                .font(.nunito(11, .black))
                                .foregroundStyle(Palette.yellow.label)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Palette.yellow.tint, in: Capsule())
                        }
                    }

                    // Meta chips: slots · effort · conditions · tags
                    ShoppingFlowLayout(spacing: 6) {
                        ForEach(meal.slots, id: \.self) { MetaChip(text: $0) }
                        MetaChip(text: meal.effortLabel)
                        if meal.requiresCalmDay { MetaChip(text: "calm days only") }
                        if meal.isEatingOut { MetaChip(text: "eating out") }
                        if meal.isRetired { MetaChip(text: "retired") }
                        ForEach(meal.tags, id: \.self) { MetaChip(text: "#\($0)") }
                    }

                    if !meal.badges.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            SectionLabel(text: "FOR THIS HOUSE")
                            ShoppingFlowLayout(spacing: 6) {
                                ForEach(meal.badges) { badge in
                                    SafetyBadge(text: badge.text, slot: badge.slot)
                                }
                            }
                        }
                        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .inkCard(background: Theme.paper, radius: 16)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        SectionLabel(text: "WHAT'S IN IT")
                        if meal.compositionLines.isEmpty {
                            Text("no recipes on file — the recipe editor is the next build")
                                .font(.nunito(12, .heavy))
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            ForEach(meal.compositionLines, id: \.self) { line in
                                Text(line)
                                    .font(.nunito(12.5, .bold))
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                    }
                    .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .inkCard(background: Theme.paper, radius: 16)

                    if !meal.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            SectionLabel(text: "NOTES")
                            Text(meal.notes)
                                .font(.nunito(12.5, .bold))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .inkCard(background: Theme.paper, radius: 16)
                    }

                    Button("EDIT MEAL") { showEdit = true }
                        .buttonStyle(PillButtonStyle(emphasis: true))
                        .frame(height: 48)

                    Button(meal.isRetired ? "bring back into rotation" : "retire this meal") {
                        if meal.isRetired {
                            appState.setMealRetired(id, false)
                        } else {
                            confirmRetire = true
                        }
                    }
                    .font(.nunito(12, .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .padding(EdgeInsets(top: 11, leading: 20, bottom: 20, trailing: 20))
            } else {
                Text("this meal isn't on file anymore")
                    .font(.nunito(12.5, .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 60)
            }
        }
        .background(Theme.shelf.ignoresSafeArea())
        .sheet(isPresented: $showEdit) {
            if let draft = appState.draft(for: id) {
                MealFormView(mode: .edit(id), initial: draft)
            }
        }
        .confirmationDialog("Retire this meal?", isPresented: $confirmRetire,
                            titleVisibility: .visible) {
            Button("retire — hides from pickers, keeps history") {
                appState.setMealRetired(id, true)
            }
            Button("cancel", role: .cancel) {}
        }
    }
}

private struct MetaChip: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.nunito(10.5, .black))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Theme.paper, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: 1))
    }
}
