import Foundation

/// Documented defaults from build-spec §8, in one place. These seed the
/// runtime-tunable `TuningConfig` singleton when it lands (M4-1) and provide
/// per-model init defaults until then. Tests reference these, never literals
/// (CLAUDE.md hard rule: no hardcoded behavioral numbers).
enum TuningDefaults {
    /// §8 `componentFreshnessDefaultDays` — producer→consumer leftover window.
    static let componentFreshnessDays = 2
    /// §8 `anchorVarietyPeriodWeeks` — how often an anchor's specific meal rotates.
    static let anchorVarietyPeriodWeeks = 3
    /// §8 `cooldownDefaultDays` — "sick of this" rest length (D-2: min 42, max 180).
    static let cooldownDefaultDays = 42
    /// NEW at M1-2 (not in §8 — noted in RUNLOG): calendar-event timing for
    /// synced plan entries. Migrate into TuningConfig at M4-1.
    static let dinnerEventHour = 18
    static let breakfastEventHour = 7
    static let planEventDurationMinutes = 60
    /// SL-4's pantry-staple exclusion list — assumed on hand, skipped by the
    /// shopping explosion unless flagged out. User-editable at M4-1.
    static let pantryStapleExclusions: Set<String> =
        ["oil", "salt", "pepper", "butter", "taco seasoning"]
    /// Spec §4 step 4: shelf-stable items prefer the bulk run when needed
    /// more than this many days out ("preferring bulk when >2 weeks out").
    static let bulkPreferenceLeadDays = 14
    /// §8 `inventoryConfidenceThreshold` — belief level at which inventory
    /// offsets the shopping list (below it: buy anyway).
    static let inventoryConfidenceThreshold = 0.7
    /// §8 `guaranteeLookaheadRuns` — how many confirmed runs ahead the
    /// guarantee covers. v1 implements exactly 1 (next per tier); the knob
    /// itself becomes runtime-tunable at M4-1.
    static let guaranteeLookaheadRuns = 1
    /// NEW at M2-3 (review finding, noted in RUNLOG): how many days fresh
    /// (`freshShort`) groceries stay good — bounds both routing (a run too
    /// far before the meal can't carry its fresh items) and purchase
    /// coverage (last week's cod never covers this week's).
    static let freshShortShelfDays = 4
}
