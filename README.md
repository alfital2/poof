# Poof

Press **⌘⇧2**, drag a region, press **Esc** — you get an animated GIF of that
region on your clipboard, and a little draggable thumbnail you can drop into a
coding agent (Claude Code, Cursor) so it reads every frame.

## Download
Grab the notarized build from
[Releases](https://github.com/alfital2/poof/releases/latest) — unzip and move
`Poof.app` to `/Applications`. It's Developer ID signed and notarized by Apple,
so it opens without Gatekeeper warnings.

## Build from source
```bash
./install.sh        # builds (ad-hoc signed) and installs to /Applications
./release.sh        # builds a Developer ID signed + notarized Poof.app.zip
```
Requires macOS 13+ and the Xcode command line tools (`xcode-select --install`).

## First run
The first recording triggers a **Screen Recording** permission prompt
(System Settings ▸ Privacy & Security ▸ Screen Recording). Grant it, then quit
and reopen Poof. No other permission is needed — the global hotkey uses Carbon,
so there's no Accessibility grant.

## Use
1. Press **⌘⇧2** (or menu bar ▸ Record Region).
2. Screen dims; drag a crosshair rectangle over the area.
3. Release — recording starts (a coral outline glows around it).
4. Press **Esc** — a small thumbnail of the GIF appears.
5. Either **paste** the GIF into an app (Messages, Slack, ...), or **drag the
   thumbnail** into a file-reading agent — it inserts a note like
   `for context, view this gif file at <path>` and the agent reads the frames.

## Settings (menu bar)
- **Frame Rate:** 10 / 15 / 20 / 30 fps (persists).
- **Keep GIF on Clipboard:** also copies the GIF on each capture (on by default).
- **Drag Message…:** edit the text inserted on drag; `[PATH]` is the file path.
- **Launch at Login:** writes/removes a per-user LaunchAgent (points at the app's
  current location, so toggle again if you move it).
- **Hide Menu Bar Icon:** hides the icon; **open Poof again** to bring it back.
- Recordings auto-stop at 60s.

## Uninstall
```bash
launchctl bootout gui/$UID/com.poof.recorder 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.poof.recorder.plist
rm -rf /Applications/Poof.app ~/Library/Caches/poof
```

## Notes
- The GIF is built in memory and put on the clipboard (raw data + a file
  reference). The one file on disk is the current capture at
  `~/Library/Caches/poof/…gif`, kept so the drag and file reference work; it's
  replaced on the next capture.
- Log (when launched at login): `~/Library/Logs/poof.log`.
