import SwiftUI

// SETTINGS (B-5/B-6) — the household, the always-stocked shelf, and the
// calendar switch, in one place. Plain-but-kit register; safety edits carry
// deliberate weight (removing a guarantee asks once, in plain words — D-55:
// a statement of consequence, never a scare).

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var editingMember: SettingsMember?
    @State private var newStapleName = ""
    @State private var newStapleAmount = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                Text("Settings")
                    .font(.baloo(30, .heavy))
                    .foregroundStyle(Theme.ink)

                // MARK: Household
                VStack(alignment: .leading, spacing: 7) {
                    SectionLabel(text: "HOUSEHOLD")
                    ForEach(appState.settingsMembers) { member in
                        Button { editingMember = member } label: {
                            HStack(spacing: 8) {
                                Text(member.name)
                                    .font(.nunito(13.5, .heavy))
                                    .foregroundStyle(Theme.ink)
                                Spacer(minLength: 6)
                                if member.isGFHard {
                                    Text("GF — guaranteed")
                                        .font(.nunito(10, .black))
                                        .foregroundStyle(Palette.green.label)
                                        .padding(.horizontal, 7).padding(.vertical, 2)
                                        .background(Palette.green.tint, in: Capsule())
                                }
                                if member.appetiteBase != 1 {
                                    Text("×\(member.appetiteBase.formatted())")
                                        .font(.nunito(10, .black))
                                        .foregroundStyle(Palette.yellow.label)
                                        .padding(.horizontal, 7).padding(.vertical, 2)
                                        .background(Palette.yellow.tint, in: Capsule())
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(Theme.textDisabled)
                            }
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if member.id != appState.settingsMembers.last?.id {
                            Divider().overlay(Theme.shelf)
                        }
                    }
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 8, trailing: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .inkCard(background: Theme.paper, radius: 16)

                // MARK: Always stocked (D-6 — the lifeline shelf)
                VStack(alignment: .leading, spacing: 7) {
                    SectionLabel(text: "ALWAYS STOCKED")
                    Text("these ride every run until they're home — the fallback meal cooks from this shelf")
                        .font(.nunito(11, .heavy))
                        .foregroundStyle(Theme.textSecondary)
                    ForEach(appState.settingsStaples) { staple in
                        HStack(spacing: 8) {
                            Text(staple.name)
                                .font(.nunito(13, .heavy))
                                .foregroundStyle(Theme.ink)
                            Text(staple.minOnHand)
                                .font(.nunito(11, .bold))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer(minLength: 6)
                            Button {
                                appState.removeStaple(staple.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 40, height: 40)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(staple.name)")
                        }
                        .frame(minHeight: 44)
                    }
                    HStack(spacing: 6) {
                        TextField("staple", text: $newStapleName)
                            .autocorrectionDisabled()
                        TextField("how many", text: $newStapleAmount)
                            .frame(width: 92)
                        Button("ADD") {
                            appState.addStaple(newStapleName, minOnHand: newStapleAmount)
                            newStapleName = ""; newStapleAmount = ""
                        }
                        .buttonStyle(PillButtonStyle(background: Palette.green.color))
                        .disabled(newStapleName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(newStapleName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                    }
                    .font(.nunito(13, .bold))
                    .textFieldStyle(.roundedBorder)
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .inkCard(background: Theme.paper, radius: 16)

                // MARK: Calendar (B-6)
                VStack(alignment: .leading, spacing: 7) {
                    SectionLabel(text: "CALENDAR")
                    Toggle(isOn: Binding(
                        get: { appState.calendarSyncEnabled },
                        set: { appState.setCalendarSync($0) })) {
                        Text("dinners on your calendar")
                            .font(.nunito(12.5, .heavy))
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.ink)
                    .frame(minHeight: 44)
                    Text(appState.calendarSyncStatus)
                        .font(.nunito(11, .heavy))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .inkCard(background: Theme.paper, radius: 16)

                // MARK: About
                Text("Moody \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
                    .font(.nunito(11, .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(EdgeInsets(top: 11, leading: 20, bottom: 20, trailing: 20))
        }
        .background(Theme.shelf.ignoresSafeArea())
        .sheet(item: $editingMember) { member in
            MemberEditorSheet(member: member)
        }
    }
}

// MARK: - Member editor (safety edits carry deliberate weight)

private struct MemberEditorSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let member: SettingsMember
    @State private var name = ""
    @State private var appetite = 1.0
    @State private var gfHard = false
    @State private var confirmGFRemoval = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Edit \(member.name)")
                    .font(.baloo(26, .heavy))
                    .foregroundStyle(Theme.ink)

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "NAME")
                    TextField("name", text: $name)
                        .font(.nunito(13, .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 13).padding(.vertical, 12)
                        .background(Theme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
                }

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "SERVINGS  ×\(appetite.formatted())")
                    Slider(value: $appetite, in: 1.0...2.0, step: 0.25)
                        .tint(Theme.ink)
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .background(Theme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))

                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: Binding(
                        get: { gfHard },
                        set: { newValue in
                            // Removing a medical guarantee asks once, plainly.
                            if !newValue && member.isGFHard {
                                confirmGFRemoval = true
                            } else {
                                gfHard = newValue
                            }
                        })) {
                        Text("gluten-free — guaranteed")
                            .font(.nunito(12.5, .heavy))
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.ink)
                    Text("a hard rule: meals that aren't verified safe never auto-fill for nights \(member.name) is home")
                        .font(.nunito(11, .heavy))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .background(Theme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))

                Button("SAVE") {
                    appState.updateMember(member.id, name: name,
                                          appetiteBase: appetite, isGFHard: gfHard)
                    dismiss()
                }
                .buttonStyle(PillButtonStyle(background: Palette.yellow.color, emphasis: true))
                .frame(height: 48)

                Button("cancel") { dismiss() }
                    .font(.nunito(12, .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .padding(20)
        }
        .background(Theme.shelf.ignoresSafeArea())
        .onAppear {
            name = member.name
            appetite = member.appetiteBase
            gfHard = member.isGFHard
        }
        .confirmationDialog(
            "Remove the gluten guarantee for \(member.name)?",
            isPresented: $confirmGFRemoval, titleVisibility: .visible) {
            Button("remove — meals stop filtering for \(member.name)",
                   role: .destructive) { gfHard = false }
            Button("keep the guarantee", role: .cancel) {}
        }
    }
}
