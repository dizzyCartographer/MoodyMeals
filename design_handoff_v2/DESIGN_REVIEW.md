# DESIGN_REVIEW.md — designer pass on the overnight build (2026-07-08)

Reviewed: all 8 screenshots in `docs/screenshots/` against `design_handoff_moody_app/`. Overall: **ship-quality fidelity.** Verdicts on the flagged calls, then new findings.

## Verdicts on HANDOFF.md's flagged judgment calls

1. **Muted-label contrast (~2.4:1)** → **Adopt the fix everywhere.** Use each slot's primary `label` color for companion text on tints; retire `labelMuted` (or alias it to `label`). The muted values were mockup artifacts; 4.4:1 readability wins. The yellow slot's adjudication is the right pattern — apply to pink ("PB 23 · the rebuild") and the rest.
2. **"JUL 6–12" chip reads as a third sticker** → **De-sticker it, keep it.** Drop the tilt and colored hard shadow; render as a plain ink-outline pill (or bare `textSecondary` text). Info stays, law 5 satisfied.
3. **ANCHOR + JOY on week plan** → **Fine as built.** They render as semantic status chips (ink bg, no tilt), not decorative sticker moments. The one-sticker law targets decoration.
4. **Backgrounds: shelf token over white mockup pages** → **Correct call.** Token sheet wins over per-mockup canvas white.
5. **Vent in Quicksand** → **Approved.** It's the mockup's face; bundling it was right.
6. **Custom back chip, swipe-back disabled** → **Restore swipe-back.** Losing the edge-swipe violates law 1 (low activation energy) — a top-left corner reach is expensive one-handed. Keep the styled chip, re-enable the interactive pop gesture (small UIKit shim on the hosting nav controller). If that fights the hidden nav bar, an edge-drag `DragGesture` fallback is acceptable.
7. **Magnet labels from `meal.id` ("Tue gfmac")** → agreed; add a `displayKeyword` on `Meal` when real data lands.

## New findings (ranked)

1. **Vertical dead zones on Home and Shopping (medium).** The mockups' 874pt compositions assumed filled frames; on device, Home has a ~500pt gap between WEEK MAGNETS and the tank check, Shopping between the Costco card and ALWAYS STOCKED. Don't add content (no-filler rule). Distribute instead: even spacing between section groups (`Spacer(minLength:)` between groups rather than one giant bottom spacer), letting cards sit ~15% larger line-heights apart. Tank check + footer staying pinned to the bottom is correct — it's the thumb zone.
2. **Streaks caption contradicts the strip (medium, content-state bug).** Caption says "Wednesday was a rest day… streak intact" but the W tile renders as dashed/future, not the blue rest-day tile from the mockup. The caption should derive from strip data: only mention a rest day when one is rendered; otherwise omit the caption line entirely.
3. **Confetti z-order (low).** Celebration pieces land on top of safety badges and buttons mid-fall. Acceptable for a transient moment; if cheap, exclude the Tonight card's badge row from the overlay's hit area visually (confetti behind the card, in front of the background).
4. **Emoji glyphs (🧲 🍜 🍲, red magnet) (low).** Mockup parity, fine for demo. The red horseshoe magnet is the only red in the app — swap to a drawn magnet (ink + slot color) in the icon pass already noted in the handoff README.
5. **Persona/family color reuse (note, no action).** Cat (blob, blue) and Elsie (chip, blue) share a slot — acceptable because blob-vs-circle carries the distinction; keep that rule deliberate if palettes shrink to 3 user colors.

## Praise worth keeping (don't regress)

- Week plan rows, effort dots as drawn shapes, CHAD COOKS chip: pixel-right.
- Thread: Hannah's pinned dark banner, "Julie · comeback dept", quick-reply pills, "lurking counts as participating ✓" — the register is exactly the brief.
- Onboarding step 1 leading with "celiac safety comes FIRST" and per-kid guarantee chips: this is the product's spine, rendered correctly.
- `Streak.displayDay` clamping + PB sticker hiding: law 4 honored in code, not just copy.
- Small-widget tap made non-destructive: right call, matches "decide" as a deliberate act.
