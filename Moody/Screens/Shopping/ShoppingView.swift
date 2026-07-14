import SwiftUI

// SHOPPING (flat + store-grouped per Ria 2026-07-13, SHOP-4) — ONE list
// answering "what do we need?", grouped the way a store is walked
// (produce / meat / dairy / pantry / frozen, then "anything else" for her
// own additions). The three-trip run math still drives routing and the
// guarantee INTERNALLY — it just doesn't schedule her errands on screen.
// Kept from the reminders-ish pass: check-off in place, strikethrough,
// quick-add, unchecked items surviving "done". New: freshness chips,
// a bottom "Done shopping" bar once anything's checked, and a "Have it"
// swipe that records a pantry-check so the guarantee agrees.

struct ShoppingView: View {
    @EnvironmentObject var appState: AppState

    private var allItems: [ShoppingItem] { appState.sections.flatMap(\.items) }
    private var checkedCount: Int { allItems.filter { appState.isChecked($0.name) }.count }

    var body: some View {
        List {
            Section {
                Label(appState.guaranteeLine,
                      systemImage: appState.guaranteeAtRisk
                        ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(appState.guaranteeAtRisk
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

            ForEach(appState.sections) { section in
                Section {
                    ForEach(section.items) { item in
                        CheckItemRow(item: item)
                    }
                    if section.id == "extras" {
                        QuickAddRow()
                    }
                } header: {
                    Text(section.title)
                } footer: {
                    if section.id == "extras" && section.items.isEmpty {
                        Text("planned dinners fill the list — anything added here stays until it's home")
                    }
                }
            }
        }
        .navigationTitle("Shopping")
        // Watch/family/Siri edits land without waiting for a local change.
        .onAppear { appState.refreshRemindersFromOutside() }
        .safeAreaInset(edge: .bottom) {
            if checkedCount > 0 {
                Button {
                    appState.finishShopping()
                } label: {
                    Text("Done shopping · \(checkedCount) of \(allItems.count)")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
    }
}

private struct CheckItemRow: View {
    @EnvironmentObject var appState: AppState
    var item: ShoppingItem

    private var checked: Bool { appState.isChecked(item.name) }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                appState.toggleChecked(item.name)
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
            if let deadline = item.deadline {
                Text(deadline)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.yellow.label)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.yellow.color.opacity(0.22)))
            }
            if !item.category.isEmpty {
                Text(item.category)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { appState.toggleChecked(item.name) }
        .swipeActions(edge: .trailing) {
            if appState.isManual(item.name) {
                Button("Remove", role: .destructive) {
                    appState.removeManualItem(named: item.name)
                }
            } else {
                // The pantry check: it's home already — off the list, and
                // the guarantee counts it as covered until the next shop.
                Button("Have it") {
                    appState.markHaveIt(item.name)
                }
                .tint(Palette.green.color)
            }
        }
    }
}

private struct QuickAddRow: View {
    @EnvironmentObject var appState: AppState

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
                    appState.addManualItem(text)
                    text = ""
                    focused = true   // Reminders-style: keep adding
                }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }
}
