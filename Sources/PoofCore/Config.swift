import Foundation

public enum Config {
    public static let maxWidth = 900
    public static let maxDuration: TimeInterval = 60
    public static let dimAlpha = 0.35
    public static let availableFPS = [10, 15, 20, 30]
    public static let defaultFPS = 15

    public static var fps: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "fps")
            return availableFPS.contains(stored) ? stored : defaultFPS
        }
        set { UserDefaults.standard.set(newValue, forKey: "fps") }
    }

    /// When true, the menu-bar icon is not shown at launch. Re-opening Poof
    /// (launching it again) clears this and restores the icon.
    public static var hideMenuBarIcon: Bool {
        get { UserDefaults.standard.bool(forKey: "hideMenuBarIcon") }
        set { UserDefaults.standard.set(newValue, forKey: "hideMenuBarIcon") }
    }

    /// Text inserted when a capture is dragged into an agent. `[PATH]` is
    /// replaced with the GIF's file path (appended if the token is absent).
    public static let defaultDragMessage = "for context, view this gif file at [PATH]"
    public static var dragMessageTemplate: String {
        get { UserDefaults.standard.string(forKey: "dragMessage") ?? defaultDragMessage }
        set { UserDefaults.standard.set(newValue, forKey: "dragMessage") }
    }

    /// Whether each capture also puts the GIF on the clipboard (so it survives a
    /// failed drag and can be pasted again). Defaults to true.
    public static var keepGifOnClipboard: Bool {
        get {
            UserDefaults.standard.object(forKey: "keepGifOnClipboard") == nil
                ? true : UserDefaults.standard.bool(forKey: "keepGifOnClipboard")
        }
        set { UserDefaults.standard.set(newValue, forKey: "keepGifOnClipboard") }
    }
}
