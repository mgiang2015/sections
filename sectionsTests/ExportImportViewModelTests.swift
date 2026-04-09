import XCTest
import SwiftData
@testable import sections

@MainActor
final class ExportImportViewModelTests: XCTestCase {

    var sut: ExportImportViewModel!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = ExportImportViewModel()

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: AudioFile.self, AudioSection.self, configurations: config)
        modelContext = ModelContext(modelContainer)

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        sut = nil
        modelContext = nil
        modelContainer = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// Creates an AudioFile with the given sections already attached.
    private func makeAudioFile(filename: String, sections: [AudioSection] = []) -> AudioFile {
        let file = AudioFile(filename: filename, localPath: filename)
        file.sections = sections
        modelContext.insert(file)
        return file
    }

    /// Writes a JSON payload to a temp file and returns its URL.
    private func writeJSON(_ payload: AudioFileExport) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let url = tempDir.appendingPathComponent("\(payload.filename)_sections.json")
        try data.write(to: url)
        return url
    }

    // MARK: - exportSections

    func test_export_createsFileInTempDirectory() async throws {
        let file = makeAudioFile(filename: "track.mp3")

        let url = try await MainActor.run {
            try sut.exportSections(for: file)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_export_filenameMatchesBRDFormat() async throws {
        // BRD §4.6: export filename = <audioFilename>_sections.json
        let file = makeAudioFile(filename: "my_track.mp3")

        let url = try await MainActor.run {
            try sut.exportSections(for: file)
        }

        XCTAssertEqual(url.lastPathComponent, "my_track_sections.json")
    }

    func test_export_jsonContainsCorrectFilename() async throws {
        let file = makeAudioFile(filename: "song.mp3")

        let url = try await MainActor.run {
            try sut.exportSections(for: file)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(AudioFileExport.self, from: data)
        XCTAssertEqual(payload.filename, "song.mp3")
    }

    func test_export_includesAllSections() async throws {
        let s1 = AudioSection(name: "Intro", startTime: 0, endTime: 15)
        let s2 = AudioSection(name: "Verse", startTime: 15, endTime: 60)
        let file = makeAudioFile(filename: "song.mp3", sections: [s1, s2])

        let url = try await MainActor.run {
            try sut.exportSections(for: file)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(AudioFileExport.self, from: data)
        XCTAssertEqual(payload.sections.count, 2)
    }

    func test_export_emptySections_producesValidJSON() async throws {
        let file = makeAudioFile(filename: "empty.mp3", sections: [])

        let url = try await MainActor.run {
            try sut.exportSections(for: file)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(AudioFileExport.self, from: data)
        XCTAssertTrue(payload.sections.isEmpty)
    }

    // MARK: - importSections — validation

    func test_import_filenameMismatch_throwsError() async throws {
        let file = makeAudioFile(filename: "correct.mp3")
        let wrongPayload = AudioFileExport(filename: "wrong.mp3", sections: [])
        let url = try writeJSON(wrongPayload)

        try await MainActor.run {
            XCTAssertThrowsError(
                try sut.importSections(from: url, into: file, context: modelContext)
            ) { error in
                guard case ImportError.filenameMismatch(let expected, let got) = error else {
                    return XCTFail("Expected .filenameMismatch, got \(error)")
                }
                XCTAssertEqual(expected, "correct.mp3")
                XCTAssertEqual(got, "wrong.mp3")
            }
        }
    }

    func test_import_invalidJSON_throwsInvalidJSONError() async throws {
        let file = makeAudioFile(filename: "track.mp3")
        let url = tempDir.appendingPathComponent("bad.json")
        try "not valid json at all }{".write(to: url, atomically: true, encoding: .utf8)

        try await MainActor.run {
            XCTAssertThrowsError(
                try sut.importSections(from: url, into: file, context: modelContext)
            ) { error in
                guard case ImportError.invalidJSON = error else {
                    return XCTFail("Expected .invalidJSON, got \(error)")
                }
            }
        }
    }

    func test_import_missingFile_throwsWriteFailedError() async throws {
        let file = makeAudioFile(filename: "track.mp3")
        let nonExistentURL = tempDir.appendingPathComponent("ghost.json")

        try await MainActor.run {
            XCTAssertThrowsError(
                try sut.importSections(from: nonExistentURL, into: file, context: modelContext)
            ) { error in
                guard case ImportError.writeFailed = error else {
                    return XCTFail("Expected .writeFailed, got \(error)")
                }
            }
        }
    }

    // MARK: - importSections — merge logic

    func test_import_validPayload_addsSections() async throws {
        let file = makeAudioFile(filename: "track.mp3")
        let section = AudioSection(name: "Chorus", startTime: 60, endTime: 90)
        let payload = AudioFileExport(filename: "track.mp3", sections: [SectionExport(from: section)])
        let url = try writeJSON(payload)

        try await MainActor.run {
            try sut.importSections(from: url, into: file, context: modelContext)
        }

        XCTAssertEqual(file.sections.count, 1)
        XCTAssertEqual(file.sections[0].name, "Chorus")
    }

    func test_import_duplicate_skipsExistingSection() async throws {
        // BRD §4.7: merge — skip duplicates by name + startTime + endTime
        let existing = AudioSection(name: "Chorus", startTime: 60, endTime: 90)
        let file = makeAudioFile(filename: "track.mp3", sections: [existing])

        // Import the exact same section again
        let duplicate = AudioSection(name: "Chorus", startTime: 60, endTime: 90)
        let payload = AudioFileExport(filename: "track.mp3", sections: [SectionExport(from: duplicate)])
        let url = try writeJSON(payload)

        try await MainActor.run {
            try sut.importSections(from: url, into: file, context: modelContext)
        }

        // Should still only have 1 section — duplicate was skipped
        XCTAssertEqual(file.sections.count, 1)
    }

    func test_import_sameNameDifferentTimestamps_isNotADuplicate() async throws {
        // Same name but different times = a different section, should be added
        let existing = AudioSection(name: "Chorus", startTime: 60, endTime: 90)
        let file = makeAudioFile(filename: "track.mp3", sections: [existing])

        let different = AudioSection(name: "Chorus", startTime: 90, endTime: 120)
        let payload = AudioFileExport(filename: "track.mp3", sections: [SectionExport(from: different)])
        let url = try writeJSON(payload)

        try await MainActor.run {
            try sut.importSections(from: url, into: file, context: modelContext)
        }

        XCTAssertEqual(file.sections.count, 2)
    }

    func test_import_newAndDuplicateMixed_onlyAddsNew() async throws {
        let existing = AudioSection(name: "Verse", startTime: 0, endTime: 30)
        let file = makeAudioFile(filename: "track.mp3", sections: [existing])

        let duplicate = AudioSection(name: "Verse", startTime: 0, endTime: 30)
        let newSection = AudioSection(name: "Chorus", startTime: 30, endTime: 60)
        let payload = AudioFileExport(
            filename: "track.mp3",
            sections: [SectionExport(from: duplicate), SectionExport(from: newSection)]
        )
        let url = try writeJSON(payload)

        try await MainActor.run {
            try sut.importSections(from: url, into: file, context: modelContext)
        }

        XCTAssertEqual(file.sections.count, 2)
        XCTAssertTrue(file.sections.contains(where: { $0.name == "Chorus" }))
    }

    func test_import_preservesLastPlayedFromJSON() async throws {
        let file = makeAudioFile(filename: "track.mp3")
        let section = AudioSection(name: "Intro", startTime: 0, endTime: 15)
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        section.lastPlayed = fixedDate

        let payload = AudioFileExport(filename: "track.mp3", sections: [SectionExport(from: section)])
        let url = try writeJSON(payload)

        try await MainActor.run {
            try sut.importSections(from: url, into: file, context: modelContext)
        }

        XCTAssertEqual(file.sections[0].lastPlayed.timeIntervalSince1970,
                       fixedDate.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - ImportError — localised descriptions

    func test_error_invalidJSON_hasDescription() {
        XCTAssertFalse(ImportError.invalidJSON.errorDescription?.isEmpty ?? true)
    }

    func test_error_filenameMismatch_mentionsBothFilenames() {
        let error = ImportError.filenameMismatch(expected: "correct.mp3", got: "wrong.mp3")
        XCTAssertTrue(error.errorDescription?.contains("correct.mp3") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("wrong.mp3") ?? false)
    }

    // MARK: - Export → Import round-trip

    func test_roundTrip_exportThenImport_restoresAllSections() async throws {
        // Export from source file
        let s1 = AudioSection(name: "Intro", startTime: 0, endTime: 15, playbackMode: .loop)
        let s2 = AudioSection(name: "Chorus", startTime: 60, endTime: 90, playbackMode: .playOnce)
        let source = makeAudioFile(filename: "track.mp3", sections: [s1, s2])

        let exportURL = try await MainActor.run {
            try sut.exportSections(for: source)
        }

        // Import into a fresh file with the same filename
        let target = makeAudioFile(filename: "track.mp3", sections: [])

        try await MainActor.run {
            try sut.importSections(from: exportURL, into: target, context: modelContext)
        }

        XCTAssertEqual(target.sections.count, 2)
        XCTAssertTrue(target.sections.contains(where: { $0.name == "Intro" && $0.startTime == 0 }))
        XCTAssertTrue(target.sections.contains(where: { $0.name == "Chorus" && $0.startTime == 60 }))
    }
}
