import SwiftUI

// ALWAYS STOCKED (its own screen per Ria 2026-07-13) — the D-6 lifeline
// shelf: items that ride every run until they're home. The fallback meal
// cooks from this shelf; the guarantee watches it.

struct StaplesView: View {
    @EnvironmentObject var appState: AppState

    @State private var newName = ""
    @State private var newAmount = ""

    var body: some View {
        List {
            Section {
                if appState.settingsStaples.isEmpty {
                    Text("nothing on the shelf yet")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                ForEach(appState.settingsStaples) { staple in
                    HStack {
                        Text(staple.name)
                        Spacer()
                        Text(staple.minOnHand)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Remove", role: .destructive) {
                            appState.removeStaple(staple.id)
                        }
                    }
                }
            } footer: {
                Text("these come along on every list until they're home — the fallback meal cooks from this shelf")
            }

            Section("Add") {
                HStack {
                    TextField("staple", text: $newName)
                        .autocorrectionDisabled()
                    TextField("how many", text: $newAmount)
                        .frame(width: 90)
                    Button("Add") {
                        appState.addStaple(newName, minOnHand: newAmount)
                        newName = ""; newAmount = ""
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("Always stocked")
    }
}
