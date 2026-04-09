import Foundation

// MARK: - Export DTOs
// These Codable structs define the JSON schema for export/import.
// They are intentionally separate from the SwiftData models.

/// Top-level export envelope for one audio file's sections.
struct AudioFileExport: Codable {
    /// The filename used for import matching validation.
    let filename: String
    /// All sections for this file.
    let sections: [SectionExport]
}

/// Portable representation of a single AudioSection.
struct SectionExport: Codable {
    let name: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let lastPlayed: Date
    let playbackMode: PlaybackMode

    // MARK: Init from model

    init(from section: AudioSection) {
        self.name = section.name
        self.startTime = section.startTime
        self.endTime = section.endTime
        self.lastPlayed = section.lastPlayed
        self.playbackMode = section.playbackMode
    }

    // MARK: Convert back to model

    /// Creates a new AudioSection model from this DTO.
    func toSection() -> AudioSection {
        let s = AudioSection(
            name: name,
            startTime: startTime,
            endTime: endTime,
            playbackMode: playbackMode
        )
        s.lastPlayed = lastPlayed
        return s
    }
}
