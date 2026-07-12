# TestFlight runbook (TF-1)

Everything mechanical is scripted; the parts below marked **(Maria)** need her
Apple account in a browser and can't be automated.

## State

- Signing: automatic, team `RC99K6SXQX` (project.yml). Device archives register
  the bundle IDs + the App Group on the portal via `-allowProvisioningUpdates`.
- Bundle IDs: app `com.mariayarley.Moody`, widgets
  `com.mariayarley.Moody.MoodyWidgets`, App Group `group.com.mariayarley.Moody`.
- Export compliance: `ITSAppUsesNonExemptEncryption=false` is baked in — no
  per-build compliance interview.
- Version `0.2.0`; build number = git commit count, stamped by the lane.
- App icon: kit-derived placeholder (fridge door + magnet + sticky),
  `scripts/make_app_icon.swift` regenerates it. NEEDS-VISUAL-REVIEW.
- Engine ships with `ENABLE_TESTABILITY=YES` in Release (the app uses
  `@testable import MoodyEngine` until the public-API pass, BACKLOG P5-1).
  Functional, slightly de-optimized — known, accepted for the MVP.

## One-time setup

0. **(Maria — currently THE blocker)** Accept Apple's updated Program License
   Agreement: developer.apple.com → Account (or Agreements). Verified
   2026-07-12: archives fail with *"PLA Update available … agree to the latest
   Program License Agreement"* until this is done — no profile or App Group
   can be issued. One minute, Account Holder only.
1. Run `scripts/testflight.sh` once (no flag). This archives and exports an
   .ipa, registering the bundle IDs + App Group on the developer portal along
   the way. First run may pop a keychain-access prompt for the signing key —
   click "Always Allow".
2. **(Maria)** appstoreconnect.apple.com → My Apps → **+** → New App:
   - Platform iOS · Bundle ID `com.mariayarley.Moody` (in the dropdown after
     step 1) · SKU anything (e.g. `moody-001`) · Primary language.
   - **Name**: must be unique across the whole App Store even for
     TestFlight-only apps — "Moody" is likely taken; see the decision digest.
3. Upload: `scripts/testflight.sh --upload` (or drop the .ipa on Transporter).

## Per build after that

```
scripts/testflight.sh --upload
```

Suite runs first (nothing uploads over a red test), build number stamps
itself, processing takes ~5–15 min, then the build appears under TestFlight.

## Testers

- **Maria immediately**: TestFlight tab → Internal Testing → add her own
  account to a group. Internal builds are live the moment processing ends —
  no review.
- **The family**: External Testing → create a "Family" group → add emails →
  first build submits to Beta App Review (usually <24 h; later builds are
  instant). ASC will ask for: what-to-test notes, a contact email, and a
  privacy policy URL (a one-page GitHub Pages note about on-device data
  suffices for beta).
- Everyone installs the TestFlight app, taps the invite link, done.
