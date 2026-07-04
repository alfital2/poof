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
    private var isFinishing = false

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        if !Config.hideMenuBarIcon { showStatusItem() }
        hotkeys.register(keyCode: 0x13, modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.startSelection()
        }
    }

    /// Re-opening Poof while it's already running (Finder/Spotlight/`open`) brings
    /// the menu-bar icon back after it was hidden.
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if Config.hideMenuBarIcon {
            Config.hideMenuBarIcon = false
            showStatusItem()
            HUD.flash("Menu bar icon shown")
        }
        return true
    }

    // MARK: Menu bar

    private func showStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = StatusIcon.image()
        item.menu = buildMenu()
        self.statusItem = item
    }

    private func hideStatusItem() {
        if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
        statusItem = nil
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

        let launch = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin),
                                keyEquivalent: "")
        launch.target = self
        launch.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launch)

        let hide = NSMenuItem(title: "Hide Menu Bar Icon", action: #selector(hideMenuBarIconAction),
                              keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)

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

    @objc private func toggleLaunchAtLogin() {
        let ok = LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        if !ok { HUD.flash("Couldn't change Launch at Login") }
        statusItem?.menu = buildMenu() // refresh checkmark
    }

    @objc private func hideMenuBarIconAction() {
        Config.hideMenuBarIcon = true
        hideStatusItem()
        HUD.flash("Icon hidden — open Poof again to show it")
    }

    // MARK: Flow

    private func startSelection() {
        guard !isRecording, !isFinishing else { return }
        overlay.begin(onCommit: { [weak self] rect, screen in
            self?.beginRecording(rect: rect, screen: screen)
        }, onCancel: { [weak self] in
            self?.overlay.end()
        })
    }

    private func beginRecording(rect: CGRect, screen: NSScreen) {
        isRecording = true
        overlay.enterRecordingMode()
        let (sourceRect, outputSize) = RegionRecorder.makeStreamRect(globalRect: rect, screen: screen)
        let fps = Config.fps

        RegionRecorder.display(for: screen) { [weak self] display in
            guard let self else { return }
            guard let display else {
                self.isRecording = false
                self.overlay.end()
                HUD.flash("No display found")
                return
            }
            let encoder = GifEncoder()
            let recorder = RegionRecorder()
            self.encoder = encoder
            self.recorder = recorder

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
        isFinishing = true
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
                    self.isFinishing = false
                }
            }
        }
    }

    private func abortRecording(message: String) {
        guard isRecording else { return }
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
