import AppKit

/// A small floating preview of the just-captured GIF that the user can DRAG
/// straight into any app or web chat. Dragging provides the real .gif file, so
/// browsers and AI chats (Claude, ChatGPT) receive an animated GIF - unlike
/// pasting, where the OS hands them a flattened still image.
public enum DragThumb {
    private static var window: NSWindow?

    public static func show(gifURL: URL, region: CGRect?) {
        hide()
        guard let image = NSImage(contentsOf: gifURL) else { return }

        // Fit the preview within a sensible box, preserving aspect.
        let maxW: CGFloat = 220, maxH: CGFloat = 160
        var iw = image.size.width, ih = image.size.height
        if iw <= 0 || ih <= 0 { iw = maxW; ih = maxH * 0.6 }
        let k = min(maxW / iw, maxH / ih, 1)
        let imgW = max(90, iw * k), imgH = max(56, ih * k)
        let pad: CGFloat = 10, captionH: CGFloat = 20
        let cardW = imgW + pad * 2
        let cardH = imgH + pad * 2 + captionH

        // Position centered on the captured region (clamped to that screen);
        // fall back to the main screen center.
        let center = region.map { CGPoint(x: $0.midX, y: $0.midY) }
        let screen = center.flatMap { c in NSScreen.screens.first { $0.frame.contains(c) } }
            ?? NSScreen.main
        let vf = screen?.visibleFrame ?? .zero
        var origin = NSPoint(x: (center?.x ?? vf.midX) - cardW / 2,
                             y: (center?.y ?? vf.midY) - cardH / 2)
        origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - cardW - 8)
        origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - cardH - 8)

        let win = NSWindow(contentRect: NSRect(origin: origin, size: NSSize(width: cardW, height: cardH)),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .screenSaver
        win.hasShadow = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = DragThumbView(frame: NSRect(origin: .zero, size: NSSize(width: cardW, height: cardH)))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(white: 0.11, alpha: 0.94).cgColor
        view.layer?.cornerRadius = 14
        view.gifURL = gifURL

        let iv = NSImageView(frame: NSRect(x: pad, y: pad + captionH, width: imgW, height: imgH))
        iv.image = image
        iv.animates = true
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.wantsLayer = true
        iv.layer?.cornerRadius = 8
        iv.layer?.masksToBounds = true
        view.addSubview(iv)
        view.preview = iv

        let caption = NSTextField(labelWithString: "Copied ✓   drag me into your chat")
        caption.font = .systemFont(ofSize: 11, weight: .medium)
        caption.textColor = .white
        caption.alignment = .center
        caption.frame = NSRect(x: 0, y: 5, width: cardW, height: 15)
        view.addSubview(caption)

        view.onDismiss = { hide() }
        win.contentView = view
        win.orderFrontRegardless()
        window = win
        view.scheduleAutoDismiss()
    }

    static func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

private final class DragThumbView: NSView, NSDraggingSource {
    var gifURL: URL?
    weak var preview: NSImageView?
    var onDismiss: (() -> Void)?
    private var dismissTimer: Timer?

    // All clicks target this view (the drag source), not the image subview.
    override func hitTest(_ point: NSPoint) -> NSView? {
        return bounds.contains(convert(point, from: superview)) ? self : nil
    }

    func scheduleAutoDismiss() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 9, repeats: false) { [weak self] _ in
            self?.fadeAndDismiss()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let url = gifURL else { return }
        dismissTimer?.invalidate()
        dismissTimer = nil
        // Drag the real file URL. Browsers and AI chats accept dragged files
        // (they land in the drop's file list) and attach the animated .gif.
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let frame = preview?.frame ?? bounds
        item.setDraggingFrame(frame, contents: preview?.image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.fadeAndDismiss() }
    }

    private func fadeAndDismiss() {
        guard let win = window else { onDismiss?(); return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in self?.onDismiss?() })
    }
}
