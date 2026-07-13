import SwiftUI

// PLAN (D-56) — the in-app calendar that was missing: 28 days from today,
// any day assignable, dinner + optional lunch per day. Pins hold what you
// placed (D-55 vocabulary). HC-5's warn-confirm finally has its surface:
// picking a non-verified meal while a GF-guaranteed member is home states
// it plainly and asks once — override allowed, silent never.

struct PlanView: View {
    @EnvironmentObject var appState: AppState

    private struct PickerTarget: Identifiable {
        let date: Date
        let slotRaw: String
        var id: String { "\(date.timeIntervalSince1970)-\(slotRaw)" }
    }
    @State private var pickerTarget: PickerTarget?

    var body: some View {
        List {
            ForEach(appState.planDays) { day in
                Section {
                    slotRow(day: day, slotRaw: "dinner", info: day.dinner,
                            label: "Dinner")
                    if let lunch = day.lunch {
                        slotRow(day: day, slotRaw: "lunch", info: lunch,
                                label: "Lunch")
                    } else {
                        Button {
                            pickerTarget = PickerTarget(date: day.id, slotRaw: "lunch")
                        } label: {
                            Label("Add lunch", systemImage: "plus")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text(day.weekdayLabel)
                        Text(day.monthLabel.map { "\($0) \(day.dayLabel)" } ?? day.dayLabel)
                        if day.isToday {
                            Text("today")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Palette.pink.color)
                        }
                    }
                }
            }
        }
        .navigationTitle("Plan")
        .sheet(item: $pickerTarget) { target in
            MealPickerSheet(date: target.date, slotRaw: target.slotRaw)
        }
    }

    @ViewBuilder
    private func slotRow(day: PlanDay, slotRaw: String,
                         info: PlanSlotInfo?, label: String) -> some View {
        if let info {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(info.needsRefill ? .secondary : .primary)
                    Text(label.lowercased())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if let badge = info.gfBadge {
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle((info.gfSafe ? Palette.green : Palette.yellow).label)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background((info.gfSafe ? Palette.green : Palette.yellow).tint,
                                    in: Capsule())
                }
                if info.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Pinned")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                pickerTarget = PickerTarget(date: day.id, slotRaw: slotRaw)
            }
            .swipeActions(edge: .trailing) {
                Button("Clear", role: .destructive) {
                    appState.clearPlan(on: day.id, slotRaw: slotRaw)
                }
                Button(info.pinned ? "Unpin" : "Pin") {
                    appState.togglePin(on: day.id, slotRaw: slotRaw)
                }
                .tint(Palette.blue.color)
            }
        } else {
            Button {
                pickerTarget = PickerTarget(date: day.id, slotRaw: slotRaw)
            } label: {
                Label("Choose \(label.lowercased())", systemImage: "plus.circle")
                    .font(.callout)
                    .foregroundStyle(Palette.pink.color)
            }
        }
    }
}

// MARK: - Meal picker (HC-5's surface lives here)

struct MealPickerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let slotRaw: String

    @State private var search = ""
    @State private var pendingGFConfirm: (meal: LibraryMeal, names: [String])?
    @State private var showGFConfirm = false

    private var meals: [LibraryMeal] {
        let pool = appState.library.filter { !$0.isRetired && !$0.isEatingOut }
        guard !search.isEmpty else { return pool }
        return pool.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(meals) { meal in
                Button {
                    pick(meal)
                } label: {
                    HStack {
                        Text(meal.name).foregroundStyle(.primary)
                        Spacer()
                        Text(meal.gfLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle((meal.gfSafe ? Palette.green : Palette.yellow).label)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background((meal.gfSafe ? Palette.green : Palette.yellow).tint,
                                        in: Capsule())
                    }
                }
            }
            .searchable(text: $search, prompt: "search meals")
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                gfConfirmTitle,
                isPresented: $showGFConfirm, titleVisibility: .visible) {
                Button("assign it anyway") {
                    if let pending = pendingGFConfirm {
                        appState.assignMeal(pending.meal.id, on: date, slotRaw: slotRaw)
                    }
                    dismiss()
                }
                Button("pick something else", role: .cancel) {
                    pendingGFConfirm = nil
                }
            }
        }
    }

    private var gfConfirmTitle: String {
        guard let pending = pendingGFConfirm else { return "" }
        let names = pending.names.joined(separator: " and ")
        return "\(pending.meal.name) isn't verified gluten-free, and \(names) will be home."
    }

    private func pick(_ meal: LibraryMeal) {
        if let names = appState.gfConfirmationNames(forMeal: meal.id) {
            pendingGFConfirm = (meal, names)
            showGFConfirm = true   // HC-5: named, plain, once — never silent
        } else {
            appState.assignMeal(meal.id, on: date, slotRaw: slotRaw)
            dismiss()
        }
    }
}
