#!/usr/bin/env bash
# Packages build/Byte Broom.app into build/ByteBroom-VERSION.dmg and writes a SHA-256 file.
# Signs the DMG when SIGN_IDENTITY is set; notarizes when NOTARY_KEY_ID, NOTARY_ISSUER and NOTARY_KEY are set.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail() { echo "make-dmg.sh: $*" >&2; exit 1; }

version="${1:?usage: make-dmg.sh VERSION}"
app="build/Byte Broom.app"
# No spaces: GitHub rewrites spaces in release asset names, which breaks shasum -c.
dmg="build/ByteBroom-$version.dmg"
[[ -d "$app" ]] || fail "missing $app; run scripts/build-app.sh first"

app_version=$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")
[[ "$app_version" == "$version" ]] || fail "app version is $app_version, not $version; rebuild with VERSION=$version"

notary_set=0
for v in NOTARY_KEY_ID NOTARY_ISSUER NOTARY_KEY; do
  if [[ -n "${!v:-}" ]]; then notary_set=$((notary_set + 1)); fi
done
if (( notary_set == 1 || notary_set == 2 )); then
  fail "set all of NOTARY_KEY_ID, NOTARY_ISSUER and NOTARY_KEY, or none"
fi
notarize=false
if (( notary_set == 3 )); then
  [[ -n "${SIGN_IDENTITY:-}" ]] || fail "notarizing needs SIGN_IDENTITY (Developer ID)"
  notarize=true
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# The staging folder becomes the volume root, so it must be world-readable.
staging="$tmp/staging"
secrets="$tmp/secrets"
mkdir -m 755 "$staging"
mkdir -m 700 "$secrets"

cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
rm -f "$dmg" "$dmg.sha256"
# hdiutil occasionally fails with "Resource busy" on CI machines; retry once.
hdiutil create -volname "Byte Broom" -srcfolder "$staging" -format UDZO -ov "$dmg" >/dev/null \
  || { sleep 5; hdiutil create -volname "Byte Broom" -srcfolder "$staging" -format UDZO -ov "$dmg" >/dev/null; }

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$dmg"
fi
if $notarize; then
  key="$secrets/notary.p8"
  printf '%s' "$NOTARY_KEY" | base64 --decode > "$key"
  auth=(--key "$key" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
  result="$secrets/submit.json"
  xcrun notarytool submit "$dmg" "${auth[@]}" --wait --timeout 30m --output-format json > "$result" || true
  id=$(plutil -extract id raw "$result" 2>/dev/null || true)
  status=$(plutil -extract status raw "$result" 2>/dev/null || true)
  if [[ "$status" != "Accepted" ]]; then
    echo "Notarization status: ${status:-unknown}" >&2
    cat "$result" >&2
    [[ -n "$id" ]] && xcrun notarytool log "$id" "${auth[@]}" >&2
    exit 1
  fi
  xcrun stapler staple "$dmg"
fi

(cd build && shasum -a 256 "$(basename "$dmg")" > "$(basename "$dmg").sha256")
echo "Built: $dmg"
