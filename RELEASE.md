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

The DMG contains MacMedia.app, an Applications shortcut, a short “How to Open” note, README, LICENSE, and third-party notices.

## Publish on GitHub

1. Tag the version (`v1.0.0`).
2. Push the tag.
3. Create a [GitHub Release](https://github.com/MoomenALdahdouh/MacMedia/releases/new) and attach `build/MacMedia.dmg`.
4. In the release notes, repeat the first-launch Gatekeeper steps from the README.

```bash
gh release create v1.0.0 build/MacMedia.dmg --title "MacMedia 1.0.0" --notes-file RELEASE_NOTES.md
```

## Signing and notarization

`Scripts/package-app.sh` signs with:

1. `CODESIGN_IDENTITY` if you set it
2. else the first **Developer ID Application** identity
3. else the first **Apple Development** identity
4. else ad-hoc (`codesign --sign -`)

Apple Development and ad-hoc builds work on the machine that signed them. Other Macs will see Gatekeeper until the user right-clicks → Open (or clears quarantine). That is documented for users.

To ship a Gatekeeper-clean download you need:

1. Apple Developer Program membership
2. Developer ID Application certificate
3. `codesign --options runtime --timestamp`
4. `xcrun notarytool submit`
5. `xcrun stapler staple`

Never embed fake certificates.

## Architecture check

```bash
file build/MacMedia.app/Contents/MacOS/MacMedia
otool -L build/MacMedia.app/Contents/MacOS/MacMedia
```

Expect `arm64`. Do not claim Universal 2 unless both architectures are present.
