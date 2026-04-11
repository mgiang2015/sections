import XCTest
import SwiftData
@testable import sections

@MainActor
final class AudioFileTests: XCTestCase {

    // MARK: - Init

    func test_init_setsProperties() {
        let before = Date()
        let file = AudioFile(filename: "track.mp3", localPath: "track.mp3")
        let after = Date()

        XCTAssertEqual(file.filename, "track.mp3")
        XCTAssertEqual(file.localPath, "track.mp3")
        XCTAssertFalse(file.id.uuidString.isEmpty)
        XCTAssertGreaterThanOrEqual(file.dateAdded, before)
        XCTAssertLessThanOrEqual(file.dateAdded, after)
        XCTAssertTrue(file.sections.isEmpty)
    }

    func test_init_eachInstanceGetsUniqueId() {
        let a = AudioFile(filename: "a.mp3", localPath: "a.mp3")
        let b = AudioFile(filename: "b.mp3", localPath: "b.mp3")
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: - resolvedURL

    func test_resolvedURL_appendsLocalPathToDocumentsDirectory() {
        let file = AudioFile(filename: "song.mp3", localPath: "song.mp3")
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        XCTAssertEqual(file.resolvedURL, documents.appendingPathComponent("song.mp3"))
    }

    func test_resolvedURL_usesLocalPath_notFilename() {
        let file = AudioFile(filename: "display.mp3", localPath: "stored/internal.mp3")
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        XCTAssertEqual(file.resolvedURL, documents.appendingPathComponent("stored/internal.mp3"))
    }

    // MARK: - sectionsSortedByLastPlayed

    func test_sectionsSortedByLastPlayed_returnsNewestFirst() {
        let file = AudioFile(filename: "track.mp3", localPath: "track.mp3")

        let old = AudioSection(name: "Old", startTime: 0, endTime: 30)
        old.lastPlayed = Date(timeIntervalSinceNow: -3600)

        let recent = AudioSection(name: "Recent", startTime: 30, endTime: 60)
        recent.lastPlayed = Date(timeIntervalSinceNow: -60)

        let newest = AudioSection(name: "Newest", startTime: 60, endTime: 90)
        newest.lastPlayed = Date()

        file.sections = [old, recent, newest]

        let sorted = file.sectionsSortedByLastPlayed
        XCTAssertEqual(sorted[0].name, "Newest")
        XCTAssertEqual(sorted[1].name, "Recent")
        XCTAssertEqual(sorted[2].name, "Old")
    }

    func test_sectionsSortedByLastPlayed_emptySections_returnsEmpty() {
        let file = AudioFile(filename: "track.mp3", localPath: "track.mp3")
        XCTAssertTrue(file.sectionsSortedByLastPlayed.isEmpty)
    }

    func test_sectionsSortedByLastPlayed_singleSection_returnsSingleItem() {
        let file = AudioFile(filename: "track.mp3", localPath: "track.mp3")
        file.sections = [AudioSection(name: "Only", startTime: 0, endTime: 30)]
        XCTAssertEqual(file.sectionsSortedByLastPlayed.count, 1)
    }
}
