import SwiftUI

// PLAN (D-56, month-first per Ria 2026-07-13) — an actual calendar: month
// grid by default (planned days visible at a glance), tap a date → that
// day's plan screen (dinner + lunch). Week view keeps the multi-day list.
// HC-5's warn-confirm lives in the shared picker: named, plain, once.

struct PlanView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case month = "Month", week = "Week"
        var id: String { rawValue }
    }

    @EnvironmentObject var appState: AppState
    @State private var mode: Mode = .month
    @State private var monthAnchor = Calendar.current.dateInterval(
        of: .month, for: .now)?.start ?? .now

    private struct DayTarget: Identifiable {
        let date: Date
        var id: Date { date }
    }
    @State private var dayTarget: DayTarget?

    private struct PickerTarget: Identifiable {
        let date: Date
        let slotRaw: String
        var id: String { "\(date.timeIntervalSince1970)-\(slotRaw)" }
    }
    @State private var pickerTarget: PickerTarget?

    var body: some View {
        Group {
            switch mode {
            case .month:
                MonthCalendarView(monthAnchor: $monthAnchor) { date in
                    dayTarget = DayTarget(date: date)
                }
            case .week:
                weekList
            }
        }
        .navigationTitle("Plan")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
        }
        .sheet(item: $dayTarget) { target in
            DayPlanSheet(date: target.date)
        }
        .sheet(item: $pickerTarget) { target in
            MealPickerSheet(date: target.date, slotRaw: target.slotRaw)
        }
    }

    // MARK: Week view — the multi-day list ("add multiple meals from the
    // same screen"), 28 rolling days.

    private var weekList: some View {
        List {
            ForEach(appState.planDays) { day in
                Section {
                    weekSlotRow(day: day, slotRaw: "dinner", info: day.dinner,
                                label: "Dinner")
                    if let lunch = day.lunch {
                        weekSlotRow(day: day, slotRaw: "lunch", info: lunch,
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
    }

    @ViewBuilder
    private func weekSlotRow(day: PlanDay, slotRaw: String,
                             info: PlanSlotInfo?, label: String) -> some View {
        if let info {
            PlanAssignedRow(info: info, slotLabel: label)
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

// MARK: - Month grid

struct MonthCalendarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var monthAnchor: Date
    var onSelect: (Date) -> Void

    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: .now) }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Leading nils pad the first row to the month's starting weekday.
    private var cells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: monthAnchor),
              let dayCount = calendar.range(of: .day, in: .month, for: monthAnchor)?.count
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days: [Date?] = (0..<dayCount).map {
            calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
        return Array(repeating: nil, count: leading) + days
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Button {
                        monthAnchor = calendar.date(byAdding: .month, value: -1,
                                                    to: monthAnchor) ?? monthAnchor
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                    Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button {
                        monthAnchor = calendar.date(byAdding: .month, value: 1,
                                                    to: monthAnchor) ?? monthAnchor
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 8)

                HStack {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4),
                                         count: 7), spacing: 6) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                        if let day {
                            MonthDayCell(
                                day: day,
                                isToday: day == today,
                                isPast: day < today,
                                cell: appState.planByDay[day]) { onSelect(day) }
                        } else {
                            Color.clear.frame(height: 54)
                        }
                    }
                }
                .padding(.horizontal, 8)

                HStack(spacing: 14) {
                    LegendDot(color: Palette.pink.color, label: "dinner")
                    LegendDot(color: Palette.blue.color, label: "lunch")
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 8)
        }
    }
}

private struct MonthDayCell: View {
    var day: Date
    var isToday: Bool
    var isPast: Bool
    var cell: PlanCell?
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.white
                        : isPast ? Color.secondary : Color.primary)
                    .frame(width: 30, height: 30)
                    .background(isToday ? Palette.pink.color : Color.clear,
                                in: Circle())
                HStack(spacing: 3) {
                    Circle()
                        .fill(cell?.dinner != nil ? Palette.pink.color : Color.clear)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(cell?.lunch != nil ? Palette.blue.color : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [day.formatted(.dateTime.weekday(.wide).month().day())]
        if let dinner = cell?.dinner { parts.append("dinner: \(dinner.name)") }
        if let lunch = cell?.lunch { parts.append("lunch: \(lunch.name)") }
        if parts.count == 1 { parts.append("nothing planned") }
        return parts.joined(separator: ", ")
    }
}

private struct LegendDot: View {
    var color: Color
    var label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Day plan screen (tap a date → dinner + lunch for that day)

struct DayPlanSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let date: Date

    private var cell: PlanCell? {
        appState.planByDay[Calendar.current.startOfDay(for: date)]
    }

    var body: some View {
        NavigationStack {
            List {
                DaySlotSection(date: date, slotRaw: "dinner",
                               label: "Dinner", info: cell?.dinner)
                DaySlotSection(date: date, slotRaw: "lunch",
                               label: "Lunch", info: cell?.lunch)
            }
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct DaySlotSection: View {
    @EnvironmentObject var appState: AppState
    let date: Date
    let slotRaw: String
    let label: String
    let info: PlanSlotInfo?

    @State private var showPicker = false

    var body: some View {
        Section(label) {
            if let info {
                PlanAssignedRow(info: info, slotLabel: nil)
                    .contentShape(Rectangle())
                    .onTapGesture { showPicker = true }
                Button(info.pinned ? "Unpin" : "Pin") {
                    appState.togglePin(on: date, slotRaw: slotRaw)
                }
                .foregroundStyle(.secondary)
                Button("Clear", role: .destructive) {
                    appState.clearPlan(on: date, slotRaw: slotRaw)
                }
            } else {
                Button {
                    showPicker = true
                } label: {
                    Label("Choose \(label.lowercased())", systemImage: "plus.circle")
                        .foregroundStyle(Palette.pink.color)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            MealPickerSheet(date: date, slotRaw: slotRaw)
        }
    }
}

/// Shared assigned-slot row: name, optional slot label, GF chip, pin state.
struct PlanAssignedRow: View {
    var info: PlanSlotInfo
    var slotLabel: String?

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(info.needsRefill ? .secondary : .primary)
                if let slotLabel {
                    Text(slotLabel.lowercased())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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
