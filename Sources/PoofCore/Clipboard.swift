import AppKit

public enum Clipboard {
    public static let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")

    public static func copyGIF(_ data: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: gifType)
    }
}
