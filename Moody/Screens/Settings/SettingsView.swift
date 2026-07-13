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
                                .foregroundStyle(Color.primary)
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

            // FR-1: the structured rules (D-45) — what the scheduler will
            // honor and the assessment will judge against. Editing arrives
            // with the rules editor; today they read truthfully.
            if !appState.memberRules.isEmpty {
                Section {
                    ForEach(appState.memberRules) { rule in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(rule.memberName)
                                    .font(.body.weight(.medium))
                                Text(rule.directionLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Palette.blue.label)
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Palette.blue.tint, in: Capsule())
                                Spacer()
                                if let window = rule.windowText {
                                    Text(window)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text("\(rule.subject) · \(rule.reason)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Food rules")
                } footer: {
                    // D-35: no names in static copy — this footer must stay
                    // true for ANY household.
                    Text("structured records the week gets built around — a Gluten · never record is the guarantee auto-fill protects, and having no records is a fine way to be")
                }
            }

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
    @State private var showAddRule = false
    @State private var pendingGlutenRemoval: MemberRule?

    private var rules: [MemberRule] {
        appState.memberRules.filter { $0.memberID == member.id }
    }

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

                // D-58: restriction/requirement records — one type for
                // everything, gluten included.
                Section {
                    if rules.isEmpty {
                        Text("no restrictions on file")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    ForEach(rules) { rule in
                        HStack {
                            Text(rule.subject)
                            Text(rule.directionLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.blue.label)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Palette.blue.tint, in: Capsule())
                            Spacer()
                            if let window = rule.windowText {
                                Text(window)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Remove", role: .destructive) {
                                if rule.isGluten {
                                    pendingGlutenRemoval = rule   // asks once, plainly
                                } else {
                                    appState.removeRule(rule.id)
                                }
                            }
                        }
                    }
                    Button {
                        showAddRule = true
                    } label: {
                        Label("Add restriction", systemImage: "plus")
                    }
                } header: {
                    Text("Restrictions & requirements")
                } footer: {
                    Text("never = filtered out · infrequent = capped · increased = the week leans toward it")
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
                                              appetiteBase: appetite)
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = member.name
                appetite = member.appetiteBase
            }
            .sheet(isPresented: $showAddRule) {
                AddRuleSheet(memberID: member.id, memberName: member.name)
            }
            .confirmationDialog(
                "Remove the gluten guarantee for \(member.name)?",
                isPresented: Binding(get: { pendingGlutenRemoval != nil },
                                     set: { if !$0 { pendingGlutenRemoval = nil } }),
                titleVisibility: .visible) {
                Button("Remove — meals stop filtering for \(member.name)",
                       role: .destructive) {
                    if let rule = pendingGlutenRemoval { appState.removeRule(rule.id) }
                    pendingGlutenRemoval = nil
                }
                Button("Keep the guarantee", role: .cancel) { pendingGlutenRemoval = nil }
            }
        }
    }
}

// MARK: - Add restriction (D-58: category picker + level picker)

private struct AddRuleSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let memberID: UUID
    let memberName: String

    @State private var categoryRaw = AppState.ruleCategories.first?.raw ?? "gluten"
    @State private var levelRaw = "never"

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $categoryRaw) {
                    ForEach(AppState.ruleCategories, id: \.raw) { category in
                        Text(category.name).tag(category.raw)
                    }
                }
                Picker("Level", selection: $levelRaw) {
                    ForEach(AppState.ruleLevels, id: \.raw) { level in
                        Text(level.name).tag(level.raw)
                    }
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("Restriction for \(memberName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        appState.addRule(memberID: memberID,
                                         categoryRaw: categoryRaw,
                                         levelRaw: levelRaw)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
