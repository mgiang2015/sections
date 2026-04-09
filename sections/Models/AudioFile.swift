import Foundation
import SwiftData

/// Represents an imported MP3 audio file stored in the app sandbox.
@Model
final class AudioFile {

    // MARK: - Stored Properties

    /// Unique identifier for this audio file record.
    var id: UUID

    /// Original filename (e.g. "my_track.mp3").
    /// Used as the canonical identifier for export/import matching.
    var filename: String

    /// Relative path to the copied file inside the app's Documents directory.
    /// Use `AudioFile.resolvedURL` to get the full absolute URL at runtime.
    var localPath: String

    /// Date the file was imported into the app library.
    var dateAdded: Date

    // MARK: - Relationships

    /// All sections defined for this audio file.
    @Relationship(deleteRule: .cascade, inverse: \AudioSection.audioFile)
    var sections: [AudioSection] = []

    // MARK: - Init

    init(filename: String, localPath: String) {
        self.id = UUID()
        self.filename = filename
        self.localPath = localPath
        self.dateAdded = Date()
    }

    // MARK: - Computed

    /// Resolves the stored relative path to an absolute URL in the app sandbox.
    var resolvedURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent(localPath)
    }

    /// Returns sections sorted by lastPlayed descending (most recently played first).
    var sectionsSortedByLastPlayed: [AudioSection] {
        sections.sorted { $0.lastPlayed > $1.lastPlayed }
    }
}
