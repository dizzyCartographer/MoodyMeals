import SwiftUI

// SHOPPING RUN DETAIL (B-4) — the in-store checklist. Check-off persists,
// your own items ride along, and finishing the run records real purchases:
// the guarantee recomputes and bought lines leave the remaining lists.
// D-55 register throughout: statements and options, no commands.

struct ShoppingRunDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let runID: String

    @State private var newItemName = ""

    private var run: ShoppingRun? { appState.runs.first { $0.id == runID } }
    private var checkedCount: Int {
        run?.items.filter { appState.isChecked(runID, $0.name) }.count ?? 0
    }

    var body: some View {
        ScrollView {
            if let run {
                VStack(alignment: .leading, spacing: 11) {
                    Text(shoppingRunDisplayTitle(run.title))
                        .font(.baloo(30, .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(run.protects)
                        .font(.nunito(12, .heavy))
                        .foregroundStyle(Theme.textSecondary)

                    VStack(spacing: 0) {
                        ForEach(run.items) { item in
                            ChecklistRow(
                                name: item.name,
                                category: item.category,
                                checked: appState.isChecked(runID, item.name),
                                isManual: appState.isManual(runID, item.name),
                                onToggle: { appState.toggleChecked(runID, item.name) },
                                onRemove: { appState.removeManualItem(named: item.name,
                                                                      runID: runID) })
                            if item.id != run.items.last?.id {
                                Divider().overlay(Theme.shelf)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .inkCard(background: Theme.paper, radius: 16)

                    // Add your own line — it rides this run.
                    HStack(spacing: 6) {
                        TextField("add an item", text: $newItemName)
                            .font(.nunito(13, .bold))
                            .foregroundStyle(Theme.ink)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 13)
                            .frame(height: 48)
                            .background(Theme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
                        Button("ADD") {
                            appState.addManualItem(newItemName, toRun: runID)
                            newItemName = ""
                        }
                        .buttonStyle(PillButtonStyle(background: Palette.green.color))
                        .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(newItemName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                    }

                    Button("\(checkedCount) OF \(run.items.count) CAME HOME") {
                        appState.completeRun(runID)
                        dismiss()
                    }
                    .buttonStyle(PillButtonStyle(background: Palette.yellow.color, emphasis: true))
                    .frame(height: 48)
                    .disabled(checkedCount == 0)
                    .opacity(checkedCount == 0 ? 0.45 : 1)

                    Text("unchecked lines stay on the list for a later run")
                        .font(.nunito(11, .heavy))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(EdgeInsets(top: 11, leading: 20, bottom: 20, trailing: 20))
            } else {
                // The run finished (or projected away) — coverage moved on.
                VStack(spacing: 8) {
                    Text("this run is settled")
                        .font(.baloo(22, .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(appState.guaranteeLine)
                        .font(.nunito(12, .heavy))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            }
        }
        .background(Theme.shelf.ignoresSafeArea())
    }
}

private struct ChecklistRow: View {
    var name: String
    var category: String
    var checked: Bool
    var isManual: Bool
    var onToggle: () -> Void
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(checked ? Palette.green.color : Theme.textDisabled)
                    Text(name)
                        .font(.nunito(13.5, .heavy))
                        .foregroundStyle(Theme.ink)
                        .strikethrough(checked, color: Theme.textSecondary)
                        .opacity(checked ? 0.6 : 1)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 6)
                    Text(category)
                        .font(.nunito(10, .black))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name), \(checked ? "checked" : "unchecked")")
            if isManual {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(name)")
            }
        }
        .padding(.horizontal, 13)
    }
}
