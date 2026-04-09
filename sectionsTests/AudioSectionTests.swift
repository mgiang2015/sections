import XCTest
import SwiftData
@testable import sections

@MainActor
final class AudioSectionTests: XCTestCase {

    // MARK: - Init

    func test_init_setsAllProperties() {
        let before = Date()
        let section = AudioSection(name: "Chorus", startTime: 30, endTime: 90)
        let after = Date()

        XCTAssertFalse(section.id.uuidString.isEmpty)
        XCTAssertEqual(section.name, "Chorus")
        XCTAssertEqual(section.startTime, 30)
        XCTAssertEqual(section.endTime, 90)
        XCTAssertEqual(section.playbackMode, .loop)
        // lastPlayed should be set to creation time per BRD
        XCTAssertGreaterThanOrEqual(section.lastPlayed, before)
        XCTAssertLessThanOrEqual(section.lastPlayed, after)
    }

    func test_init_defaultPlaybackMode_isLoop() {
        let section = AudioSection(name: "Verse", startTime: 0, endTime: 60)
        XCTAssertEqual(section.playbackMode, .loop)
    }

    func test_init_customPlaybackMode() {
        let section = AudioSection(name: "Bridge", startTime: 10, endTime: 20, playbackMode: .playOnce)
        XCTAssertEqual(section.playbackMode, .playOnce)
    }

    func test_init_eachInstanceGetsUniqueId() {
        let a = AudioSection(name: "A", startTime: 0, endTime: 10)
        let b = AudioSection(name: "B", startTime: 0, endTime: 10)
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: - duration

    func test_duration_simpleCase() {
        let section = AudioSection(name: "Test", startTime: 10, endTime: 70)
        XCTAssertEqual(section.duration, 60)
    }

    func test_duration_fractionalSeconds() {
        let section = AudioSection(name: "Test", startTime: 1.5, endTime: 4.0)
        XCTAssertEqual(section.duration, 2.5, accuracy: 0.001)
    }

    func test_duration_zeroLength() {
        let section = AudioSection(name: "Test", startTime: 30, endTime: 30)
        XCTAssertEqual(section.duration, 0)
    }

    // MARK: - startTimeFormatted / endTimeFormatted

    func test_startTimeFormatted() {
        let section = AudioSection(name: "Test", startTime: 62, endTime: 125)
        XCTAssertEqual(section.startTimeFormatted, "1:02")
    }

    func test_endTimeFormatted() {
        let section = AudioSection(name: "Test", startTime: 62, endTime: 125)
        XCTAssertEqual(section.endTimeFormatted, "2:05")
    }

    func test_startTimeFormatted_zero() {
        let section = AudioSection(name: "Test", startTime: 0, endTime: 30)
        XCTAssertEqual(section.startTimeFormatted, "0:00")
    }

    // MARK: - Sections can overlap (BRD §4.4)

    func test_overlappingSections_canCoexist() {
        // BRD explicitly allows sections to overlap
        let a = AudioSection(name: "A", startTime: 0, endTime: 60)
        let b = AudioSection(name: "B", startTime: 30, endTime: 90)
        // Just verify both can be created with overlapping times — no crash or assertion
        XCTAssertEqual(a.startTime, 0)
        XCTAssertEqual(b.startTime, 30)
        XCTAssertLessThan(a.startTime, b.endTime)
        XCTAssertLessThan(b.startTime, a.endTime)
    }
}
