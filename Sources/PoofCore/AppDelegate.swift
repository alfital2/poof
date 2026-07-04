import AppKit
import Carbon.HIToolbox

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let hotkeys = HotkeyManager()
    private let overlay = SelectionOverlay()
    private var recorder: RegionRecorder?
    private var frameProbeCount = 0

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        hotkeys.register(keyCode: 0x13, modifiers: UInt32(cmdKey | shiftKey)) { [self] in
            self.overlay.begin(onCommit: { rect, screen in
                NSLog("Poof: committed rect \(rect) on \(screen.localizedName)")
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
            }, onCancel: {
                self.overlay.end()
            })
        }
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
