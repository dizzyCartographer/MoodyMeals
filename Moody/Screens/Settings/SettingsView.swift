import SwiftUI

// SETTINGS (D-56 native) — household, always-stocked shelf, calendar switch.
// Safety edits carry deliberate weight: removing a guarantee asks once, in
// plain words (D-55 register — a statement of consequence, never a scare).

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var editingMember: SettingsMember?

    var body: some View {
        Form {
            Section("Household") {
                ForEach(appState.settingsMembers) { member in
                    Button { editingMember = member } label: {
                        HStack {
                            Text(member.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if member.isGFHard {
                                Text("GF — guaranteed")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Palette.green.label)
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Palette.green.tint, in: Capsule())
                            }
                            if member.appetiteBase != 1 {
                                Text("×\(member.appetiteBase.formatted())")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            // Always-stocked moved to its own screen under Shopping
            // (Ria 2026-07-13: "staples should be its own screen").

            Section {
                Toggle("Dinners on your calendar", isOn: Binding(
                    get: { appState.calendarSyncEnabled },
                    set: { appState.setCalendarSync($0) }))
            } header: {
                Text("Calendar")
            } footer: {
                Text(appState.calendarSyncStatus)
            }

            Section {
                LabeledContent("Version",
                    value: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
            }
        }
        .navigationTitle("Settings")
        .sheet(item: $editingMember) { member in
            MemberEditorSheet(member: member)
        }
    }
}

// MARK: - Member editor

private struct MemberEditorSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let member: SettingsMember
    @State private var name = ""
    @State private var appetite = 1.0
    @State private var gfHard = false
    @State private var confirmGFRemoval = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }

                Section {
                    LabeledContent("Servings", value: "×\(appetite.formatted())")
                    Slider(value: $appetite, in: 1.0...2.0, step: 0.25)
                }

                Section {
                    Toggle("Gluten-free — guaranteed", isOn: Binding(
                        get: { gfHard },
                        set: { newValue in
                            if !newValue && member.isGFHard {
                                confirmGFRemoval = true   // removal asks once, plainly
                            } else {
                                gfHard = newValue
                            }
                        }))
                } footer: {
                    Text("a hard rule: meals that aren't verified safe never auto-fill for nights \(member.name) is home")
                }
            }
            .navigationTitle("Edit \(member.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.updateMember(member.id, name: name,
                                              appetiteBase: appetite, isGFHard: gfHard)
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = member.name
                appetite = member.appetiteBase
                gfHard = member.isGFHard
            }
            .confirmationDialog(
                "Remove the gluten guarantee for \(member.name)?",
                isPresented: $confirmGFRemoval, titleVisibility: .visible) {
                Button("Remove — meals stop filtering for \(member.name)",
                       role: .destructive) { gfHard = false }
                Button("Keep the guarantee", role: .cancel) {}
            }
        }
    }
}
