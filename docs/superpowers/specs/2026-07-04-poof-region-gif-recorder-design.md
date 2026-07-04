# Poof — Region → GIF Recorder (Design)

**Date:** 2026-07-04
**Status:** Approved for planning
**Platform:** macOS 12.3+ (built/tested on macOS 26 / Darwin 25)

## Summary

A menu-bar background app. Press **⌘⇧2** anywhere → a crosshair region selector
appears with the rest of the screen dimmed → drag to select a region → recording
starts automatically on mouse-up → press **Esc** to stop → an animated GIF of the
region is placed on the clipboard. No files are written to disk; the GIF is built
in memory and copied straight to the pasteboard.

Named "Poof" — the recording vanishes into the clipboard, nothing left behind.

## Goals

- Trigger with a single global hotkey (⌘⇧2), mirroring the feel of macOS's
  native screenshot shortcuts.
- Custom selection overlay: crosshair cursor, selected region shown clearly,
  everything else dimmed to emphasize the selection.
- Recording begins automatically once the region is selected (mouse-up).
- Direct-to-GIF: capture frames and encode a GIF in memory. Never persist an
  intermediate `.mov` or the `.gif` to disk.
- Esc stops the recording and copies the GIF to the clipboard only.
- Feel first-class and native; no runtime dependencies.

## Non-Goals (v1, YAGNI)

- Preferences UI (fps/size/duration are compile-time constants).
- Per-app / global optimized GIF palette (per-frame adaptive palette is fine).
- File-reference on the clipboard (raw GIF data only — explicit user choice).
- A region spanning multiple displays (selection is confined to one display).
- Editing, trimming, or re-recording.

## Permissions

**Screen Recording only.** Granted once via System Settings ▸ Privacy & Security
▸ Screen Recording. Triggered by the first `SCStream.start`.

**No Accessibility / Input Monitoring.** The global hotkey uses the Carbon
`RegisterEventHotKey` API, which does not require Accessibility (unlike
`NSEvent.addGlobalMonitorForEvents`). Esc-to-stop is implemented as a *second*
Carbon hotkey registered only while recording, so it also needs no extra
permission.

## Architecture

Menu-bar agent app (`LSUIElement = true`, no Dock icon). A small status-bar
icon provides quit and a permission shortcut. Built as a Swift Package, then
assembled into `Poof.app` and ad-hoc code-signed. Auto-starts at login via a
LaunchAgent. Bundle id `com.poof.recorder`.

### Flow / data path

```
⌘⇧2 (Carbon hotkey)
  → SelectionOverlay: dim all screens 35%, crosshair cursor, drag to select rect
  → mouseUp(rect): dim removed, thin red outline remains, overlay becomes
                   click-through so input reaches the apps being recorded
  → register Esc Carbon hotkey; RegionRecorder.start(rect, display)
  → SCStream frames (CVPixelBuffer) → CGImage → GifEncoder.append(img, delay=Δts)
  → Esc: stop stream; GifEncoder.finalize() → Data (in memory, no file)
  → NSPasteboard ← GIF ; HUD "Copied ✓" ; outline removed ; Esc hotkey removed
```

### Modules (each has one job)

| Module | Responsibility | Depends on |
|---|---|---|
| `AppDelegate` | NSApplication agent, menu-bar item, lifecycle, owns ⌘⇧2 | HotkeyManager, SelectionOverlay |
| `HotkeyManager` | Carbon `RegisterEventHotKey`: ⌘⇧2 (always) + Esc (record only) | Carbon |
| `SelectionOverlay` | Borderless transparent window per `NSScreen`; dim + even-odd mask hole at selection; crosshair; live size label; drag tracking; commit/cancel | AppKit, QuartzCore |
| `RegionRecorder` | ScreenCaptureKit stream cropped to region; emits frames + timestamps | ScreenCaptureKit |
| `GifEncoder` | ImageIO `CGImageDestination` (UTType.gif) → CFData in memory; per-frame delay from timestamp deltas; infinite loop | ImageIO |
| `Clipboard` | `NSPasteboard` set `com.compuserve.gif` | AppKit |
| `HUD` | Own small fade window for "Copied ✓" / errors (avoids notification permission) | AppKit |
| `Config` | Constants: fps 15, maxWidth 900, maxDuration 60s, dim alpha 0.35 | — |

### Key technical decisions

**Region capture via ScreenCaptureKit.** `SCContentFilter` for the display the
selection lives on; `SCStreamConfiguration.sourceRect` set to the selected rect
(points, relative to display origin); `width`/`height` set the output pixel size,
scaled so width ≤ `maxWidth` (900). `minimumFrameInterval = 1/fps` (15). SCK crops
and scales; no manual cropping.

**Timestamp-based GIF frame delays.** SCK only emits frames when pixels change.
A fixed 1/15 s delay would collapse a multi-second static pause into a single
frame's delay, replaying it too fast. Instead each GIF frame's delay is the delta
between consecutive frames' `presentationTimeStamp`, so playback matches real time
including pauses.

**In-memory GIF.** `CGImageDestination` writes to a `CFMutableData`, not a file
URL. On finalize, the `Data` goes straight to the pasteboard. Nothing touches disk.

**Frame conversion.** CVPixelBuffer (BGRA) → CGImage via a reused `CIContext`
(`createCGImage(CIImage(cvPixelBuffer:), from:)`).

### Error handling

- **No Screen-Recording grant** → first `SCStream.start` throws → HUD message and
  open System Settings ▸ Privacy ▸ Screen Recording. (First run triggers the OS
  prompt.)
- **Click without drag / rect too small** → cancel, record nothing.
- **Selection near display edge** → clamp rect to the display bounds.
- **60 s cap reached** → auto-stop exactly as if Esc, HUD notes the cap.
- **Recorder start failure** → HUD error, tear down overlay + hotkey, return to idle.
- **Esc during selection (before recording)** → cancel cleanly, remove overlay.

## Packaging

```
poof/
  Package.swift
  Sources/poof/
    main.swift              # NSApplication bootstrap, agent activation policy
    AppDelegate.swift
    HotkeyManager.swift
    SelectionOverlay.swift
    RegionRecorder.swift
    GifEncoder.swift
    Clipboard.swift
    HUD.swift
    Config.swift
  Tests/poofTests/
    GifEncoderTests.swift
  Resources/Info.plist       # LSUIElement, CFBundleIdentifier, LSMinimumSystemVersion 12.3
  build.sh                   # swift build -c release → assemble + ad-hoc sign Poof.app
  install.sh                 # copy to /Applications, write + load LaunchAgent
  README.md                  # setup, permissions, manual test plan
```

- **build.sh**: `swift build -c release`, assemble `Poof.app` bundle
  (`Contents/MacOS/poof`, `Contents/Info.plist`, `Contents/Resources`),
  `codesign --force --sign - Poof.app` (ad-hoc). TCC prompts on first capture.
- **install.sh**: build, copy `Poof.app` to `/Applications`, write
  `~/Library/LaunchAgents/com.poof.recorder.plist` (`RunAtLoad`, `KeepAlive`),
  `launchctl load`. Logs to `~/Library/Logs/poof.log`.

## Testing

- **Unit (no permissions needed):**
  - `GifEncoder`: feed two distinct `CGImage`s → assert output bytes begin with
    the `GIF89a` header and that re-decoding yields two frames with expected delays.
  - `Clipboard`: type identifier is `com.compuserve.gif`.
  - `Config`: values are sane (fps > 0, maxWidth > 0, maxDuration > 0).
- **Interactive (manual, in README):** ⌘⇧2 → select a region over a moving UI →
  Esc → paste into Messages/Slack → GIF animates at the right speed; nothing left
  on disk; Desktop clean.

## Open risks

- Ad-hoc code signature changes cdhash on each rebuild, so the Screen-Recording
  grant may need re-approval after a rebuild. Acceptable for a personal tool;
  a Developer ID signature (if available) would make the grant stable.
- ScreenCaptureKit API details (exact `sourceRect` coordinate space, frame
  callback threading) to be confirmed during implementation against the installed
  SDK.
