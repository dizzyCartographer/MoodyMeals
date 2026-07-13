import SwiftUI

// SHOPPING RUN DETAIL (D-56 native) — the in-store checklist. Check-off
// persists, your own items ride along, and finishing the run records real
// purchases: the guarantee recomputes and bought lines leave the lists.

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
        if let run {
            List {
                Section {
                    ForEach(run.items) { item in
                        Button {
                            appState.toggleChecked(runID, item.name)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: appState.isChecked(runID, item.name)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(appState.isChecked(runID, item.name)
                                        ? Palette.green.color : Color.secondary)
                                    .font(.title3)
                                Text(item.name)
                                    .foregroundStyle(.primary)
                                    .strikethrough(appState.isChecked(runID, item.name),
                                                   color: .secondary)
                                Spacer()
                                Text(item.category)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if appState.isManual(runID, item.name) {
                                Button("Remove", role: .destructive) {
                                    appState.removeManualItem(named: item.name, runID: runID)
                                }
                            }
                        }
                    }
                } header: {
                    Text(run.protects)
                } footer: {
                    Text("unchecked lines stay on the list for a later run")
                }

                Section {
                    HStack {
                        TextField("add an item", text: $newItemName)
                            .autocorrectionDisabled()
                        Button("Add") {
                            appState.addManualItem(newItemName, toRun: runID)
                            newItemName = ""
                        }
                        .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    Button {
                        appState.completeRun(runID)
                        dismiss()
                    } label: {
                        Text("\(checkedCount) of \(run.items.count) came home")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(checkedCount == 0)
                }
            }
            .navigationTitle(shoppingRunDisplayTitle(run.title))
            .navigationBarTitleDisplayMode(.inline)
        } else {
            VStack(spacing: 8) {
                Text("this run is settled")
                    .font(.headline)
                Text(appState.guaranteeLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
