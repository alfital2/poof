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
Installs `Poof.app` to `/Applications`, registers a login LaunchAgent, and starts it.
A scissors icon appears in the menu bar.

## First run
The first recording triggers a **Screen Recording** permission prompt
(System Settings ▸ Privacy & Security ▸ Screen Recording). Grant it, then
quit and reopen Poof (or it relaunches via the LaunchAgent). No other
permission is needed.

## Use
1. Press **⌘⇧2** (or menu bar ▸ Record Region).
2. Screen dims; drag a crosshair rectangle over the area.
3. Release — recording starts (red outline).
4. Press **Esc** — the GIF is copied to the clipboard ("Copied ✓").
5. Paste anywhere that accepts GIFs (Messages, Slack, etc.).

## Settings
- **Frame Rate:** menu bar ▸ Frame Rate ▸ 10 / 15 / 20 / 30 fps (persists).
- Recordings auto-stop at 60s.

## Uninstall
```bash
launchctl unload ~/Library/LaunchAgents/com.poof.recorder.plist
rm ~/Library/LaunchAgents/com.poof.recorder.plist
rm -rf /Applications/Poof.app
```

## Notes
- GIF is raw `com.compuserve.gif` clipboard data (no file reference), built in memory.
- Rebuilding re-signs ad-hoc; macOS may re-ask for Screen Recording after a rebuild.
