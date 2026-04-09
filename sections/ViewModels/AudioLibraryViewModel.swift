import Foundation
import SwiftData

enum AudioImportError: LocalizedError {
    case notMP3
    case duplicateFilename(String)
    case copyFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notMP3:
            return "Only MP3 files are supported. Please choose an .mp3 file."
        case .duplicateFilename(let name):
            return "A file named \"\(name)\" already exists in your library."
        case .copyFailed(let underlying):
            return "Failed to copy file: \(underlying.localizedDescription)"
        }
    }
}

final class AudioLibraryViewModel {

    // MARK: - Import

    /// Copies the selected file into the app sandbox and inserts an AudioFile record.
    /// Throws `AudioImportError` on validation or copy failure.
    @MainActor
    func importAudioFile(from url: URL, existingFiles: [AudioFile], context: ModelContext) throws {
        // Validate extension
        guard url.pathExtension.lowercased() == "mp3" else {
            throw AudioImportError.notMP3
        }

        let filename = url.lastPathComponent

        // Duplicate check — prompt handled at the call site; here we throw for simplicity
        if existingFiles.contains(where: { $0.filename == filename }) {
            throw AudioImportError.duplicateFilename(filename)
        }

        // Security-scoped access for Files app URLs
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destination = documents.appendingPathComponent(filename)

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            throw AudioImportError.copyFailed(error)
        }

        let audioFile = AudioFile(filename: filename, localPath: filename)
        context.insert(audioFile)
    }

    // MARK: - Delete

    /// Removes the audio file from the sandbox and deletes the SwiftData record (cascade deletes sections).
    @MainActor
    func deleteAudioFile(_ file: AudioFile, context: ModelContext) {
        // Remove from sandbox
        try? FileManager.default.removeItem(at: file.resolvedURL)
        context.delete(file)
    }
}
