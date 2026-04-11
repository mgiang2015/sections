import Foundation
import SwiftData
internal import UniformTypeIdentifiers

// MARK: - Supported formats

extension AudioLibraryViewModel {
    /// File extensions accepted by the app, lowercased.
    static let supportedExtensions: Set<String> = ["mp3", "wav", "m4a"]

    /// UTTypes for the Files app document picker.
    static let supportedContentTypes: [UTType] = [.mp3, .wav, .mpeg4Audio]
}

// MARK: - Error

enum AudioImportError: LocalizedError {
    case unsupportedFormat(String)
    case duplicateFilename(String)
    case copyFailed(Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            let supported = AudioLibraryViewModel.supportedExtensions
                .sorted()
                .joined(separator: ", ")
            return "\"\(ext)\" is not supported. Please choose an \(supported) file."
        case .duplicateFilename(let name):
            return "A file named \"\(name)\" already exists in your library."
        case .copyFailed(let underlying):
            return "Failed to copy file: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - ViewModel

final class AudioLibraryViewModel {

    // MARK: - Import

    /// Copies the selected file into the app sandbox and inserts an AudioFile record.
    /// Throws `AudioImportError` on validation or copy failure.
    @MainActor
    func importAudioFile(from url: URL, existingFiles: [AudioFile], context: ModelContext) throws {
        let ext = url.pathExtension.lowercased()

        guard AudioLibraryViewModel.supportedExtensions.contains(ext) else {
            throw AudioImportError.unsupportedFormat(ext)
        }

        let filename = url.lastPathComponent

        if existingFiles.contains(where: { $0.filename == filename }) {
            throw AudioImportError.duplicateFilename(filename)
        }

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
        try? FileManager.default.removeItem(at: file.resolvedURL)
        context.delete(file)
    }
}
