import Foundation
import SwiftData

enum ImportError: LocalizedError {
    case invalidJSON
    case filenameMismatch(expected: String, got: String)
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "The selected file is not a valid Sections export file."
        case .filenameMismatch(let expected, let got):
            return "This export belongs to \"\(got)\" but you are viewing \"\(expected)\". Import aborted."
        case .writeFailed(let error):
            return "Failed to write export file: \(error.localizedDescription)"
        }
    }
}

final class ExportImportViewModel {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Export

    /// Serialises all sections for `audioFile` to a temp JSON file and returns its URL.
    /// The file is named `<audioFilename>_sections.json` per BRD §4.6.
    @MainActor
    func exportSections(for audioFile: AudioFile) throws -> URL {
        let payload = AudioFileExport(
            filename: audioFile.filename,
            sections: audioFile.sections.map { SectionExport(from: $0) }
        )

        let data: Data
        do {
            data = try encoder.encode(payload)
        } catch {
            throw ImportError.writeFailed(error)
        }

        let exportName = audioFile.filename
            .replacingOccurrences(of: ".mp3", with: "")
            + "_sections.json"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(exportName)
        do {
            try data.write(to: tempURL, options: .atomic)
        } catch {
            throw ImportError.writeFailed(error)
        }

        return tempURL
    }

    // MARK: - Import

    /// Reads a JSON export file, validates the filename matches `audioFile`, then merges sections.
    /// Merge strategy: add new sections; skip duplicates matched by name + startTime + endTime.
    @MainActor
    func importSections(from url: URL, into audioFile: AudioFile, context: ModelContext) throws {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.writeFailed(error)
        }

        let payload: AudioFileExport
        do {
            payload = try decoder.decode(AudioFileExport.self, from: data)
        } catch {
            throw ImportError.invalidJSON
        }

        // Filename mismatch check (BRD §4.7)
        guard payload.filename == audioFile.filename else {
            throw ImportError.filenameMismatch(expected: audioFile.filename, got: payload.filename)
        }

        // Merge: skip duplicates by (name, startTime, endTime)
        let existing = Set(audioFile.sections.map { "\($0.name)|\($0.startTime)|\($0.endTime)" })

        for dto in payload.sections {
            let key = "\(dto.name)|\(dto.startTime)|\(dto.endTime)"
            guard !existing.contains(key) else { continue }
            let section = dto.toSection()
            section.audioFile = audioFile
            context.insert(section)
        }
    }
}
