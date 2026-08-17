# Shipping Pulse to TestFlight

The repo is set up for TestFlight distribution, but the first upload needs a few
things only your Apple Developer account can provide. This is the full runbook.

## What's already done (in the repo)

- `Scripts/ExportOptions.plist` — App Store distribution export options (team `APQT8U28NL`, automatic signing).
- `Scripts/build-testflight.sh` — archives, exports a signed `.ipa`, and optionally uploads.
- Deployment target is **iOS 17.0 / watchOS 10.0** (broad reach; iPhone XS and newer).
- Version starts at `MARKETING_VERSION 1.0`, `CURRENT_PROJECT_VERSION 1` (in `project.yml`).

## One-time account setup (only you can do this)

1. **Apple Developer Program** — an active membership (individual or org) for team `APQT8U28NL`.
2. **App Store Connect app record** — create an app for bundle id `com.joelroy.pulse`
   at https://appstoreconnect.apple.com → Apps → **+** → New App (pick the bundle id,
   set a name/primary language/SKU).
3. **Distribution signing** — sign this Mac into that Apple ID in
   **Xcode → Settings → Accounts**. Automatic signing then creates the
   "Apple Distribution" certificate + App Store provisioning profile on first archive.
   (Currently only an *Apple Development* cert exists locally, which is not enough
   for TestFlight.)

## Easiest path — Xcode GUI (recommended for the first upload)

1. Open `Pulse.xcodeproj` (run `xcodegen generate` first if needed).
2. Select the **Pulse** scheme and **Any iOS Device (arm64)** as the run destination.
3. **Product → Archive**. Wait for the Organizer to open.
4. **Distribute App → TestFlight & App Store Connect → Upload**. Accept the
   automatic-signing prompts. This creates the distribution cert/profile for you.
5. After ~5–15 min of processing, the build shows in App Store Connect → your app
   → **TestFlight**. Add it to Internal Testing (or a group) and invite testers.

## CLI path (repeatable, for later)

Create an **App Store Connect API key** (App Store Connect → Users and Access →
Integrations → keys): download the `AuthKey_XXXX.p8`, and note the **Key ID** and
**Issuer ID**. Then:

```bash
ASC_KEY_ID=XXXXXXXXXX \
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
ASC_KEY_PATH=~/AuthKey_XXXXXXXXXX.p8 \
./Scripts/build-testflight.sh --upload
```

Without `--upload` it just produces `build/export/*.ipa`, which you can drag into
Apple's **Transporter** app to upload manually.

> Keep the `.p8` key out of git. Store it under `~/.appstoreconnect/private_keys/`
> or pass an absolute path via `ASC_KEY_PATH`. Never commit it.

## Bumping the build for each upload

App Store Connect rejects a re-used build number. Before each upload, increment
`CURRENT_PROJECT_VERSION` in `project.yml` (and `MARKETING_VERSION` for a new
user-facing version), then `xcodegen generate`.

## Notes

- TestFlight testers need a device on **iOS 17+ / watchOS 10+**.
- Export compliance: the app uses only HTTPS (standard encryption). On first
  submit, answer the encryption question accordingly or add
  `ITSAppUsesNonExemptEncryption = NO` to the app Info.plist to skip the prompt.
- Real API keys stay in the gitignored `Config/*.xcconfig`; they are injected at
  build time and are not part of this flow.
