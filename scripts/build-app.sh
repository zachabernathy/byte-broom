#!/usr/bin/env bash
# Builds "Byte Broom.app" in build/. Pass --install to copy it to ~/Applications.
# Env: VERSION (e.g. 1.2.3), BUILD_NUMBER, SIGN_IDENTITY (Developer ID; ad hoc if unset).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

install=false
case "${1:-}" in
  "") ;;
  --install) install=true ;;
  *) echo "usage: build-app.sh [--install]" >&2; exit 2 ;;
esac

if [[ -z "${VERSION:-}" ]]; then
  last=$(git describe --tags --abbrev=0 2>/dev/null || echo v0.0.0)
  VERSION="${last#v}-dev"
fi
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 0)}"

swift test
swift build -c release
bin="$(swift build -c release --show-bin-path)/ByteBroom"

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
echo "Built: $app ($VERSION, build $BUILD_NUMBER)"

if $install; then
  dest="$HOME/Applications/Byte Broom.app"
  mkdir -p "$HOME/Applications"
  rm -rf "$dest"
  cp -R "$app" "$dest"
  echo "Installed: $dest"
fi
