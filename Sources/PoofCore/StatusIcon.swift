import AppKit

/// The menu-bar glyph: a small puff of smoke — a "poof". Evokes the app's whole
/// idea (select a region, it vanishes into the clipboard). Drawn as a template
/// image so the menu bar tints it correctly in light and dark.
public enum StatusIcon {
    public static func image() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setFill()

            // Cloud body: overlapping circles union into a lumpy puff.
            let puff = NSBezierPath()
            func bump(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
                puff.appendOval(in: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            bump(5.2, 7.0, 3.0)
            bump(8.4, 5.9, 3.3)
            bump(8.9, 8.2, 3.4)
            bump(11.9, 7.1, 2.9)
            puff.windingRule = .nonZero
            puff.fill()

            // Wisps drifting up-right — the "poof" dissipating.
            for (x, y, r) in [(13.4, 11.6, 1.2), (15.1, 14.1, 0.85)] as [(CGFloat, CGFloat, CGFloat)] {
                NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
