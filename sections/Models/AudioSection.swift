import Foundation
import SwiftData

// MARK: - Playback Mode

enum PlaybackMode: String, Codable, CaseIterable {
    case loop      = "loop"
    case playOnce  = "playOnce"

    var displayName: String {
        switch self {
        case .loop:     return "Loop"
        case .playOnce: return "Play Once"
        }
    }
}

// MARK: - AudioSection Model

/// A user-defined time range within an AudioFile.
@Model
final class AudioSection {

    // MARK: - Stored Properties

    /// Unique identifier.
    var id: UUID

    /// User-defined label (e.g. "Chorus", "Verse 1").
    var name: String

    /// Start of the section in seconds from the beginning of the audio file.
    var startTime: TimeInterval

    /// End of the section in seconds from the beginning of the audio file.
    var endTime: TimeInterval

    /// Timestamp of the most recent playback. Set to creation date on first creation.
    var lastPlayed: Date

    /// Playback behaviour when the section ends.
    var playbackMode: PlaybackMode

    // MARK: - Relationships

    /// The audio file this section belongs to.
    var audioFile: AudioFile?

    // MARK: - Init

    init(
        name: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        playbackMode: PlaybackMode = .loop
    ) {
        self.id = UUID()
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.playbackMode = playbackMode
        self.lastPlayed = Date()   // BRD: set lastPlayed to creation timestamp
    }

    // MARK: - Computed

    /// Duration of the section in seconds.
    var duration: TimeInterval {
        endTime - startTime
    }

    /// Human-readable representation of startTime (mm:ss).
    var startTimeFormatted: String {
        TimeFormatter.format(startTime)
    }

    /// Human-readable representation of endTime (mm:ss).
    var endTimeFormatted: String {
        TimeFormatter.format(endTime)
    }
}
