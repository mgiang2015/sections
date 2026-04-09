import Foundation
import AVFoundation

/// Stateless helpers for working with audio files via AVFoundation.
enum AudioFileService {

    /// Returns the duration in seconds of the MP3 at the given URL.
    /// Uses the modern async load(.duration) API (replaces deprecated asset.duration).
    /// Returns nil if the file cannot be read or duration is invalid.
    static func duration(of url: URL) async -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        guard duration.isValid, !duration.isIndefinite else { return nil }
        return CMTimeGetSeconds(duration)
    }
}
