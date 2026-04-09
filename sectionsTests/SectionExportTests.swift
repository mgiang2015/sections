import XCTest
@testable import sections

@MainActor
final class SectionExportTests: XCTestCase {

    // MARK: - SectionExport init(from:)

    func test_initFromSection_copiesAllFields() {
        let section = AudioSection(name: "Chorus", startTime: 30, endTime: 90, playbackMode: .playOnce)
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        section.lastPlayed = fixedDate

        let dto = SectionExport(from: section)

        XCTAssertEqual(dto.name, "Chorus")
        XCTAssertEqual(dto.startTime, 30)
        XCTAssertEqual(dto.endTime, 90)
        XCTAssertEqual(dto.playbackMode, .playOnce)
        XCTAssertEqual(dto.lastPlayed, fixedDate)
    }

    // MARK: - toSection()

    func test_toSection_restoresAllFields() {
        let section = AudioSection(name: "Verse", startTime: 10, endTime: 50, playbackMode: .loop)
        let fixedDate = Date(timeIntervalSince1970: 1_600_000_000)
        section.lastPlayed = fixedDate

        let dto = SectionExport(from: section)
        let restored = dto.toSection()

        XCTAssertEqual(restored.name, "Verse")
        XCTAssertEqual(restored.startTime, 10)
        XCTAssertEqual(restored.endTime, 50)
        XCTAssertEqual(restored.playbackMode, .loop)
        XCTAssertEqual(restored.lastPlayed, fixedDate)
    }

    // MARK: - AudioFileExport Codable round-trip

    func test_audioFileExport_encodeDecode_roundTrip() throws {
        let section = AudioSection(name: "Bridge", startTime: 60, endTime: 120, playbackMode: .loop)
        section.lastPlayed = Date(timeIntervalSince1970: 1_700_000_000)

        let original = AudioFileExport(
            filename: "my_track.mp3",
            sections: [SectionExport(from: section)]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AudioFileExport.self, from: data)

        XCTAssertEqual(decoded.filename, "my_track.mp3")
        XCTAssertEqual(decoded.sections.count, 1)
        XCTAssertEqual(decoded.sections[0].name, "Bridge")
        XCTAssertEqual(decoded.sections[0].startTime, 60)
        XCTAssertEqual(decoded.sections[0].endTime, 120)
        XCTAssertEqual(decoded.sections[0].playbackMode, .loop)
    }

    func test_audioFileExport_emptySections_encodesAndDecodes() throws {
        let original = AudioFileExport(filename: "empty.mp3", sections: [])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AudioFileExport.self, from: data)

        XCTAssertEqual(decoded.filename, "empty.mp3")
        XCTAssertTrue(decoded.sections.isEmpty)
    }

    func test_audioFileExport_multipleSections_preservesOrder() throws {
        let s1 = AudioSection(name: "Intro", startTime: 0, endTime: 15)
        let s2 = AudioSection(name: "Verse", startTime: 15, endTime: 60)
        let s3 = AudioSection(name: "Chorus", startTime: 60, endTime: 90)

        let original = AudioFileExport(
            filename: "song.mp3",
            sections: [s1, s2, s3].map { SectionExport(from: $0) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AudioFileExport.self, from: data)

        XCTAssertEqual(decoded.sections.count, 3)
        XCTAssertEqual(decoded.sections[0].name, "Intro")
        XCTAssertEqual(decoded.sections[1].name, "Verse")
        XCTAssertEqual(decoded.sections[2].name, "Chorus")
    }

    // MARK: - JSON schema (BRD §5.3)

    func test_json_containsExpectedKeys() throws {
        let section = AudioSection(name: "Chorus", startTime: 62, endTime: 94, playbackMode: .loop)
        section.lastPlayed = Date(timeIntervalSince1970: 1_700_000_000)

        let export = AudioFileExport(filename: "track.mp3", sections: [SectionExport(from: section)])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)

        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(json["filename"])
        XCTAssertNotNil(json["sections"])

        let sections = try XCTUnwrap(json["sections"] as? [[String: Any]])
        let first = try XCTUnwrap(sections.first)
        XCTAssertNotNil(first["name"])
        XCTAssertNotNil(first["startTime"])
        XCTAssertNotNil(first["endTime"])
        XCTAssertNotNil(first["lastPlayed"])
        XCTAssertNotNil(first["playbackMode"])
    }
}
