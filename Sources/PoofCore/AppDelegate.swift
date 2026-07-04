import AppKit
import Carbon.HIToolbox

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let hotkeys = HotkeyManager()
    private let overlay = SelectionOverlay()

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        hotkeys.register(keyCode: 0x13, modifiers: UInt32(cmdKey | shiftKey)) { [self] in
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
