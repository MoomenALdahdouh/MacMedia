# Releasing MacMedia

## Produce the artifacts

```bash
Scripts/vendor-libs.sh
Scripts/gen-test-media.sh
Scripts/run-tests.sh
Scripts/package-app.sh
Scripts/package-dmg.sh
```

Deliverables:

```text
build/MacMedia.app
build/MacMedia.dmg
```

The DMG contains MacMedia.app, an Applications shortcut, README, LICENSE, and third-party notices.

## Signing

`Scripts/package-app.sh` uses:

```text
Apple Development: moomenaldahdouh@gmail.com (NS9S9TNXA7)
```

when that identity is in the keychain. This is suitable for local development runs.

This machine does **not** have a Developer ID Application certificate, so:

- The app is **not** notarized
- Distribution outside this Mac will likely hit Gatekeeper

Never embed fake certificates. To ship to other users you need:

1. Apple Developer Program membership
2. Developer ID Application certificate
3. `codesign --options runtime --timestamp`
4. `xcrun notarytool submit`
5. `xcrun stapler staple`

## Architecture check

```bash
file build/MacMedia.app/Contents/MacOS/MacMedia
otool -L build/MacMedia.app/Contents/MacOS/MacMedia
```

Expect `arm64`. Do not claim Universal 2 unless both architectures are present.

## Gatekeeper (unsigned / development-signed builds)

```bash
xattr -dr com.apple.quarantine /Applications/MacMedia.app
```

Then open the app from Finder via **Open** on the context menu.
