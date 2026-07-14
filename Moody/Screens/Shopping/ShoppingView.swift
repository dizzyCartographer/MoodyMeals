import SwiftUI

// SHOPPING (reminders-ish per Ria 2026-07-13) — one flat checklist: every
// run is a section, every item checks off IN PLACE with a round toggle,
// quick-add lives in each section, and "finish" sits in the section header
// once anything's checked. The engine completion (done run + purchase
// records + guarantee recompute) rides that finish, same as before.

struct ShoppingView: View {
    @EnvironmentObject var appState: AppState

    private var atRiskAnywhere: Bool {
        appState.runs.contains { $0.atRisk != nil }
    }

    var body: some View {
        List {
            Section {
                Label(appState.guaranteeLine,
                      systemImage: atRiskAnywhere
                        ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(atRiskAnywhere
                        ? Palette.yellow.label : Palette.green.label)
                    .font(.callout.weight(.medium))
                NavigationLink {
                    StaplesView()
                } label: {
                    HStack {
                        Label("Always stocked", systemImage: "tray.full")
                        Spacer()
                        Text("\(appState.settingsStaples.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: Binding(
                    get: { appState.remindersSyncEnabled },
                    set: { appState.setRemindersSync($0) })) {
                    Label("Also in Reminders", systemImage: "checklist")
                }
            } footer: {
                Text(appState.remindersSyncStatus)
            }

            if appState.runs.isEmpty {
                Section {
                    QuickAddRow(runID: "topup")
                } footer: {
                    Text("planned dinners create runs — anything you add here rides the next top-up")
                }
            }

            ForEach(appState.runs) { run in
                ShoppingRunSection(run: run)
            }
        }
        .navigationTitle("Shopping")
        // Watch/family/Siri edits land without waiting for a local change.
        .onAppear { appState.refreshRemindersFromOutside() }
    }
}

private struct ShoppingRunSection: View {
    @EnvironmentObject var appState: AppState
    var run: ShoppingRun

    private var checkedCount: Int {
        run.items.filter { appState.isChecked(run.id, $0.name) }.count
    }

    var body: some View {
        Section {
            ForEach(run.items) { item in
                CheckItemRow(runID: run.id, item: item)
            }
            QuickAddRow(runID: run.id)
        } header: {
            HStack {
                Text(shoppingRunDisplayTitle(run.title))
                Spacer()
                if checkedCount > 0 {
                    Button("Finish · \(checkedCount) of \(run.items.count)") {
                        appState.completeRun(run.id)
                    }
                    .font(.caption.weight(.semibold))
                    .textCase(nil)
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                Text(run.protects)
                if let atRisk = run.atRisk {
                    Text(atRisk).foregroundStyle(Palette.yellow.label)
                }
            }
        }
    }
}

private struct CheckItemRow: View {
    @EnvironmentObject var appState: AppState
    let runID: String
    var item: ShoppingItem

    private var checked: Bool { appState.isChecked(runID, item.name) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                appState.toggleChecked(runID, item.name)
            } label: {
                Image(systemName: checked ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(checked ? Palette.pink.color : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.name), \(checked ? "checked" : "unchecked")")
            Text(item.name)
                .strikethrough(checked, color: .secondary)
                .foregroundStyle(checked ? .secondary : .primary)
            Spacer()
            Text(item.category)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture { appState.toggleChecked(runID, item.name) }
        .swipeActions(edge: .trailing) {
            if appState.isManual(runID, item.name) {
                Button("Remove", role: .destructive) {
                    appState.removeManualItem(named: item.name, runID: runID)
                }
            }
        }
    }
}

private struct QuickAddRow: View {
    @EnvironmentObject var appState: AppState
    let runID: String

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Palette.pink.color)
            TextField("add an item", text: $text)
                .autocorrectionDisabled()
                .focused($focused)
                .onSubmit {
                    appState.addManualItem(text, toRun: runID)
                    text = ""
                    focused = true   // Reminders-style: keep adding
                }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}

func shoppingRunDisplayTitle(_ title: String) -> String {
    title
}
