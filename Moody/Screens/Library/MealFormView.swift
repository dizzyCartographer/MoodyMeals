import SwiftUI

// MEAL FORM (B-1) — create/edit, kit-plain. Engine vocabulary shown truthfully
// (four effort levels, three slots); MealDraft keeps engine enums out of views.

struct MealFormView: View {
    enum Mode { case create, edit(UUID) }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    @State var initial = MealDraft()
    @State private var draft = MealDraft()

    private static let efforts: [(raw: Int, label: String)] =
        [(0, "no cook"), (1, "assembly"), (2, "simple"), (3, "involved")]
    private static let slotOptions = ["dinner", "breakfast", "lunch"]

    private var isCreate: Bool { if case .create = mode { true } else { false } }
    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(isCreate ? "New meal" : "Edit meal")
                    .font(.baloo(26, .heavy))
                    .foregroundStyle(Theme.ink)

                field("NAME") {
                    TextField("what's it called at your table?", text: $draft.title)
                        .font(.nunito(13, .bold))
                }
                field("NOTES") {
                    TextField("anything worth remembering", text: $draft.notes,
                              axis: .vertical)
                        .font(.nunito(13, .bold))
                        .lineLimit(2...4)
                }

                SectionLabel(text: "EFFORT")
                HStack(spacing: 6) {
                    ForEach(Self.efforts, id: \.raw) { option in
                        SelectChip(text: option.label,
                                   selected: draft.effortRaw == option.raw) {
                            draft.effortRaw = option.raw
                        }
                    }
                }

                SectionLabel(text: "SLOTS")
                HStack(spacing: 6) {
                    ForEach(Self.slotOptions, id: \.self) { slot in
                        SelectChip(text: slot, selected: draft.slots.contains(slot)) {
                            if draft.slots.contains(slot) {
                                draft.slots.remove(slot)
                            } else {
                                draft.slots.insert(slot)
                            }
                        }
                    }
                }

                field("TAGS") {
                    TextField("comma-separated: mexican, quick, …", text: $draft.tagsText)
                        .font(.nunito(13, .bold))
                        .autocorrectionDisabled()
                }

                toggleRow("all-time favorite", $draft.isAllTimer)
                toggleRow("eating out (never auto-scheduled)", $draft.isEatingOut)
                toggleRow("calm days only", $draft.requiresCalmDay)

                Button(isCreate ? "ADD MEAL" : "SAVE CHANGES") {
                    switch mode {
                    case .create: appState.createMeal(from: draft)
                    case .edit(let id): appState.updateMeal(id, from: draft)
                    }
                    dismiss()
                }
                .buttonStyle(PillButtonStyle(background: Palette.yellow.color, emphasis: true))
                .frame(height: 48)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)

                Button("cancel") { dismiss() }
                    .font(.nunito(12, .heavy))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .padding(20)
        }
        .background(Theme.shelf.ignoresSafeArea())
        .onAppear { draft = initial }
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: label)
            content()
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(Theme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
        }
    }

    private func toggleRow(_ label: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(label)
                .font(.nunito(12.5, .heavy))
                .foregroundStyle(Theme.ink)
        }
        .tint(Theme.ink)
        .padding(.horizontal, 13)
        .frame(minHeight: 48)
        .background(Theme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
    }
}

private struct SelectChip: View {
    var text: String
    var selected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.nunito(11.5, .black))
                .foregroundStyle(selected ? Theme.paper : Theme.ink)
                .padding(.horizontal, 11)
                .frame(minHeight: 40)
                .background(selected ? Theme.ink : Theme.paper, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: Theme.borderWidth))
        }
        .buttonStyle(.plain)
    }
}
