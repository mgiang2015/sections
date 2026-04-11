import XCTest
import SwiftData
@testable import sections

@MainActor
final class AudioLibraryViewModelTests: XCTestCase {

    var sut: AudioLibraryViewModel!
    var tempDir: URL!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    /// Tracks every file copied into the app's Documents sandbox so tearDown can remove them.
    var sandboxDestinations: [URL] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = AudioLibraryViewModel()
        sandboxDestinations = []

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: AudioFile.self, AudioSection.self, configurations: config)
        modelContext = ModelContext(modelContainer)

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Remove source temp dir
        try? FileManager.default.removeItem(at: tempDir)
        // Remove any files the ViewModel copied into the real Documents sandbox
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for dest in sandboxDestinations {
            try? FileManager.default.removeItem(at: documents.appendingPathComponent(dest.lastPathComponent))
        }
        sandboxDestinations = []
        sut = nil
        modelContext = nil
        modelContainer = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// Creates a fake audio file in the isolated temp directory with the exact filename given.
    /// The file is registered for sandbox cleanup in tearDown.
    private func makeFakeFile(named filename: String) throws -> URL {
        let url = tempDir.appendingPathComponent(filename)
        try Data("fake audio".utf8).write(to: url)
        sandboxDestinations.append(url)
        return url
    }

    // MARK: - supportedExtensions

    func test_supportedExtensions_containsMP3() {
        XCTAssertTrue(AudioLibraryViewModel.supportedExtensions.contains("mp3"))
    }

    func test_supportedExtensions_containsWAV() {
        XCTAssertTrue(AudioLibraryViewModel.supportedExtensions.contains("wav"))
    }

    func test_supportedExtensions_containsM4A() {
        XCTAssertTrue(AudioLibraryViewModel.supportedExtensions.contains("m4a"))
    }

    func test_supportedExtensions_doesNotContainAAC() {
        XCTAssertFalse(AudioLibraryViewModel.supportedExtensions.contains("aac"))
    }

    func test_supportedExtensions_doesNotContainFLAC() {
        XCTAssertFalse(AudioLibraryViewModel.supportedExtensions.contains("flac"))
    }

    func test_supportedContentTypes_hasThreeEntries() {
        XCTAssertEqual(AudioLibraryViewModel.supportedContentTypes.count, 3)
    }

    // MARK: - importAudioFile — accepted formats

    func test_import_mp3_succeeds() throws {
        let url = try makeFakeFile(named: "track.mp3")
        try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "track.mp3")
    }

    func test_import_wav_succeeds() throws {
        let url = try makeFakeFile(named: "track.wav")
        try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "track.wav")
    }

    func test_import_m4a_succeeds() throws {
        let url = try makeFakeFile(named: "track.m4a")
        try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].filename, "track.m4a")
    }

    func test_import_mp3Uppercase_succeeds() throws {
        let url = try makeFakeFile(named: "track.MP3")
        try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files.count, 1)
    }

    func test_import_wavUppercase_succeeds() throws {
        let url = try makeFakeFile(named: "track.WAV")
        try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files.count, 1)
    }

    func test_import_m4aUppercase_succeeds() throws {
        let url = try makeFakeFile(named: "track.M4A")
        try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files.count, 1)
    }

    // MARK: - importAudioFile — rejected formats

    func test_import_aac_throwsUnsupportedFormat() throws {
        let url = try makeFakeFile(named: "track.aac")
        XCTAssertThrowsError(
            try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        ) { error in
            guard case AudioImportError.unsupportedFormat(let ext) = error else {
                return XCTFail("Expected .unsupportedFormat, got \(error)")
            }
            XCTAssertEqual(ext, "aac")
        }
    }

    func test_import_flac_throwsUnsupportedFormat() throws {
        let url = try makeFakeFile(named: "track.flac")
        XCTAssertThrowsError(
            try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        ) { error in
            guard case AudioImportError.unsupportedFormat = error else {
                return XCTFail("Expected .unsupportedFormat, got \(error)")
            }
        }
    }

    func test_import_txt_throwsUnsupportedFormat() throws {
        let url = try makeFakeFile(named: "notes.txt")
        XCTAssertThrowsError(
            try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        ) { error in
            guard case AudioImportError.unsupportedFormat = error else {
                return XCTFail("Expected .unsupportedFormat, got \(error)")
            }
        }
    }

    func test_import_noExtension_throwsUnsupportedFormat() throws {
        let url = try makeFakeFile(named: "track")
        XCTAssertThrowsError(
            try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        ) { error in
            guard case AudioImportError.unsupportedFormat = error else {
                return XCTFail("Expected .unsupportedFormat, got \(error)")
            }
        }
    }

    // MARK: - importAudioFile — sets correct properties

    func test_import_wav_setsLocalPathToFilename() throws {
        let url = try makeFakeFile(named: "drums.wav")
        try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files[0].localPath, "drums.wav")
    }

    func test_import_m4a_setsLocalPathToFilename() throws {
        let url = try makeFakeFile(named: "voice.m4a")
        try sut.importAudioFile(from: url, existingFiles: [], context: modelContext)
        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files[0].localPath, "voice.m4a")
    }

    // MARK: - importAudioFile — duplicate detection (all formats)

    func test_import_duplicateWAV_throwsDuplicateError() throws {
        let url = try makeFakeFile(named: "drums.wav")
        let existing = AudioFile(filename: "drums.wav", localPath: "drums.wav")
        XCTAssertThrowsError(
            try sut.importAudioFile(from: url, existingFiles: [existing], context: modelContext)
        ) { error in
            guard case AudioImportError.duplicateFilename(let name) = error else {
                return XCTFail("Expected .duplicateFilename, got \(error)")
            }
            XCTAssertEqual(name, "drums.wav")
        }
    }

    func test_import_duplicateM4A_throwsDuplicateError() throws {
        let url = try makeFakeFile(named: "voice.m4a")
        let existing = AudioFile(filename: "voice.m4a", localPath: "voice.m4a")
        XCTAssertThrowsError(
            try sut.importAudioFile(from: url, existingFiles: [existing], context: modelContext)
        ) { error in
            guard case AudioImportError.duplicateFilename = error else {
                return XCTFail("Expected .duplicateFilename, got \(error)")
            }
        }
    }

    func test_import_sameNameDifferentFormat_isNotDuplicate() throws {
        // "track.mp3" and "track.wav" are different files
        let url = try makeFakeFile(named: "track.wav")
        let existing = AudioFile(filename: "track.mp3", localPath: "track.mp3")
        try sut.importAudioFile(from: url, existingFiles: [existing], context: modelContext)
        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(files.count, 1)
    }

    func test_import_mixedFormats_allInserted() throws {
        try sut.importAudioFile(from: try makeFakeFile(named: "a.mp3"), existingFiles: [], context: modelContext)
        let afterMP3 = try modelContext.fetch(FetchDescriptor<AudioFile>())
        try sut.importAudioFile(from: try makeFakeFile(named: "b.wav"), existingFiles: afterMP3, context: modelContext)
        let afterWAV = try modelContext.fetch(FetchDescriptor<AudioFile>())
        try sut.importAudioFile(from: try makeFakeFile(named: "c.m4a"), existingFiles: afterWAV, context: modelContext)
        let finalFiles = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertEqual(finalFiles.count, 3)
    }

    // MARK: - AudioImportError — localised descriptions

    func test_error_unsupportedFormat_includesExtension() {
        let error = AudioImportError.unsupportedFormat("aac")
        XCTAssertTrue(error.errorDescription?.contains("aac") ?? false)
    }

    func test_error_unsupportedFormat_listsSupportedFormats() {
        let error = AudioImportError.unsupportedFormat("aac")
        let desc = error.errorDescription ?? ""
        // All three supported formats should be mentioned
        XCTAssertTrue(desc.contains("mp3"), "Expected 'mp3' in: \(desc)")
        XCTAssertTrue(desc.contains("wav"), "Expected 'wav' in: \(desc)")
        XCTAssertTrue(desc.contains("m4a"), "Expected 'm4a' in: \(desc)")
    }

    func test_error_duplicateFilename_includesFilename() {
        let error = AudioImportError.duplicateFilename("my_track.wav")
        XCTAssertTrue(error.errorDescription?.contains("my_track.wav") ?? false)
    }

    func test_error_copyFailed_includesUnderlyingDescription() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "disk full"])
        let error = AudioImportError.copyFailed(underlying)
        XCTAssertTrue(error.errorDescription?.contains("disk full") ?? false)
    }

    // MARK: - deleteAudioFile

    func test_delete_removesRecordFromContext() throws {
        let file = AudioFile(filename: "track.wav", localPath: "track.wav")
        modelContext.insert(file)
        sut.deleteAudioFile(file, context: modelContext)
        let files = try modelContext.fetch(FetchDescriptor<AudioFile>())
        XCTAssertTrue(files.isEmpty)
    }
}
