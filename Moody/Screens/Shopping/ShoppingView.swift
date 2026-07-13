import SwiftUI

// SHOPPING (D-56 native) — the guarantee verdict, tiered runs as plain
// navigation, add-your-own items, and the always-stocked shelf.

struct ShoppingView: View {
    @EnvironmentObject var appState: AppState

    @State private var newItemName = ""

    var body: some View {
        List {
            Section {
                Label(appState.guaranteeLine,
                      systemImage: appState.runs.compactMap(\.atRisk).first == nil
                        ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(appState.runs.compactMap(\.atRisk).first == nil
                        ? Palette.green.label : Palette.yellow.label)
                    .font(.callout.weight(.medium))
            }

            if appState.runs.isEmpty {
                Section {
                    Text("no runs on the board — planned dinners create them")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            } else {
                Section("Runs") {
                    ForEach(appState.runs) { run in
                        NavigationLink(value: run.id) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(shoppingRunDisplayTitle(run.title))
                                        .font(.body.weight(.medium))
                                    Spacer()
                                    Text("\(run.items.count)")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Text(run.protects)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if let atRisk = run.atRisk {
                                    Text(atRisk)
                                        .font(.caption)
                                        .foregroundStyle(Palette.yellow.label)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                HStack {
                    TextField("add an item", text: $newItemName)
                        .autocorrectionDisabled()
                    Button("Add") {
                        appState.addManualItem(newItemName,
                                               toRun: appState.runs.first?.id ?? "topup")
                        newItemName = ""
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("lands on the soonest run — movable from inside any run")
            }

            Section("Always stocked") {
                ForEach(appState.settingsStaples) { staple in
                    HStack {
                        Text(staple.name)
                        Spacer()
                        Text(staple.minOnHand)
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
            }
        }
        .navigationTitle("Shopping")
    }
}

func shoppingRunDisplayTitle(_ title: String) -> String {
    title
}
