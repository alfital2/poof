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
