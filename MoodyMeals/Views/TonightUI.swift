import SwiftUI
import SwiftData

// ── M1-3: the Tonight view — today's dinner, swap, per-member badges.
// Functional only; the design brief's hero treatment comes later. ──

struct TonightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CalendarSyncService.self) private var calendarSync
    @Query(sort: \PlanEntry.date) private var allEntries: [PlanEntry]
    @Query private var members: [FamilyMember]
    @State private var pickingSwap = false

    private var tonight: PlanEntry? {
        allEntries.first {
            $0.slot == .dinner && $0.date == WeekPlan.dayAnchor(for: .now)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Tonight's dinner") {
                    if let entry = tonight, let meal = entry.meal {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(meal.title).font(.title3.bold())
                            if !meal.freeformNotes.isEmpty {
                                Text(meal.freeformNotes)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if entry.status == .swapped {
                                Text("swapped from the plan")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("Swap tonight", systemImage: "arrow.2.squarepath") {
                            pickingSwap = true
                        }
                    } else if let entry = tonight, entry.meal == nil {
                        Label("Needs a refill — the planned meal was deleted",
                              systemImage: "exclamationmark.triangle")
                        Button("Pick dinner") { pickingSwap = true }
                    } else {
                        Text("Nothing planned yet")
                            .foregroundStyle(.secondary)
                        Button("Pick dinner") { pickingSwap = true }
                    }
                }

                // SF-2: badges are per person, never household-wide.
                if let meal = tonight?.meal {
                    Section("Who's it safe for") {
                        ForEach(members) { member in
                            HStack {
                                Text(member.name)
                                Spacer()
                                memberBadge(meal: meal, member: member)
                            }
                        }
                    }
                }

                // SF-1: "what's safe for X tonight" — one tap away.
                Section("Safe foods by person") {
                    ForEach(members) { member in
                        NavigationLink("Safe for \(member.name)") {
                            SafeListView(member: member)
                        }
                    }
                }
            }
            .navigationTitle("Tonight")
            .sheet(isPresented: $pickingSwap) {
                NavigationStack {
                    MealPickerView(day: .now, slot: .dinner, attendees: members)
                }
            }
        }
    }

    @ViewBuilder
    private func memberBadge(meal: Meal, member: FamilyMember) -> some View {
        if Tonight.isSafe(meal, for: member) {
            Label("safe", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green).labelStyle(.titleAndIcon).font(.caption)
        } else if member.hardRequirements.contains(.glutenFree),
                  !meal.isGFVerifiedForCeliac {
            Label("not verified GF", systemImage: "exclamationmark.shield")
                .foregroundStyle(.red).font(.caption)
        } else if Tonight.isHidden(meal, for: member) {
            Label("not today", systemImage: "moon.zzz")
                .foregroundStyle(.orange).font(.caption)
        } else {
            Text("—").foregroundStyle(.secondary)
        }
    }
}

private struct SafeListView: View {
    @Environment(\.modelContext) private var modelContext
    let member: FamilyMember
    @State private var meals: [Meal] = []

    var body: some View {
        List {
            if meals.isEmpty {
                Text("No safe foods flagged for \(member.name) yet — mark meals safe from the meal editor.")
                    .foregroundStyle(.secondary)
            }
            ForEach(meals) { Text($0.title) }
        }
        .navigationTitle("Safe for \(member.name)")
        .task { meals = (try? Tonight.safeMeals(for: member, in: modelContext)) ?? [] }
    }
}
