# Contributing to Byte Broom

Thanks for your interest in Byte Broom. Bug reports, ideas, and pull requests are all welcome.

## Requirements

- A Mac with Apple silicon
- macOS 14 Sonoma or later
- Full Xcode (not just the Command Line Tools), for XCTest and the macOS SDK

## Build and test

```bash
swift build                     # debug build
swift test                      # run the unit tests
scripts/build-app.sh            # tests, release build, and build/Byte Broom.app
scripts/build-app.sh --install  # same, then copies the app to ~/Applications
```

The app has no dependencies beyond Apple's frameworks.

## Testing against a fake home folder

Byte Broom moves real files to the Trash, so try your changes on a throwaway folder. Set `BYTE_BROOM_HOME` and Byte Broom scans that folder's `Desktop`, `Documents`, `Downloads`, `Movies`, `Music`, and `Pictures` instead of your own:

```bash
mkdir -p /tmp/demo/Downloads
mkfile -n 500m /tmp/demo/Downloads/big-file.bin
open --env BYTE_BROOM_HOME=/tmp/demo "build/Byte Broom.app"
```

Never point `BYTE_BROOM_HOME` at a folder with files you care about.

## Pull requests

- Keep each pull request small and focused on one change.
- Add or update tests for logic in `Sources/ByteBroomCore`.
- Make sure `swift build` has no warnings and `swift test` passes.
- Add a line to `CHANGELOG.md` under `## [Unreleased]`.

## Releasing

1. Move the `[Unreleased]` entries in `CHANGELOG.md` into a new `## [X.Y.Z] - YYYY-MM-DD` section, and add a `[X.Y.Z]: https://github.com/zachabernathy/byte-broom/releases/tag/vX.Y.Z` link line at the bottom.
2. Get that change onto `main` (merge a pull request, or push to `main`).
3. Tag the commit on `main` and push the tag:

   ```bash
   git checkout main && git pull
   git tag -a vX.Y.Z -m "Byte Broom X.Y.Z"
   git push origin vX.Y.Z
   ```

The Release workflow builds the app, makes `ByteBroom-X.Y.Z.dmg` and its checksum, attests the build, and publishes the GitHub release with the changelog section as notes.

Signing and notarization are optional. They run only when these repository secrets are set:

| Secret | What it is |
| --- | --- |
| `SIGN_IDENTITY` | Developer ID Application identity name |
| `SIGN_CERT_P12` | Base64 of the Developer ID certificate (`.p12`) |
| `SIGN_CERT_PASSWORD` | Password for the `.p12` |
| `NOTARY_KEY_ID` | App Store Connect API key ID |
| `NOTARY_ISSUER` | App Store Connect issuer ID |
| `NOTARY_KEY` | Base64 of the App Store Connect API key (`.p8`) |

Set the three `SIGN_*` secrets together, and the three `NOTARY_*` secrets together. Notarization needs signing. Without them, the app is signed ad hoc. Until a release is notarized, users see the first-launch Open Anyway step.
