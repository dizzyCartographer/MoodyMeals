# Moody screen-builder brief

> **⚠️ HISTORICAL (round-1 screen builds, pre-unification).** Autonomous runs follow `CLAUDE.md` + `BACKLOG.md`; canon lives in `DECISIONS.md` (through D-48). Details below are stale where they conflict — e.g. AppState is now a facade over MoodyEngine (not demo data), "Wed ramen cook" is disposable seed lore (D-47: the chain example is a kid's fried-rice night), and safety badges derive from the engine.

You are building one SwiftUI screen of **Moody**, a meal-planning app whose interface is itself an accommodation for an AuDHD user. Read these before writing any code:

1. `design_handoff_moody_app/README.md` — the authoritative spec. Read ALL of it, especially your screen's section, Design Laws, Design Tokens, and The Cast.
2. Your assigned reference HTML in `design_refs/` — recreate it **pixel-faithfully** (px → pt 1:1). Inline styles in the HTML are the spec: colors, sizes, weights, radii, rotations, shadows.
3. The shared API you MUST build against (already written, already compiles — do not modify these files):
   - `Moody/DesignSystem/Theme.swift` — `Theme.*` colors/spacing/radii, `Palette` slots, `Font.baloo(_:_:)` / `Font.nunito(_:_:)`, `.hardShadow()` / `.softHardShadow()`
   - `Moody/DesignSystem/Components.swift` — `.inkCard()`, `MagnetDot`, `SafetyBadge`, `StickerChip`, `PillButtonStyle`, `StickyNote`, `BlobAvatar`, `SectionLabel`
   - `Moody/Models/Models.swift` — domain types
   - `Moody/Data/AppState.swift` — `@EnvironmentObject var appState: AppState`; demo data lives here

## Hard rules

- **Cast names**: exploration refs (2b–2i) use PLACEHOLDER names (Juno/Milo/Tas/Dev, Peach/Grandma Greens/Mr. Kettle). Replace with the authoritative cast: family = Ria, Chuck, Caddie (celiac), Elsie (plain/safe foods), Chad (×2, Wed ramen cook). Personas = Hannah, Cat, Julie. Voices per README §The Cast.
- **Design laws are requirements**: ≥48pt hit targets; ~3 options per choice; streak UI can never display "0"; no red anywhere, no overdue/guilt aesthetics; max ONE sticker moment per screen; tilt only decorative elements (±0.5–3°), never buttons/nav/text blocks; hard shadows have ZERO blur.
- Safety badges (Caddie GF ✓ / Elsie plain ✓ / Chad ×2 ✓) come from `meal.badges` — they are guarantees, render them wherever the spec shows them.
- Emoji glyphs in mockups (✓ ×2 🧲 🍜 🍲) are fine to keep as text for v1.
- **File placement**: write ONLY under `Moody/Screens/<YourScreen>/` (create the folder). Screen-specific helper views live in your files, prefixed with your screen name (e.g. `WeekPlanDayRow`). Do NOT touch DesignSystem/Models/Data/App files or other screens' folders.
- **Navigation**: do NOT reference other screens' types. Where the spec says a tap navigates elsewhere, expose an optional closure property (e.g. `var onOpenThread: (() -> Void)? = nil`) and call it. Wiring happens later.
- No third-party dependencies. iOS 17 APIs are fine. Respect `@Environment(\.accessibilityReduceMotion)` for any animation you add.
- Every screen file gets a `#Preview` with `.environmentObject(AppState())`.

## Self-check before you finish (required)

Run from `/Users/mariayarley/Documents/GitHub/MoodyMeals`:

```
swiftc -typecheck -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -target arm64-apple-ios17.0-simulator Moody/DesignSystem/*.swift Moody/Models/*.swift Moody/Data/*.swift Moody/Screens/<YourScreen>/*.swift
```

(Note: exclude `Moody/App/` and other screens' folders — they reference views being written concurrently.) Iterate until it exits 0. Do not run xcodebuild; do not launch simulators.
