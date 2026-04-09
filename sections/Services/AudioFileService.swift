import Foundation
import AVFoundation

/// Stateless helpers for working with audio files via AVFoundation.
enum AudioFileService {

    /// Returns the duration in seconds of the MP3 at the given URL.
    /// Returns nil if the file cannot be read.
    static func duration(of url: URL) -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        let duration = asset.duration
        guard duration.isValid, !duration.isIndefinite else { return nil }
        return CMTimeGetSeconds(duration)
    }
}
