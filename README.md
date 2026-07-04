# Poof

Press **⌘⇧2**, drag a region, press **Esc** — an animated GIF of that region
lands on your clipboard. Nothing is written to disk.

## Requirements
- macOS 13+
- Swift toolchain (Xcode command line tools): `xcode-select --install`

## Build & install
```bash
./install.sh
```
Builds and installs `Poof.app` to `/Applications`, then launches it. A small
puff-of-smoke icon appears in the menu bar.

## First run
The first recording triggers a **Screen Recording** permission prompt
(System Settings ▸ Privacy & Security ▸ Screen Recording). Grant it, then
quit and reopen Poof. No other permission is needed (the global hotkey uses
Carbon, so no Accessibility grant).

## Use
1. Press **⌘⇧2** (or menu bar ▸ Record Region).
2. Screen dims; drag a crosshair rectangle over the area.
3. Release — recording starts (red outline).
4. Press **Esc** — the GIF is copied to the clipboard ("Copied ✓").
5. Paste anywhere that accepts GIFs (Messages, Slack, etc.).

## Settings (menu bar)
- **Frame Rate:** 10 / 15 / 20 / 30 fps (persists).
- **Launch at Login:** toggle — writes/removes a per-user LaunchAgent so Poof
  starts at your next login. (The LaunchAgent points at the app's current
  location, so toggle it again if you move the app.)
- **Hide Menu Bar Icon:** hides the icon; **open Poof again** (Finder/Spotlight)
  to bring it back.
- Recordings auto-stop at 60s.

## Uninstall
```bash
# turn off Launch at Login from the menu first, or:
launchctl bootout gui/$UID/com.poof.recorder 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.poof.recorder.plist
rm -rf /Applications/Poof.app
```

## Notes
- GIF is raw `com.compuserve.gif` clipboard data (no file reference), built in memory.
- Rebuilding re-signs ad-hoc; macOS may re-ask for Screen Recording after a rebuild.
- Log (when launched at login): `~/Library/Logs/poof.log`.
