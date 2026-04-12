import Foundation

/// Controls the sort order of the audio file library.
enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case recentlyAdded = "recentlyAdded"
    case alphabetical  = "alphabetical"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .recentlyAdded: return "Most Recently Added"
        case .alphabetical:  return "Alphabetical"
        }
    }

    var systemImage: String {
        switch self {
        case .recentlyAdded: return "clock"
        case .alphabetical:  return "textformat.abc"
        }
    }

    /// Sorts an array of AudioFiles according to this order.
    func sort(_ files: [AudioFile]) -> [AudioFile] {
        switch self {
        case .recentlyAdded:
            return files.sorted { $0.dateAdded > $1.dateAdded }
        case .alphabetical:
            return files.sorted {
                $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending
            }
        }
    }
}
