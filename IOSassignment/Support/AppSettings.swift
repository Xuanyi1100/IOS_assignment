import Foundation

/// User preferences backed by UserDefaults, shared by Settings and Chat.
///
/// Kept as a tiny static facade so view controllers don't each reinvent keys.
enum AppSettings {
    private enum Key {
        static let streaming = "settings.streaming"
        static let temperature = "settings.temperature"
        static let engineIndex = "settings.engineIndex"
        static let maxWords = "settings.maxWords"
    }

    private static let defaults = UserDefaults.standard

    /// Show the reply token by token (true) or all at once (false).
    static var streamingEnabled: Bool {
        get { defaults.object(forKey: Key.streaming) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.streaming) }
    }

    /// Sampling temperature, 0...1. Ignored by MockEngine; used by real engines in Phase 3.
    static var temperature: Float {
        get { defaults.object(forKey: Key.temperature) as? Float ?? 0.7 }
        set { defaults.set(newValue, forKey: Key.temperature) }
    }

    /// Selected engine in the Settings segmented control (0 = Mock, 1 = On-device).
    static var engineIndex: Int {
        get { defaults.integer(forKey: Key.engineIndex) }
        set { defaults.set(newValue, forKey: Key.engineIndex) }
    }

    /// Upper bound on reply length, in words (Settings stepper).
    static var maxWords: Int {
        get {
            let stored = defaults.integer(forKey: Key.maxWords)
            return stored > 0 ? stored : 60
        }
        set { defaults.set(newValue, forKey: Key.maxWords) }
    }
}
