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
}
