import XCTest
@testable import sections

final class PlaybackModeTests: XCTestCase {

    // MARK: - displayName

    func test_displayName_loop() {
        XCTAssertEqual(PlaybackMode.loop.displayName, "Loop")
    }

    func test_displayName_playOnce() {
        XCTAssertEqual(PlaybackMode.playOnce.displayName, "Play Once")
    }

    // MARK: - Raw values (used in JSON export/import)

    func test_rawValue_loop() {
        XCTAssertEqual(PlaybackMode.loop.rawValue, "loop")
    }

    func test_rawValue_playOnce() {
        XCTAssertEqual(PlaybackMode.playOnce.rawValue, "playOnce")
    }

    // MARK: - Codable round-trip

    func test_encode_loop() throws {
        let encoded = try JSONEncoder().encode(PlaybackMode.loop)
        let string = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(string, "\"loop\"")
    }

    func test_encode_playOnce() throws {
        let encoded = try JSONEncoder().encode(PlaybackMode.playOnce)
        let string = String(data: encoded, encoding: .utf8)
        XCTAssertEqual(string, "\"playOnce\"")
    }

    func test_decode_loop() throws {
        let data = "\"loop\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PlaybackMode.self, from: data)
        XCTAssertEqual(decoded, .loop)
    }

    func test_decode_playOnce() throws {
        let data = "\"playOnce\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PlaybackMode.self, from: data)
        XCTAssertEqual(decoded, .playOnce)
    }

    func test_decode_unknownValue_throws() {
        let data = "\"repeat\"".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(PlaybackMode.self, from: data))
    }

    // MARK: - CaseIterable

    func test_allCases_containsBothModes() {
        XCTAssertTrue(PlaybackMode.allCases.contains(.loop))
        XCTAssertTrue(PlaybackMode.allCases.contains(.playOnce))
        XCTAssertEqual(PlaybackMode.allCases.count, 2)
    }
}
