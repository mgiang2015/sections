import XCTest
import SwiftData
@testable import sections

@MainActor
final class AudioLibraryViewModelTests: XCTestCase {

    var sut: AudioLibraryViewModel!
    var tempDir: URL!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = AudioLibraryViewModel()

        // In-memory SwiftData container for tests
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: AudioFile.self, AudioSection.self, configurations: config)
        modelContext = ModelContext(modelContainer)

        // Isolated temp directory for each test
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

    private func makeFakeMP3(named filename: String) throws -> URL {
        let url = tempDir.appendingPathComponent(filename)
        try Data("fake mp3".utf8).write(to: url)
        return url
    }

    // MARK: - importAudioFile — validation

    func test_import_nonMP3_throwsNotMP3Error() throws {
        let url = tempDir.appendingPathComponent("track.wav")
        try Data("fake".utf8).write(to: url)

        XCTAssertThrowsError(
            try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        ) { error in
            guard case AudioImportError.notMP3 = error else {
                return XCTFail("Expected .notMP3, got \(error)")
            }
        }
    }

    func test_import_validMP3_insertsAudioFile() throws {
        let url = try makeFakeMP3(named: "song.mp3")

        try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)

        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "song.mp3")
    }

    func test_import_validMP3_setsLocalPathToFilename() throws {
        let url = try makeFakeMP3(named: "track.mp3")

        try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)

        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files[0].localPath, "track.mp3")
    }

    func test_import_duplicateFilename_throwsDuplicateError() throws {
        let url = try makeFakeMP3(named: "song.mp3")
        let existing = AudioFile(filename: "song.mp3", localPath: "song.mp3")

        XCTAssertThrowsError(
            try sut.importAudioFile(from: url, existingFiles: [existing], context: modelContext)
        ) { error in
            guard case AudioImportError.duplicateFilename(let name) = error else {
                return XCTFail("Expected .duplicateFilename, got \(error)")
            }
            XCTAssertEqual(name, "song.mp3")
        }
    }

    func test_import_differentFilename_doesNotThrowDuplicateError() throws {
        let url = try makeFakeMP3(named: "new_track.mp3")
        let existing = AudioFile(filename: "old_track.mp3", localPath: "old_track.mp3")

        try sut.importAudioFile(from: url, existingFiles: [existing], context: modelContext)

        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files.count, 1)
    }

    func test_import_caseInsensitiveExtension_mp3uppercase_succeeds() throws {
        let url = tempDir.appendingPathComponent("track.MP3")
        try Data("fake".utf8).write(to: url)

        try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)

        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files.count, 1)
    }

    // MARK: - AudioImportError — localised descriptions

    func test_error_notMP3_hasDescription() {
        let error = AudioImportError.notMP3
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func test_error_duplicateFilename_includesFilename() {
        let error = AudioImportError.duplicateFilename("my_track.mp3")
        XCTAssertTrue(error.errorDescription?.contains("my_track.mp3") ?? false)
    }

    func test_error_copyFailed_includesUnderlyingDescription() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "disk full"])
        let error = AudioImportError.copyFailed(underlying)
        XCTAssertTrue(error.errorDescription?.contains("disk full") ?? false)
    }

    // MARK: - deleteAudioFile

    func test_delete_removesRecordFromContext() throws {
        let file = AudioFile(filename: "track.mp3", localPath: "track.mp3")
        modelContext.insert(file)

        sut.deleteAudioFile(file, context: modelContext)

        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertTrue(files.isEmpty)
    }
}
