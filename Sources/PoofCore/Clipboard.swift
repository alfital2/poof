import AppKit

public enum Clipboard {
    public static let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")

    /// Puts the GIF on the clipboard both as raw data AND as a file reference.
    /// The file reference is what makes most apps (Notes, Messages, Mail, Slack)
    /// paste the GIF *animated* - pasting raw GIF data alone is flattened to a
    /// single still frame by many receivers.
    /// Returns the temp GIF file URL (for the draggable thumbnail), or nil if
    /// the file could not be written.
    @discardableResult
    public static func copyGIF(_ data: Data) -> URL? {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setData(data, forType: gifType)
        let url = writeTempGIF(data)
        if let url {
            item.setString(url.absoluteString, forType: .fileURL)
        }
        pasteboard.writeObjects([item])
        return url
    }

    private static func cacheDir() -> URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("poof", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes the GIF to a private cache file and returns its URL. Old poof GIFs
    /// are removed first, so only the current clipboard GIF ever lingers on disk.
    private static func writeTempGIF(_ data: Data) -> URL? {
        guard let dir = cacheDir() else { return nil }
        if let existing = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in existing where file.pathExtension == "gif" {
                try? FileManager.default.removeItem(at: file)
            }
        }
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        let url = dir.appendingPathComponent("poof-\(stamp).gif")
        do {
            try data.write(to: url)
            return url
        } catch {
            NSLog("Poof: temp GIF write failed: \(error)")
            return nil
        }
    }
}
