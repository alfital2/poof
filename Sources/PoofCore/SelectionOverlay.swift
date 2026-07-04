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

    /// 0…1 breathing value driving the recording-frame glow.
    var pulse: CGFloat = 1
    func setPulse(_ p: CGFloat) {
        pulse = p
        if let sel = committedRect { setNeedsDisplay(sel.insetBy(dx: -30, dy: -30)) }
    }

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
        let cp = NSPoint(x: min(max(p.x, 0), bounds.width), y: min(max(p.y, 0), bounds.height))
        currentRect = NSRect(x: min(start.x, cp.x), y: min(start.y, cp.y),
                             width: abs(cp.x - start.x), height: abs(cp.y - start.y))
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
            guard let sel = committedRect else { break }
            // Sharp rectangle (truthfully matches the captured region), sitting
            // just outside it, in a vivid coral-red with a soft breathing glow.
            // The overlay window is excluded from the SCStream, so neither the
            // line nor the glow ever appears in the GIF.
            let red = NSColor(srgbRed: 1.0, green: 0.27, blue: 0.22, alpha: 1.0)
            let frameRect = sel.insetBy(dx: -1.5, dy: -1.5)

            guard let ctx = NSGraphicsContext.current else { break }
            ctx.saveGraphicsState()
            let glow = NSShadow()
            glow.shadowColor = red.withAlphaComponent(0.55 + 0.40 * pulse)
            glow.shadowBlurRadius = 12 + 18 * pulse
            glow.shadowOffset = .zero
            glow.set()
            red.setStroke()
            let glowPath = NSBezierPath(rect: frameRect)
            glowPath.lineWidth = 3
            glowPath.stroke()
            ctx.restoreGraphicsState()

            // Crisp line on top (no shadow) so the edge stays sharp.
            red.setStroke()
            let crisp = NSBezierPath(rect: frameRect)
            crisp.lineWidth = 2.5
            crisp.stroke()
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
    private var pulseTimer: Timer?
    private var pulsePhase: CGFloat = 0

    public init() {}

    /// AppKit window numbers of the overlay windows — used to exclude Poof's own
    /// recording outline from the ScreenCaptureKit stream.
    public var overlayWindowNumbers: [Int] { windows.map { $0.windowNumber } }

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
                self.onCommit?(global, screen)
            }
            view.onCancel = { [weak self] in self?.cancel() }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            windows.append(window)
            views.append(view)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    public func enterRecordingMode() {
        for (window, view) in zip(windows, views) {
            view.mode = .recording
            window.ignoresMouseEvents = true
            window.makeFirstResponder(nil)
        }
        startPulse()
        // Relinquish app activation so keyboard/focus returns to the app being
        // recorded. Windows stay visible (screenSaver level) so the red
        // outline remains even though we're no longer the active app.
        NSApp.deactivate()
    }

    public func end() {
        stopPulse()
        guard !windows.isEmpty else { return }
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        views.removeAll()
    }

    // MARK: Recording-frame pulse

    private func startPulse() {
        pulseTimer?.invalidate()
        pulsePhase = 0
        // ~1.4s breathing cycle at 30fps. Runs on the main runloop, which keeps
        // firing while recording even though the app is deactivated.
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.pulsePhase += (2 * .pi) / (1.4 * 30)
            let p = (sin(self.pulsePhase) + 1) / 2   // 0…1
            for view in self.views { view.setPulse(p) }
        }
        RunLoop.main.add(timer, forMode: .common)
        pulseTimer = timer
    }

    private func stopPulse() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }

    private func cancel() {
        end()
        onCancel?()
    }
}
