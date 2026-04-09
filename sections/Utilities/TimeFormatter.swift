import Foundation

/// Utility for converting between TimeInterval (seconds) and "mm:ss" strings.
enum TimeFormatter {

    /// Formats a TimeInterval as "m:ss" (e.g. 62.0 → "1:02").
    static func format(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Parses a "mm:ss" or "m:ss" string into a TimeInterval in seconds.
    /// Returns nil if the string cannot be parsed.
    static func parse(_ string: String) -> TimeInterval? {
        let parts = string.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2,
              let minutes = Int(parts[0]),
              let seconds = Int(parts[1]),
              minutes >= 0,
              seconds >= 0, seconds < 60
        else { return nil }
        return TimeInterval(minutes * 60 + seconds)
    }
}
