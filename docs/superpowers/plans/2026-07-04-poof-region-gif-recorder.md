# Poof — Region → GIF Recorder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS menu-bar app: press ⌘⇧2 → dim-screen crosshair region select → auto-record → Esc → animated GIF on the clipboard, no files on disk.

**Architecture:** Swift Package with a `PoofCore` library (all logic + AppKit UI) and a thin `poof` executable entry point. Assembled into `Poof.app` (agent app, `LSUIElement`), ad-hoc signed, auto-started via LaunchAgent. Global hotkey via Carbon; region capture via ScreenCaptureKit; GIF encoded in memory via ImageIO; result placed on `NSPasteboard`.

**Tech Stack:** Swift 5.9, AppKit, Carbon.HIToolbox (hotkeys), ScreenCaptureKit (capture), ImageIO/CoreImage (GIF encode), Swift Package Manager + XCTest.

## Global Constraints

- Minimum macOS: **13.0** (SwiftPM platform floor; ScreenCaptureKit region APIs require 12.3+).
- Permissions: **Screen Recording only**. No Accessibility / Input Monitoring. Hotkeys MUST use Carbon `RegisterEventHotKey`, never `NSEvent.addGlobalMonitorForEvents`.
- No file is ever written for the recording pipeline — GIF is built in `NSMutableData` and copied to the pasteboard.
- Bundle id: `com.poof.recorder`. App name: `Poof`. Agent app: `LSUIElement = true`.
- Config constants: `maxWidth = 900`, `maxDuration = 60s`, `dimAlpha = 0.35`. Frame rate is user-tweakable (`availableFPS = [10,15,20,30]`, default `15`), stored in `UserDefaults` key `"fps"`.
- Clipboard GIF type identifier: `com.compuserve.gif`.
- Frequent commits: one per task minimum.

---

### Task 1: Project scaffold + Config + menu-bar shell

**Files:**
- Create: `Package.swift`
- Create: `Sources/poof/main.swift`
- Create: `Sources/PoofCore/Config.swift`
- Create: `Sources/PoofCore/AppDelegate.swift`
- Create: `Resources/Info.plist`
- Create: `build.sh`
- Test: `Tests/PoofCoreTests/ConfigTests.swift`

**Interfaces:**
- Produces: `enum Config` with `static let maxWidth: Int`, `maxDuration: TimeInterval`, `dimAlpha: Double`, `availableFPS: [Int]`, `defaultFPS: Int`, and `static var fps: Int { get set }` (persisted in `UserDefaults`).
- Produces: `final class AppDelegate: NSObject, NSApplicationDelegate` (public), initially only a status-bar item with a Quit item.

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "poof",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PoofCore", path: "Sources/PoofCore"),
        .executableTarget(name: "poof", dependencies: ["PoofCore"], path: "Sources/poof"),
        .testTarget(name: "PoofCoreTests", dependencies: ["PoofCore"], path: "Tests/PoofCoreTests"),
    ]
)
```

- [ ] **Step 2: Write the failing Config test**

`Tests/PoofCoreTests/ConfigTests.swift`:

```swift
import XCTest
@testable import PoofCore

final class ConfigTests: XCTestCase {
    override func setUp() {
        UserDefaults.standard.removeObject(forKey: "fps")
    }

    func testDefaultFPSWhenUnset() {
        UserDefaults.standard.removeObject(forKey: "fps")
        XCTAssertEqual(Config.fps, 15)
    }

    func testFPSPersistsWhenValid() {
        Config.fps = 20
        XCTAssertEqual(Config.fps, 20)
    }

    func testInvalidFPSFallsBackToDefault() {
        UserDefaults.standard.set(999, forKey: "fps")
        XCTAssertEqual(Config.fps, 15)
    }

    func testConstantsSane() {
        XCTAssertGreaterThan(Config.maxWidth, 0)
        XCTAssertGreaterThan(Config.maxDuration, 0)
        XCTAssertTrue(Config.availableFPS.contains(Config.defaultFPS))
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `swift test --filter ConfigTests`
Expected: FAIL — `PoofCore` / `Config` does not exist yet (compile error).

- [ ] **Step 4: Write `Config.swift`**

`Sources/PoofCore/Config.swift`:

```swift
import Foundation

public enum Config {
    public static let maxWidth = 900
    public static let maxDuration: TimeInterval = 60
    public static let dimAlpha = 0.35
    public static let availableFPS = [10, 15, 20, 30]
    public static let defaultFPS = 15

    public static var fps: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "fps")
            return availableFPS.contains(stored) ? stored : defaultFPS
        }
        set { UserDefaults.standard.set(newValue, forKey: "fps") }
    }
}
```

- [ ] **Step 5: Write the minimal `AppDelegate`**

`Sources/PoofCore/AppDelegate.swift`:

```swift
import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Poof")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Poof", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Poof", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        self.statusItem = item
    }
}
```

- [ ] **Step 6: Write `main.swift`**

`Sources/poof/main.swift`:

```swift
import AppKit
import PoofCore

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 7: Write `Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Poof</string>
    <key>CFBundleDisplayName</key><string>Poof</string>
    <key>CFBundleIdentifier</key><string>com.poof.recorder</string>
    <key>CFBundleExecutable</key><string>poof</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Poof</string>
</dict>
</plist>
```

- [ ] **Step 8: Write `build.sh`**

`build.sh`:

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="Poof.app"
BIN="poof"

echo "Building release binary..."
swift build -c release

echo "Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$BIN" "$APP/Contents/MacOS/$BIN"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

echo "Ad-hoc code signing..."
codesign --force --sign - "$APP"

echo "Done: $APP"
```

- [ ] **Step 9: Run the Config tests**

Run: `chmod +x build.sh && swift test --filter ConfigTests`
Expected: PASS (4 tests).

- [ ] **Step 10: Build and launch, verify menu-bar icon**

Run:
```bash
./build.sh
open Poof.app
```
Expected: a scissors icon appears in the menu bar. Clicking it shows "Poof" + "Quit Poof". Quit works. No Dock icon appears.

- [ ] **Step 11: Commit**

```bash
git add Package.swift Sources Resources build.sh Tests
git commit -m "feat: scaffold Poof agent app with Config and menu-bar shell"
```

---

### Task 2: GifEncoder (in-memory GIF)

**Files:**
- Create: `Sources/PoofCore/GifEncoder.swift`
- Test: `Tests/PoofCoreTests/GifEncoderTests.swift`

**Interfaces:**
- Produces: `final class GifEncoder`
  - `init?(loopForever: Bool = true)`
  - `func append(_ image: CGImage, delay: Double)`
  - `var count: Int { get }`
  - `func finalize() -> Data?` (returns nil if zero frames)

- [ ] **Step 1: Write the failing test**

`Tests/PoofCoreTests/GifEncoderTests.swift`:

```swift
import XCTest
import CoreGraphics
import ImageIO
@testable import PoofCore

final class GifEncoderTests: XCTestCase {
    private func solidImage(gray: CGFloat, size: Int = 8) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(red: gray, green: gray, blue: gray, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return ctx.makeImage()!
    }

    func testEncodesTwoFramesWithGif89aHeader() throws {
        let encoder = try XCTUnwrap(GifEncoder())
        encoder.append(solidImage(gray: 0.1), delay: 0.1)
        encoder.append(solidImage(gray: 0.9), delay: 0.1)
        XCTAssertEqual(encoder.count, 2)

        let data = try XCTUnwrap(encoder.finalize())
        XCTAssertGreaterThan(data.count, 0)

        // GIF89a magic
        let header = String(bytes: data.prefix(6), encoding: .ascii)
        XCTAssertEqual(header, "GIF89a")

        // Decodes back to 2 frames
        let src = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        XCTAssertEqual(CGImageSourceGetCount(src), 2)
    }

    func testFinalizeReturnsNilWithNoFrames() {
        let encoder = GifEncoder()
        XCTAssertNil(encoder?.finalize())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter GifEncoderTests`
Expected: FAIL — `GifEncoder` undefined (compile error).

- [ ] **Step 3: Write `GifEncoder.swift`**

`Sources/PoofCore/GifEncoder.swift`:

```swift
import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

public final class GifEncoder {
    private let data = NSMutableData()
    private let destination: CGImageDestination
    private var frameCount = 0

    public init?(loopForever: Bool = true) {
        guard let dest = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.gif.identifier as CFString, 0, nil
        ) else { return nil }
        destination = dest
        let gifProps: [CFString: Any] = [kCGImagePropertyGIFLoopCount: loopForever ? 0 : 1]
        CGImageDestinationSetProperties(
            dest, [kCGImagePropertyGIFDictionary: gifProps] as CFDictionary
        )
    }

    public func append(_ image: CGImage, delay: Double) {
        let safeDelay = max(delay, 0.02) // GIF viewers clamp very small delays
        let frameProps: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: safeDelay,
                kCGImagePropertyGIFUnclampedDelayTime: safeDelay,
            ] as [CFString: Any]
        ]
        CGImageDestinationAddImage(destination, image, frameProps as CFDictionary)
        frameCount += 1
    }

    public var count: Int { frameCount }

    public func finalize() -> Data? {
        guard frameCount > 0, CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter GifEncoderTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/PoofCore/GifEncoder.swift Tests/PoofCoreTests/GifEncoderTests.swift
git commit -m "feat: in-memory GIF encoder via ImageIO"
```

---

### Task 3: Clipboard

**Files:**
- Create: `Sources/PoofCore/Clipboard.swift`
- Test: `Tests/PoofCoreTests/ClipboardTests.swift`

**Interfaces:**
- Produces: `enum Clipboard` with `static let gifType: NSPasteboard.PasteboardType` (`com.compuserve.gif`) and `static func copyGIF(_ data: Data)`.

- [ ] **Step 1: Write the failing test**

`Tests/PoofCoreTests/ClipboardTests.swift`:

```swift
import XCTest
import AppKit
@testable import PoofCore

final class ClipboardTests: XCTestCase {
    func testGifTypeIdentifier() {
        XCTAssertEqual(Clipboard.gifType.rawValue, "com.compuserve.gif")
    }

    func testCopyGIFRoundTrips() {
        let sample = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]) // "GIF89a"
        Clipboard.copyGIF(sample)
        let read = NSPasteboard.general.data(forType: Clipboard.gifType)
        XCTAssertEqual(read, sample)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ClipboardTests`
Expected: FAIL — `Clipboard` undefined.

- [ ] **Step 3: Write `Clipboard.swift`**

`Sources/PoofCore/Clipboard.swift`:

```swift
import AppKit

public enum Clipboard {
    public static let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")

    public static func copyGIF(_ data: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: gifType)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ClipboardTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/PoofCore/Clipboard.swift Tests/PoofCoreTests/ClipboardTests.swift
git commit -m "feat: clipboard GIF copy helper"
```

---

### Task 4: HotkeyManager (Carbon)

**Files:**
- Create: `Sources/PoofCore/HotkeyManager.swift`
- Modify: `Sources/PoofCore/AppDelegate.swift` (temporary demo wiring, reverted in Task 8)

**Interfaces:**
- Produces: `final class HotkeyManager`
  - `init()`
  - `@discardableResult func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> UInt32` (returns an id)
  - `func unregister(_ id: UInt32)`
- Key/modifier values used elsewhere: ⌘⇧2 = `keyCode 0x13`, `modifiers UInt32(cmdKey | shiftKey)`. Esc = `keyCode 0x35`, `modifiers 0`.

This task is verified manually (Carbon installs a real system hotkey; not unit-testable).

- [ ] **Step 1: Write `HotkeyManager.swift`**

`Sources/PoofCore/HotkeyManager.swift`:

```swift
import Carbon.HIToolbox
import AppKit

public final class HotkeyManager {
    public typealias Handler = () -> Void

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: Handler] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    public init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData, let event else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            manager.handlers[hkID.id]?()
            return noErr
        }, 1, &spec, selfPtr, &eventHandler)
    }

    @discardableResult
    public func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping Handler) -> UInt32 {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x504F4F46), id: id) // 'POOF'
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs[id] = ref
            handlers[id] = handler
        }
        return id
    }

    public func unregister(_ id: UInt32) {
        if let ref = refs[id] { UnregisterEventHotKey(ref) }
        refs[id] = nil
        handlers[id] = nil
    }
}
```

- [ ] **Step 2: Add temporary demo wiring to `AppDelegate`**

In `AppDelegate`, add a stored property and register ⌘⇧2 to beep. This is temporary — Task 8 replaces it.

Add property near the top of the class:
```swift
    private let hotkeys = HotkeyManager()
```
At the end of `applicationDidFinishLaunching(_:)` add:
```swift
        hotkeys.register(keyCode: 0x13, modifiers: UInt32(cmdKey | shiftKey)) {
            NSSound.beep()
            NSLog("Poof: hotkey fired")
        }
```
Add `import Carbon.HIToolbox` at the top of `AppDelegate.swift`.

- [ ] **Step 3: Build and manually verify**

Run:
```bash
./build.sh && open Poof.app
```
Then press ⌘⇧2 with any app focused.
Expected: a system beep each press; `log stream --predicate 'eventMessage contains "Poof: hotkey"' --info` shows "Poof: hotkey fired". No Accessibility permission prompt appears.

- [ ] **Step 4: Commit**

```bash
git add Sources/PoofCore/HotkeyManager.swift Sources/PoofCore/AppDelegate.swift
git commit -m "feat: Carbon global hotkey manager (demo-wired to beep)"
```

---

### Task 5: HUD (transient status window)

**Files:**
- Create: `Sources/PoofCore/HUD.swift`

**Interfaces:**
- Produces: `enum HUD` with `static func flash(_ text: String)` — shows a small centered borderless label window that fades out after ~1.2s. Must be called on the main thread.

Verified manually (visual).

- [ ] **Step 1: Write `HUD.swift`**

`Sources/PoofCore/HUD.swift`:

```swift
import AppKit

public enum HUD {
    public static func flash(_ text: String) {
        let padding: CGFloat = 20
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.sizeToFit()

        let size = NSSize(width: label.frame.width + padding * 2,
                          height: label.frame.height + padding)
        guard let screen = NSScreen.main else { return }
        let origin = NSPoint(x: screen.frame.midX - size.width / 2,
                             y: screen.frame.midY - size.height / 2)

        let window = NSWindow(contentRect: NSRect(origin: origin, size: size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.hasShadow = false

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        container.layer?.cornerRadius = 12
        label.frame.origin = NSPoint(x: padding, y: padding / 2)
        container.addSubview(label)
        window.contentView = container
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            ctx.allowsImplicitAnimation = true
            window.animator().alphaValue = 1
        }, completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.4
                    window.animator().alphaValue = 0
                }, completionHandler: {
                    window.orderOut(nil)
                })
            }
        })
    }
}
```

- [ ] **Step 2: Temporarily call HUD from the hotkey to verify**

In `AppDelegate.applicationDidFinishLaunching`, change the demo hotkey handler body to:
```swift
            HUD.flash("Poof ✓")
```
(remove the `NSSound.beep()` / `NSLog` lines).

- [ ] **Step 3: Build and manually verify**

Run: `./build.sh && open Poof.app`, press ⌘⇧2.
Expected: a rounded dark "Poof ✓" pill fades in center-screen and fades out after ~1s.

- [ ] **Step 4: Commit**

```bash
git add Sources/PoofCore/HUD.swift Sources/PoofCore/AppDelegate.swift
git commit -m "feat: transient HUD window"
```

---

### Task 6: SelectionOverlay (dim + crosshair + drag select)

**Files:**
- Create: `Sources/PoofCore/SelectionOverlay.swift`
- Modify: `Sources/PoofCore/AppDelegate.swift` (temporary demo wiring)

**Interfaces:**
- Produces: `final class SelectionOverlay`
  - `func begin(onCommit: @escaping (_ rect: CGRect, _ screen: NSScreen) -> Void, onCancel: @escaping () -> Void)` — shows the dim/crosshair overlay on every screen. `rect` is in AppKit **global** coordinates (bottom-left origin). Selecting a zero/tiny area cancels.
  - `func enterRecordingMode()` — removes the dim, keeps a red outline around the committed rect, makes the overlay click-through so input reaches apps below.
  - `func end()` — tears down all overlay windows.

Verified manually (interactive UI).

- [ ] **Step 1: Write `SelectionOverlay.swift`**

`Sources/PoofCore/SelectionOverlay.swift`:

```swift
import AppKit

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class OverlayView: NSView {
    enum Mode { case selecting, recording }
    var mode: Mode = .selecting { didSet { needsDisplay = true } }

    var onCommit: ((CGRect) -> Void)?   // rect in this view's window/global coords
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect? { didSet { needsDisplay = true } }
    private(set) var committedRect: NSRect?

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        guard mode == .selecting else { return }
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = NSRect(origin: startPoint!, size: .zero)
    }

    override func mouseDragged(with event: NSEvent) {
        guard mode == .selecting, let start = startPoint else { return }
        let p = convert(event.locationInWindow, from: nil)
        currentRect = NSRect(x: min(start.x, p.x), y: min(start.y, p.y),
                             width: abs(p.x - start.x), height: abs(p.y - start.y))
    }

    override func mouseUp(with event: NSEvent) {
        guard mode == .selecting, let rect = currentRect else { onCancel?(); return }
        if rect.width < 8 || rect.height < 8 { onCancel?(); return }
        committedRect = rect
        onCommit?(rect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } // Esc
    }

    override func draw(_ dirtyRect: NSRect) {
        switch mode {
        case .selecting:
            NSColor.black.withAlphaComponent(Config.dimAlpha).setFill()
            if let sel = currentRect, sel.width > 0, sel.height > 0 {
                let path = NSBezierPath(rect: bounds)
                path.append(NSBezierPath(rect: sel))
                path.windingRule = .evenOdd
                path.fill()
                NSColor.white.setStroke()
                let border = NSBezierPath(rect: sel)
                border.lineWidth = 1
                border.stroke()
                drawSizeLabel(for: sel)
            } else {
                NSBezierPath(rect: bounds).fill()
            }
        case .recording:
            if let sel = committedRect {
                NSColor.systemRed.setStroke()
                let border = NSBezierPath(rect: sel)
                border.lineWidth = 2
                border.stroke()
            }
        }
    }

    private func drawSizeLabel(for sel: NSRect) {
        let text = "\(Int(sel.width)) × \(Int(sel.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let strSize = str.size()
        let pt = NSPoint(x: sel.minX, y: sel.maxY + 4)
        str.draw(at: pt)
        _ = strSize
    }
}

public final class SelectionOverlay {
    private var windows: [OverlayWindow] = []
    private var views: [OverlayView] = []
    private var onCommit: ((CGRect, NSScreen) -> Void)?
    private var onCancel: (() -> Void)?

    public init() {}

    public func begin(onCommit: @escaping (CGRect, NSScreen) -> Void,
                      onCancel: @escaping () -> Void) {
        self.onCommit = onCommit
        self.onCancel = onCancel
        end() // clear any stale state

        for screen in NSScreen.screens {
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless,
                                       backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let view = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onCommit = { [weak self] rectInWindow in
                guard let self else { return }
                // Convert to global coordinates by offsetting with the window origin.
                let global = CGRect(x: rectInWindow.origin.x + screen.frame.origin.x,
                                    y: rectInWindow.origin.y + screen.frame.origin.y,
                                    width: rectInWindow.width, height: rectInWindow.height)
                self.committedScreen = screen
                self.onCommit?(global, screen)
            }
            view.onCancel = { [weak self] in self?.cancel() }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
            views.append(view)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private var committedScreen: NSScreen?

    public func enterRecordingMode() {
        for (window, view) in zip(windows, views) {
            view.mode = .recording
            window.ignoresMouseEvents = true
        }
    }

    public func end() {
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        views.removeAll()
    }

    private func cancel() {
        end()
        onCancel?()
    }
}
```

- [ ] **Step 2: Temporarily wire the overlay to the hotkey**

Replace the demo hotkey handler body in `AppDelegate.applicationDidFinishLaunching` with:
```swift
            self.overlay.begin(onCommit: { rect, screen in
                NSLog("Poof: committed rect \(rect) on \(screen.localizedName)")
                self.overlay.enterRecordingMode()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.overlay.end()
                    HUD.flash("(recording would run here)")
                }
            }, onCancel: {
                self.overlay.end()
            })
```
Add the property to `AppDelegate`:
```swift
    private let overlay = SelectionOverlay()
```
Make the hotkey closure capture self weakly/strongly consistently — since `AppDelegate` lives for the app lifetime, capture `self` directly is fine, but silence the warning with `[self]` if needed.

- [ ] **Step 3: Build and manually verify**

Run: `./build.sh && open Poof.app`, press ⌘⇧2.
Expected:
- The whole screen dims ~35%; cursor becomes a crosshair.
- Dragging shows a clear (undimmed) rectangle with a white border and a "W × H" label.
- Releasing: dim disappears, a red outline remains for ~1.5s, then a HUD shows. The log prints the committed global rect.
- Pressing Esc mid-selection removes the overlay with no commit.

- [ ] **Step 4: Commit**

```bash
git add Sources/PoofCore/SelectionOverlay.swift Sources/PoofCore/AppDelegate.swift
git commit -m "feat: dim/crosshair region selection overlay"
```

---

### Task 7: RegionRecorder (ScreenCaptureKit)

**Files:**
- Create: `Sources/PoofCore/RegionRecorder.swift`
- Modify: `Sources/PoofCore/AppDelegate.swift` (temporary demo wiring)

**Interfaces:**
- Produces: `final class RegionRecorder: NSObject, SCStreamOutput`
  - `static func display(for screen: NSScreen, completion: @escaping (SCDisplay?) -> Void)` — resolves the `SCDisplay` matching an `NSScreen`.
  - `static func makeStreamRect(globalRect: CGRect, screen: NSScreen) -> (sourceRect: CGRect, outputSize: CGSize)` — converts a global (bottom-left) AppKit rect into a display-local top-left `sourceRect` (points) and a scaled output pixel size (width ≤ `Config.maxWidth`).
  - `func start(display: SCDisplay, sourceRect: CGRect, outputSize: CGSize, fps: Int, onFrame: @escaping (CGImage, Double) -> Void, onError: @escaping (Error) -> Void)`
  - `func stop(completion: @escaping () -> Void)`
- Consumes: `Config` (only via caller passing `fps`).

The coordinate conversion (`makeStreamRect`) is pure and unit-tested; the live capture is verified manually (needs Screen Recording permission).

- [ ] **Step 1: Write the failing conversion test**

`Tests/PoofCoreTests/RegionRecorderTests.swift`:

```swift
import XCTest
import AppKit
@testable import PoofCore

final class RegionRecorderTests: XCTestCase {
    // A synthetic screen-like frame: 1440x900 at origin (0,0), scale 2.
    func testMakeStreamRectConvertsToTopLeftLocal() {
        // We can't fabricate an NSScreen; test the pure math helper instead.
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let scale: CGFloat = 2
        // A 200x100 rect whose bottom-left is at (100, 700) in global coords.
        let global = CGRect(x: 100, y: 700, width: 200, height: 100)

        let result = RegionRecorder.convert(globalRect: global,
                                            screenFrame: screenFrame, scale: scale)
        // Top-left local: x unchanged (100). topY = maxY(900) - rect.maxY(800) = 100.
        XCTAssertEqual(result.sourceRect, CGRect(x: 100, y: 100, width: 200, height: 100))
        // Output width: 200pt * 2 = 400px, under maxWidth(900) -> stays 400x200.
        XCTAssertEqual(result.outputSize, CGSize(width: 400, height: 200))
    }

    func testOutputScaledDownWhenAboveMaxWidth() {
        let screenFrame = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let scale: CGFloat = 1
        let global = CGRect(x: 0, y: 0, width: 1800, height: 900)
        let result = RegionRecorder.convert(globalRect: global,
                                            screenFrame: screenFrame, scale: scale)
        // 1800px wide > 900 maxWidth -> scale to 900 wide, height 450.
        XCTAssertEqual(result.outputSize, CGSize(width: 900, height: 450))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter RegionRecorderTests`
Expected: FAIL — `RegionRecorder.convert` undefined.

- [ ] **Step 3: Write `RegionRecorder.swift`**

`Sources/PoofCore/RegionRecorder.swift`:

```swift
import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreImage

@available(macOS 13.0, *)
public final class RegionRecorder: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private let ciContext = CIContext()
    private let queue = DispatchQueue(label: "com.poof.recorder")
    private var lastPTS: CMTime?
    private var onFrame: ((CGImage, Double) -> Void)?
    private var fallbackFPS: Int = 15

    public override init() { super.init() }

    // MARK: Pure coordinate math (unit tested)

    public struct StreamRect: Equatable {
        public let sourceRect: CGRect
        public let outputSize: CGSize
    }

    public static func convert(globalRect: CGRect, screenFrame: CGRect,
                               scale: CGFloat) -> StreamRect {
        // AppKit global coords are bottom-left origin. SCK sourceRect is top-left,
        // in points, relative to the display.
        let localX = globalRect.minX - screenFrame.minX
        let localTopY = screenFrame.maxY - globalRect.maxY
        let sourceRect = CGRect(x: localX, y: localTopY,
                                width: globalRect.width, height: globalRect.height)

        var outW = globalRect.width * scale
        var outH = globalRect.height * scale
        if outW > CGFloat(Config.maxWidth) {
            let k = CGFloat(Config.maxWidth) / outW
            outW *= k
            outH *= k
        }
        return StreamRect(sourceRect: sourceRect,
                          outputSize: CGSize(width: outW.rounded(), height: outH.rounded()))
    }

    public static func makeStreamRect(globalRect: CGRect,
                                      screen: NSScreen) -> (sourceRect: CGRect, outputSize: CGSize) {
        let r = convert(globalRect: globalRect, screenFrame: screen.frame,
                        scale: screen.backingScaleFactor)
        return (r.sourceRect, r.outputSize)
    }

    // MARK: Display resolution

    public static func display(for screen: NSScreen, completion: @escaping (SCDisplay?) -> Void) {
        let targetID = (screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, _ in
            let match = content?.displays.first { $0.displayID == targetID }
            DispatchQueue.main.async { completion(match ?? content?.displays.first) }
        }
    }

    // MARK: Capture

    public func start(display: SCDisplay, sourceRect: CGRect, outputSize: CGSize, fps: Int,
                      onFrame: @escaping (CGImage, Double) -> Void,
                      onError: @escaping (Error) -> Void) {
        self.onFrame = onFrame
        self.fallbackFPS = fps
        self.lastPTS = nil

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = Int(outputSize.width)
        config.height = Int(outputSize.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 6

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        do {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
            stream.startCapture { error in if let error { onError(error) } }
            self.stream = stream
        } catch {
            onError(error)
        }
    }

    public func stop(completion: @escaping () -> Void) {
        guard let stream else { completion(); return }
        stream.stopCapture { _ in
            DispatchQueue.main.async { completion() }
        }
        self.stream = nil
    }

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                       of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }

        // Only keep frames SCK marks as complete (skip idle/blank).
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]],
           let statusRaw = attachments.first?[.status] as? Int,
           let status = SCFrameStatus(rawValue: statusRaw), status != .complete {
            return
        }

        let pts = sampleBuffer.presentationTimeStamp
        let delay: Double
        if let last = lastPTS {
            delay = max((pts - last).seconds, 0.0)
        } else {
            delay = 1.0 / Double(fallbackFPS)
        }
        lastPTS = pts

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        onFrame?(cgImage, delay)
    }
}
```

- [ ] **Step 4: Run the conversion tests**

Run: `swift test --filter RegionRecorderTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Temporarily wire capture to prove live frames**

In `AppDelegate`, add:
```swift
    private var recorder: RegionRecorder?
    private var frameProbeCount = 0
```
Replace the overlay `onCommit` body (from Task 6) with:
```swift
                self.overlay.enterRecordingMode()
                let (src, out) = RegionRecorder.makeStreamRect(globalRect: rect, screen: screen)
                RegionRecorder.display(for: screen) { display in
                    guard let display else { self.overlay.end(); return }
                    let recorder = RegionRecorder()
                    self.recorder = recorder
                    self.frameProbeCount = 0
                    recorder.start(display: display, sourceRect: src, outputSize: out,
                                   fps: Config.fps, onFrame: { _, _ in
                        self.frameProbeCount += 1
                    }, onError: { error in
                        NSLog("Poof: capture error \(error)")
                        DispatchQueue.main.async { self.overlay.end() }
                    })
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        recorder.stop {
                            NSLog("Poof: captured \(self.frameProbeCount) frames")
                            self.overlay.end()
                            HUD.flash("\(self.frameProbeCount) frames")
                        }
                    }
                }
```

- [ ] **Step 6: Build and manually verify (grants Screen Recording)**

Run: `./build.sh && open Poof.app`, press ⌘⇧2, select a region over a moving UI (e.g. a playing video), wait 3s.
Expected:
- First run: macOS prompts for Screen Recording permission. Grant it, then quit and `open Poof.app` again (TCC grant applies on next launch).
- HUD shows a nonzero frame count (e.g. "35 frames"); log confirms.

- [ ] **Step 7: Commit**

```bash
git add Sources/PoofCore/RegionRecorder.swift Tests/PoofCoreTests/RegionRecorderTests.swift Sources/PoofCore/AppDelegate.swift
git commit -m "feat: ScreenCaptureKit region recorder + coordinate conversion"
```

---

### Task 8: Wire the full flow + Frame Rate menu + Esc-to-stop + duration cap

**Files:**
- Modify: `Sources/PoofCore/AppDelegate.swift` (replace all temporary demo wiring with the real pipeline)

**Interfaces:**
- Consumes: `HotkeyManager`, `SelectionOverlay`, `RegionRecorder`, `GifEncoder`, `Clipboard`, `HUD`, `Config`.
- Produces: the complete, shippable `AppDelegate`.

This task replaces the demo scaffolding from Tasks 4–7 with the final implementation, so paste the whole file.

- [ ] **Step 1: Replace `AppDelegate.swift` entirely**

`Sources/PoofCore/AppDelegate.swift`:

```swift
import AppKit
import Carbon.HIToolbox

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeys = HotkeyManager()
    private let overlay = SelectionOverlay()
    private var statusItem: NSStatusItem?

    // Recording state
    private var recorder: RegionRecorder?
    private var encoder: GifEncoder?
    private let encodeQueue = DispatchQueue(label: "com.poof.encode")
    private var escHotkeyID: UInt32?
    private var capTimer: Timer?
    private var isRecording = false

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        hotkeys.register(keyCode: 0x13, modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.startSelection()
        }
    }

    // MARK: Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Poof")
        item.menu = buildMenu()
        self.statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let record = NSMenuItem(title: "Record Region", action: #selector(recordFromMenu),
                                keyEquivalent: "2")
        record.keyEquivalentModifierMask = [.command, .shift]
        record.target = self
        menu.addItem(record)

        let rateItem = NSMenuItem(title: "Frame Rate", action: nil, keyEquivalent: "")
        let rateMenu = NSMenu()
        for fps in Config.availableFPS {
            let sub = NSMenuItem(title: "\(fps) fps", action: #selector(setFPS(_:)), keyEquivalent: "")
            sub.target = self
            sub.tag = fps
            sub.state = (fps == Config.fps) ? .on : .off
            rateMenu.addItem(sub)
        }
        rateItem.submenu = rateMenu
        menu.addItem(rateItem)

        menu.addItem(.separator())
        let perm = NSMenuItem(title: "Screen Recording Permission…",
                              action: #selector(openScreenRecordingSettings), keyEquivalent: "")
        perm.target = self
        menu.addItem(perm)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Poof",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func recordFromMenu() { startSelection() }

    @objc private func setFPS(_ sender: NSMenuItem) {
        Config.fps = sender.tag
        statusItem?.menu = buildMenu() // refresh checkmarks
    }

    @objc private func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Flow

    private func startSelection() {
        guard !isRecording else { return }
        overlay.begin(onCommit: { [weak self] rect, screen in
            self?.beginRecording(rect: rect, screen: screen)
        }, onCancel: { [weak self] in
            self?.overlay.end()
        })
    }

    private func beginRecording(rect: CGRect, screen: NSScreen) {
        overlay.enterRecordingMode()
        let (sourceRect, outputSize) = RegionRecorder.makeStreamRect(globalRect: rect, screen: screen)
        let fps = Config.fps

        RegionRecorder.display(for: screen) { [weak self] display in
            guard let self else { return }
            guard let display else {
                self.overlay.end()
                HUD.flash("No display found")
                return
            }
            let encoder = GifEncoder()
            let recorder = RegionRecorder()
            self.encoder = encoder
            self.recorder = recorder
            self.isRecording = true

            recorder.start(display: display, sourceRect: sourceRect, outputSize: outputSize, fps: fps,
                onFrame: { [weak self] image, delay in
                    self?.encodeQueue.async { encoder?.append(image, delay: delay) }
                },
                onError: { [weak self] error in
                    NSLog("Poof: capture error \(error)")
                    DispatchQueue.main.async { self?.abortRecording(message: "Grant Screen Recording") }
                })

            // Esc stops (Carbon hotkey, active only while recording).
            self.escHotkeyID = self.hotkeys.register(keyCode: 0x35, modifiers: 0) { [weak self] in
                self?.stopRecording()
            }
            // Safety cap.
            self.capTimer = Timer.scheduledTimer(withTimeInterval: Config.maxDuration,
                                                 repeats: false) { [weak self] _ in
                self?.stopRecording()
            }
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        if let escHotkeyID { hotkeys.unregister(escHotkeyID) }
        escHotkeyID = nil
        capTimer?.invalidate()
        capTimer = nil

        let recorder = self.recorder
        let encoder = self.encoder
        recorder?.stop { [weak self] in
            guard let self else { return }
            self.encodeQueue.async {
                let data = encoder?.finalize()
                DispatchQueue.main.async {
                    self.overlay.end()
                    self.recorder = nil
                    self.encoder = nil
                    if let data, !data.isEmpty {
                        Clipboard.copyGIF(data)
                        HUD.flash("Copied ✓")
                    } else {
                        HUD.flash("Nothing captured")
                    }
                }
            }
        }
    }

    private func abortRecording(message: String) {
        isRecording = false
        if let escHotkeyID { hotkeys.unregister(escHotkeyID) }
        escHotkeyID = nil
        capTimer?.invalidate()
        capTimer = nil
        recorder?.stop { }
        recorder = nil
        encoder = nil
        overlay.end()
        HUD.flash(message)
    }
}
```

- [ ] **Step 2: Build and run the full end-to-end flow**

Run: `./build.sh && open Poof.app`
Then: press ⌘⇧2 → select a region over a moving UI → press **Esc**.
Expected:
- Dim + crosshair selection, red outline during recording.
- On Esc: "Copied ✓" HUD.
- Paste (⌘V) into Messages or Slack → the GIF animates at real-time speed.
- No `.mov`/`.gif` files anywhere (check `~/Desktop`, `ls` the project, `TMPDIR`).

- [ ] **Step 3: Verify the Frame Rate menu**

Open the menu bar item → Frame Rate → pick 30 fps (checkmark moves). Record again → the new GIF is visibly smoother / has more frames. Re-open menu: 30 fps stays checked (persisted).

- [ ] **Step 4: Verify the duration cap**

Start a recording and do nothing for just over 60s.
Expected: it auto-stops at ~60s and copies the GIF ("Copied ✓").

- [ ] **Step 5: Run the full unit suite**

Run: `swift test`
Expected: all tests pass (Config, GifEncoder, Clipboard, RegionRecorder conversion).

- [ ] **Step 6: Commit**

```bash
git add Sources/PoofCore/AppDelegate.swift
git commit -m "feat: wire full record->GIF->clipboard flow, fps menu, esc-stop, duration cap"
```

---

### Task 9: Install script, LaunchAgent, README

**Files:**
- Create: `install.sh`
- Create: `README.md`

**Interfaces:**
- Consumes: `build.sh`, `Poof.app`.
- Produces: `install.sh` (build + install to `/Applications` + LaunchAgent load), `README.md`.

- [ ] **Step 1: Write `install.sh`**

`install.sh`:

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

DEST="/Applications/Poof.app"
echo "Installing to $DEST..."
rm -rf "$DEST"
cp -R "Poof.app" "$DEST"

PLIST="$HOME/Library/LaunchAgents/com.poof.recorder.plist"
echo "Writing LaunchAgent $PLIST..."
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.poof.recorder</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/Poof.app/Contents/MacOS/poof</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>$HOME/Library/Logs/poof.log</string>
    <key>StandardErrorPath</key><string>$HOME/Library/Logs/poof.log</string>
</dict>
</plist>
EOF

echo "Loading LaunchAgent..."
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "Installed. Poof is running (menu bar). Grant Screen Recording on first ⌘⇧2 if prompted."
```

- [ ] **Step 2: Write `README.md`**

`README.md`:

```markdown
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
```

- [ ] **Step 3: Run install and verify autostart**

Run:
```bash
chmod +x install.sh && ./install.sh
launchctl list | grep com.poof.recorder
```
Expected: the LaunchAgent is listed; the menu-bar icon is present; ⌘⇧2 works from `/Applications/Poof.app`.

- [ ] **Step 4: Commit**

```bash
git add install.sh README.md
git commit -m "feat: install script, LaunchAgent, README"
```

---

## Self-Review

**Spec coverage:**
- ⌘⇧2 hotkey → Task 4 (Carbon), wired Task 8. ✓
- Dim overlay + crosshair + clear selection → Task 6. ✓
- Auto-record on mouse-up → Task 8 `beginRecording`. ✓
- Direct in-memory GIF (no .mov/.gif files) → Task 2 + Task 8 (never writes a file). ✓
- Esc stops → Task 8 (Esc Carbon hotkey during recording). ✓
- Clipboard only → Task 3 + Task 8. ✓
- Screen Recording only permission → Carbon hotkeys (Task 4), no NSEvent monitors. ✓
- Timestamp-based frame delays → Task 7 `stream(_:didOutputSampleBuffer:of:)`. ✓
- Frame Rate menu (persisted) → Task 8 `buildMenu`/`setFPS` + Config (Task 1). ✓
- maxWidth scaling / maxDuration cap / dimAlpha → Task 7 `convert`, Task 8 `capTimer`, Task 6 draw. ✓
- Menu-bar agent app, LaunchAgent autostart → Task 1 (LSUIElement), Task 9. ✓
- Error handling (no permission, tiny selection, clamp, cap) → Task 6 (tiny selection), Task 7/8 (permission/error), Task 8 (cap). ✓
- Unit tests for GifEncoder / Clipboard / Config / conversion → Tasks 1,2,3,7. ✓

**Placeholder scan:** No TBD/TODO; every code step has complete code; manual-verify steps state exact expected observations. ✓

**Type consistency:** `Config.fps`, `GifEncoder.append/finalize/count`, `Clipboard.gifType/copyGIF`, `HotkeyManager.register/unregister`, `SelectionOverlay.begin/enterRecordingMode/end`, `RegionRecorder.convert/makeStreamRect/display/start/stop` are used with matching signatures across Tasks 4–9. ✓

**Note on edge clamping:** the spec mentions clamping selection to display bounds. In practice the overlay view's bounds equal the screen, so a drag cannot exceed the display; explicit clamping is therefore unnecessary and omitted (documented here rather than adding dead code).
