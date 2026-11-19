#!/usr/bin/env bash
# Prints the CHANGELOG.md section for VERSION. Exits 1 if there is none.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
version="${1:?usage: release-notes.sh VERSION}"
# Literal prefix match, so dots in VERSION are not regex wildcards.
notes=$(RELEASE_VERSION="$version" awk '
  BEGIN { h = "## [" ENVIRON["RELEASE_VERSION"] "]" }
  found && /^## \[/ { exit }
  index($0, h) == 1 { found=1; next }
  found && /^\[[^]]*\]: / { next }
  found && !started && /^[[:space:]]*$/ { next }
  found { started=1; print }
' CHANGELOG.md)
[[ -n "${notes//[[:space:]]/}" ]] || { echo "No CHANGELOG entry for $version" >&2; exit 1; }
printf '%s\n' "$notes"
