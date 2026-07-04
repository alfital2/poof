import AppKit

public enum Clipboard {
    public static let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")

    /// Puts the GIF on the clipboard as raw data plus, if provided, a file
    /// reference. The file reference helps native apps that accept a pasted
    /// file paste it animated; the raw data covers everything else.
    public static func copyGIF(_ data: Data, fileURL: URL? = nil) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setData(data, forType: gifType)
        if let fileURL {
            item.setString(fileURL.absoluteString, forType: .fileURL)
        }
        pasteboard.writeObjects([item])
    }

    /// Writes the GIF to a private cache file and returns its URL (used as the
    /// drag source and the clipboard file reference). Old poof GIFs are removed
    /// first, so only the current capture lingers on disk.
    @discardableResult
    public static func stageGIF(_ data: Data) -> URL? {
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
            NSLog("Poof: staging GIF failed: \(error)")
            return nil
        }
    }

    private static func cacheDir() -> URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("poof", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
