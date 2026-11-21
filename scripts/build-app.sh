#!/usr/bin/env bash
# Builds "Byte Broom.app" in build/ for Apple silicon. Pass --universal to also include Intel,
# and --install to copy the app to ~/Applications.
# Env: VERSION (e.g. 1.2.3), BUILD_NUMBER, SIGN_IDENTITY (Developer ID; ad hoc if unset).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

install=false
arch=(--arch arm64)
for opt in "$@"; do
  case "$opt" in
    --install) install=true ;;
    --universal) arch=(--arch arm64 --arch x86_64) ;;
    *) echo "usage: build-app.sh [--universal] [--install]" >&2; exit 2 ;;
  esac
done

if [[ -z "${VERSION:-}" ]]; then
  last=$(git describe --tags --abbrev=0 2>/dev/null || echo v0.0.0)
  VERSION="${last#v}-dev"
fi
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 0)}"

swift test
swift build -c release "${arch[@]}"
bin="$(swift build -c release "${arch[@]}" --show-bin-path)/ByteBroom"

app="build/Byte Broom.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/ByteBroom"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$app/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$app/Contents/Info.plist"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$app"
else
  codesign --force --options runtime --sign - "$app"
fi
codesign --verify --strict "$app"
echo "Built: $app ($VERSION, build $BUILD_NUMBER, $(lipo -archs "$app/Contents/MacOS/ByteBroom"))"

if $install; then
  dest="$HOME/Applications/Byte Broom.app"
  mkdir -p "$HOME/Applications"
  rm -rf "$dest"
  cp -R "$app" "$dest"
  echo "Installed: $dest"
fi
