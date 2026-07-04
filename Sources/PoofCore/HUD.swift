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
