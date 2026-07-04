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
}
