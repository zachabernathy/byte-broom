#!/usr/bin/env bash
# Packages build/Byte Broom.app into build/ByteBroom-VERSION.dmg (Apple silicon) or
# build/ByteBroom-VERSION-universal.dmg (Apple silicon and Intel) and writes a SHA-256 file.
# Signs the DMG when SIGN_IDENTITY is set; notarizes when NOTARY_KEY_ID, NOTARY_ISSUER and NOTARY_KEY are set.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail() { echo "make-dmg.sh: $*" >&2; exit 1; }

version="${1:?usage: make-dmg.sh VERSION}"
app="build/Byte Broom.app"
[[ -d "$app" ]] || fail "missing $app; run scripts/build-app.sh first"
case "$(lipo -archs "$app/Contents/MacOS/ByteBroom")" in
  arm64) suffix="" ;;
  "x86_64 arm64" | "arm64 x86_64") suffix="-universal" ;;
  *) fail "unexpected architectures in $app" ;;
esac
# No spaces: GitHub rewrites spaces in release asset names, which breaks shasum -c.
dmg="build/ByteBroom-$version$suffix.dmg"

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
mnt=""
trap '[[ -n "$mnt" ]] && hdiutil detach "$mnt" -force >/dev/null 2>&1; rm -rf "$tmp"' EXIT
# The staging folder becomes the volume root, so it must be world-readable.
staging="$tmp/staging"
secrets="$tmp/secrets"
mkdir -m 755 "$staging"
mkdir -m 700 "$secrets"

cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
mkdir "$staging/.background"
cp Resources/dmg-background.tiff "$staging/.background/background.tiff"
rm -f "$dmg" "$dmg.sha256"

# Finder addresses the volume by name, so a mounted "Byte Broom" (e.g. an older DMG) would get the layout instead.
[[ ! -e "/Volumes/Byte Broom" ]] || fail "eject the mounted Byte Broom volume first"
rw="$tmp/rw.dmg"
# hdiutil occasionally fails with "Resource busy" on CI machines; retry once.
create=(hdiutil create -volname "Byte Broom" -srcfolder "$staging" -fs HFS+ -layout NONE -format UDRW -ov "$rw")
"${create[@]}" >/dev/null || { sleep 5; "${create[@]}" >/dev/null; }
mnt=$(hdiutil attach "$rw" -readwrite -noverify -noautoopen | awk -F'\t' '/\/Volumes\//{print $NF}')
[[ "$mnt" == "/Volumes/Byte Broom" ]] || fail "unexpected mount point: $mnt"

# Icon centers must match Resources/make-dmg-background.swift. Bounds add ~28pt for the title bar.
osascript <<'EOF'
tell application "Finder"
  tell disk "Byte Broom"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 860, 548}
    set opts to icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "Byte Broom.app" of container window to {165, 180}
    set position of item "Applications" of container window to {495, 180}
    update without registering applications
    delay 5
    close
  end tell
end tell
EOF
sync
rm -rf "$mnt/.fseventsd"
hdiutil detach "$mnt" >/dev/null || { sleep 5; hdiutil detach "$mnt" -force >/dev/null; }
mnt=""
# Make Finder open the window on mount: finderInfo[2] (open folder) in the HFS+ volume header = root folder ID 2.
# This is what `bless --openfolder` writes, but bless refuses on Apple silicon.
[[ "$(xxd -s 1024 -l 2 -p "$rw")" == "482b" ]] || fail "expected an HFS+ volume header in $rw"
printf '\x00\x00\x00\x02' | dd of="$rw" bs=1 seek=$((1024 + 80 + 8)) conv=notrunc 2>/dev/null
[[ "$(xxd -s $((1024 + 80 + 8)) -l 4 -p "$rw")" == "00000002" ]] || fail "could not set the open-folder field"
hdiutil convert "$rw" -format UDZO -o "$dmg" >/dev/null

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
