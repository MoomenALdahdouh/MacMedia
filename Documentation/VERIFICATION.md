# Release checklist

Use this before tagging a GitHub Release.

- [ ] `Scripts/run-tests.sh` passes
- [ ] `Scripts/package-app.sh` produces `build/MacMedia.app`
- [ ] `file build/MacMedia.app/Contents/MacOS/MacMedia` reports `arm64`
- [ ] `Scripts/package-dmg.sh` produces `build/MacMedia.dmg`
- [ ] App launches, opens a local video, play/pause/seek/fullscreen work
- [ ] Screenshot saves without crashing
- [ ] Play after end-of-file replays from the start
- [ ] Opening a file from Finder does not create a blank extra window
- [ ] README first-launch (Gatekeeper) steps still match reality
- [ ] DMG attached to the GitHub Release
