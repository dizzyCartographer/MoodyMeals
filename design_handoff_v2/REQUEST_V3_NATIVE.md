# Design request V3 — the native reset (D-56, 2026-07-13)

For the claude.design workspace, via the shared-folder pipeline.

## What changed and why

Ria called it at midnight on build 61: the basics weren't working and the
flair was in the way. *"Use the color palette, but let's go back to something
more swifty looking… save this look, we may come back to it… let's get it
actually working before we get cute."*

The sticker-aisle look is **preserved, not discarded**: git tag
`sticker-aisle-v1`, screens parked in `Attic/StickerAisle/`. This request is
about the NEW baseline.

## What shipped as the new baseline (build 62)

Standard SwiftUI idiom, system type, native Lists/Forms, SF Symbols tab bar:
**Today · Plan · Meals · Shopping · Settings.**

- **Today** — tonight's meal + truthful per-member badges, Decide/Swap,
  capacity segmented control, guarantee line.
- **Plan** — the calendar that was missing: 28 rolling days, every day takes
  dinner + optional lunch via a searchable picker; pin/clear via swipe;
  HC-5 warn-confirm inside the picker (named, plain, once).
- **Meals** — searchable library, detail with recipes + per-line GF chips,
  editors as native Forms.
- **Shopping** — guarantee verdict, runs as navigation rows, in-store
  checklist with real completion, add-your-own items.
- **Settings** — household (GF guarantee with deliberate-weight removal),
  always-stocked shelf, calendar sync switch.

Palette survives as ACCENT (currently pink for tint) + badge tints where
color carries meaning: green = verified guarantee, yellow = attention.
No red exists anywhere (law 4).

## What we'd like from design

1. A **native-first visual pass** over the five tabs: type scale, spacing,
   where the palette accents land (and where they shouldn't), empty states.
   Standard components stay standard — this is calibration, not a new kit.
2. **Badge/chip language** within native idiom: the truthful states
   (GF ✓ / check / not GF, and soon the D-44 bands: safe / awaiting
   substitution / not checked yet / unsafe) need a quiet, consistent form.
3. **The D-44 band + chips (D-46) surface direction** — per-person ❤️/✅/❌
   chips on meal rows/detail, and the awaiting-substitution indicator that is
   calm, never alarming, schedulable.
4. Voice laws bind all copy in mockups: law 4 (never shame/zero/red),
   D-48 (reassurance shown, never narrated), **D-55 (demand-free: no
   imperatives, no "locked", pin not lock, no pressure jokes, no minimizers
   — PDA in the household; accessibility, not taste)**.

Screenshots of the shipped baseline: `docs/screenshots/nb-*.png`.
