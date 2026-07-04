import Foundation

/// Manages "Launch at Login" by writing/removing a per-user LaunchAgent plist
/// that points at this app's own executable. Writing the plist is what makes
/// it take effect at the next login (RunAtLoad, no KeepAlive so Quit stays quit).
///
/// We deliberately do NOT `launchctl bootstrap` on enable: the plist has
/// RunAtLoad, so loading it while Poof is already running would spawn a second
/// instance. Writing the file is enough — launchd loads it at the next login.
public enum LaunchAtLogin {
    public static let label = "com.poof.recorder"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    public static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// Returns true on success; false if the file operation failed (caller may notify).
    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Bool {
        enabled ? enable() : disable()
    }

    private static func executablePath() -> String {
        Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments.first ?? ""
    }

    private static func enable() -> Bool {
        let logPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/poof.log").path
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key><string>\(label)</string>
            <key>ProgramArguments</key>
            <array><string>\(executablePath())</string></array>
            <key>RunAtLoad</key><true/>
            <key>StandardOutPath</key><string>\(logPath)</string>
            <key>StandardErrorPath</key><string>\(logPath)</string>
        </dict>
        </plist>
        """
        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try plist.write(to: plistURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            NSLog("Poof: enable Launch at Login failed: \(error)")
            return false
        }
    }

    private static func disable() -> Bool {
        // Best-effort unload in case a previous login already loaded it.
        let unload = Process()
        unload.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        unload.arguments = ["bootout", "gui/\(getuid())/\(label)"]
        try? unload.run()
        unload.waitUntilExit()

        guard FileManager.default.fileExists(atPath: plistURL.path) else { return true }
        do {
            try FileManager.default.removeItem(at: plistURL)
            return true
        } catch {
            NSLog("Poof: disable Launch at Login failed: \(error)")
            return false
        }
    }
}
