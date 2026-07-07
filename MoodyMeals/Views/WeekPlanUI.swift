import SwiftUI
import SwiftData

// ── M1-1: manual planning week grid. Functional only — attendance chips
// and visual design land later (attendees default to everyone, D-5). ──

struct WeekPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CalendarSyncService.self) private var calendarSync
    @Query(sort: \PlanEntry.date) private var allEntries: [PlanEntry]
    @Query private var members: [FamilyMember]
    @State private var weekAnchor: Date = .now
    @State private var picking: PickTarget?
    @State private var showingSyncExplanation = false

    private struct PickTarget: Identifiable {
        let day: Date
        let slot: SlotKind
        var id: String { "\(day.timeIntervalSince1970)-\(slot.rawValue)" }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(WeekPlan.weekDays(containing: weekAnchor), id: \.self) { day in
                    Section(day.formatted(.dateTime.weekday(.wide).month().day())) {
                        slotRow(day: day, slot: .dinner)
                        slotRow(day: day, slot: .breakfast)
                    }
                }
            }
            .navigationTitle("Week Plan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // CAL-1/CAL-3: sync to the Moody calendar; denial shows
                    // a clear explanation, never a silent failure.
                    Button("Sync to Calendar",
                           systemImage: calendarSync.isAvailable
                               ? "calendar.badge.checkmark" : "calendar.badge.exclamationmark") {
                        Task {
                            await calendarSync.requestAccessIfNeeded()
                            if calendarSync.isAvailable {
                                calendarSync.syncAll(in: modelContext)
                            } else {
                                showingSyncExplanation = true
                            }
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Previous week", systemImage: "chevron.left") {
                        weekAnchor = Calendar.current.date(
                            byAdding: .weekOfYear, value: -1, to: weekAnchor) ?? weekAnchor
                    }
                    Button("This week") { weekAnchor = .now }
                    Button("Next week", systemImage: "chevron.right") {
                        weekAnchor = Calendar.current.date(
                            byAdding: .weekOfYear, value: 1, to: weekAnchor) ?? weekAnchor
                    }
                }
            }
            .alert("Calendar sync is off", isPresented: $showingSyncExplanation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(calendarSync.unavailableReason ?? "")
            }
            .sheet(item: $picking) { target in
                NavigationStack {
                    MealPickerView(day: target.day, slot: target.slot,
                                   attendees: members) // default: everyone (D-5)
                }
            }
        }
    }

    @ViewBuilder
    private func slotRow(day: Date, slot: SlotKind) -> some View {
        let entry = allEntries.first {
            $0.slot == slot && $0.date == WeekPlan.dayAnchor(for: day)
        }
        HStack {
            Text(slot == .dinner ? "Dinner" : "Breakfast")
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
            if let entry {
                Text(entry.meal?.title ?? "⚠︎ needs refill") // D-37 flag state
                Spacer()
                Button {
                    try? WeekPlan.setLocked(!entry.isLocked, entry: entry, in: modelContext)
                } label: {
                    Image(systemName: entry.isLocked ? "lock.fill" : "lock.open")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(entry.isLocked ? "Unlock" : "Lock")
            } else {
                Button("Add") { picking = PickTarget(day: day, slot: slot) }
                    .buttonStyle(.borderless)
                Spacer()
            }
        }
        .swipeActions(edge: .trailing) {
            if let entry {
                Button("Clear", role: .destructive) {
                    calendarSync.remove(entry, in: modelContext) // CAL-2: no orphans
                    try? WeekPlan.clear(entry: entry, in: modelContext)
                }
                Button(entry.meal == nil ? "Assign" : "Swap") {
                    picking = PickTarget(day: day, slot: slot)
                }
            }
        }
    }
}

struct MealPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CalendarSyncService.self) private var calendarSync
    let day: Date
    let slot: SlotKind
    let attendees: [FamilyMember]

    @Query(sort: \Meal.title) private var meals: [Meal]
    @State private var pendingGFConfirm: Meal?

    private var candidates: [Meal] {
        meals.filter { $0.rotationState == .active && $0.slots.contains(slot) }
    }

    var body: some View {
        List(candidates) { meal in
            Button {
                select(meal)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.title)
                        Text(meal.effort.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if meal.isGFVerifiedForCeliac {
                        Image(systemName: "checkmark.shield")
                            .foregroundStyle(.green)
                            .accessibilityLabel("GF verified")
                    }
                }
            }
            .tint(.primary)
        }
        .navigationTitle(slot == .dinner ? "Pick dinner" : "Pick breakfast")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        // HC-5 ⚠️: manual override allowed, silent never.
        .alert("Not verified gluten-free",
               isPresented: Binding(get: { pendingGFConfirm != nil },
                                    set: { if !$0 { pendingGFConfirm = nil } }),
               presenting: pendingGFConfirm) { meal in
            Button("Assign anyway", role: .destructive) { assign(meal) }
            Button("Cancel", role: .cancel) { pendingGFConfirm = nil }
        } message: { meal in
            let names = WeekPlan.gfAttendeeNames(attendees)
                .formatted(.list(type: .and))
            Text("\(meal.title) isn't verified safe for \(names), who's home that night. Assign it anyway?")
        }
    }

    private func select(_ meal: Meal) {
        if WeekPlan.requiresGFConfirmation(meal, attendees: attendees) {
            pendingGFConfirm = meal // never silently (HC-5)
        } else {
            assign(meal)
        }
    }

    private func assign(_ meal: Meal) {
        if let entry = try? WeekPlan.assign(meal, on: day, slot: slot,
                                            attendees: attendees, in: modelContext) {
            calendarSync.sync(entry, in: modelContext) // CAL-1/CAL-2: event follows the plan
        }
        dismiss()
    }
}
