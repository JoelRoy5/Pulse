#!/usr/bin/env bash
#
# build-testflight.sh — archive Pulse, export a signed .ipa, and (optionally)
# upload it to TestFlight.
#
# Prerequisites (one-time, see docs/testflight.md):
#   • Apple Developer Program membership + this Mac signed into that Apple ID in
#     Xcode (Settings → Accounts), so automatic signing can mint an
#     "Apple Distribution" certificate and an App Store provisioning profile.
#   • An App Store Connect app record for bundle id com.joelroy.pulse.
#   • For the upload step: an App Store Connect API key (.p8) and its Key ID +
#     Issuer ID, exported as env vars (see below).
#
# Usage:
#   ./Scripts/build-testflight.sh            # archive + export only
#   ASC_KEY_ID=XXXX ASC_ISSUER_ID=yyyy ASC_KEY_PATH=~/AuthKey_XXXX.p8 \
#     ./Scripts/build-testflight.sh --upload # archive + export + upload
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="Pulse"
ARCHIVE_PATH="$ROOT/build/Pulse.xcarchive"
EXPORT_DIR="$ROOT/build/export"
EXPORT_OPTS="$ROOT/Scripts/ExportOptions.plist"

echo "==> Regenerating project (xcodegen)"
xcodegen generate >/dev/null

echo "==> Archiving $SCHEME (Release)"
rm -rf "$ARCHIVE_PATH"
xcodebuild -project Pulse.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    clean archive

echo "==> Exporting .ipa"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTS" \
    -allowProvisioningUpdates

IPA="$(find "$EXPORT_DIR" -name '*.ipa' | head -1)"
echo "==> Exported: $IPA"

if [[ "${1:-}" == "--upload" ]]; then
    : "${ASC_KEY_ID:?set ASC_KEY_ID}"
    : "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
    : "${ASC_KEY_PATH:?set ASC_KEY_PATH to your AuthKey_XXXX.p8}"
    echo "==> Validating and uploading to TestFlight"
    xcrun altool --validate-app -f "$IPA" --type ios \
        --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
    xcrun altool --upload-app -f "$IPA" --type ios \
        --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
    echo "==> Uploaded. It will appear in App Store Connect → TestFlight after processing."
else
    echo "==> Skipped upload. Re-run with --upload (and ASC_* env vars) to send to TestFlight,"
    echo "    or drag the .ipa into Apple's Transporter app."
fi
