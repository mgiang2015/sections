import XCTest
@testable import sections

final class TimeFormatterTests: XCTestCase {

    // MARK: - format(_:)

    func test_format_zero() {
        XCTAssertEqual(TimeFormatter.format(0), "0:00")
    }

    func test_format_lessThanOneMinute() {
        XCTAssertEqual(TimeFormatter.format(9), "0:09")
        XCTAssertEqual(TimeFormatter.format(59), "0:59")
    }

    func test_format_exactlyOneMinute() {
        XCTAssertEqual(TimeFormatter.format(60), "1:00")
    }

    func test_format_minutesAndSeconds() {
        XCTAssertEqual(TimeFormatter.format(62), "1:02")
        XCTAssertEqual(TimeFormatter.format(90), "1:30")
        XCTAssertEqual(TimeFormatter.format(125), "2:05")
    }

    func test_format_largeValue() {
        // 15 minutes = 900 seconds (max expected per BRD)
        XCTAssertEqual(TimeFormatter.format(900), "15:00")
    }

    func test_format_truncatesDecimal() {
        // TimeInterval is Double — fractional seconds should be truncated, not rounded
        XCTAssertEqual(TimeFormatter.format(61.9), "1:01")
        XCTAssertEqual(TimeFormatter.format(59.999), "0:59")
    }

    func test_format_negative_clampsToZero() {
        XCTAssertEqual(TimeFormatter.format(-5), "0:00")
    }

    func test_format_secondsPaddedToTwoDigits() {
        XCTAssertEqual(TimeFormatter.format(61), "1:01")
        XCTAssertEqual(TimeFormatter.format(600), "10:00")
    }

    // MARK: - parse(_:)

    func test_parse_zero() {
        XCTAssertEqual(TimeFormatter.parse("0:00"), 0)
    }

    func test_parse_secondsOnly() {
        XCTAssertEqual(TimeFormatter.parse("0:30"), 30)
        XCTAssertEqual(TimeFormatter.parse("0:59"), 59)
    }

    func test_parse_minutesAndSeconds() {
        XCTAssertEqual(TimeFormatter.parse("1:00"), 60)
        XCTAssertEqual(TimeFormatter.parse("1:30"), 90)
        XCTAssertEqual(TimeFormatter.parse("2:05"), 125)
    }

    func test_parse_largeValue() {
        XCTAssertEqual(TimeFormatter.parse("15:00"), 900)
    }

    func test_parse_trimsWhitespace() {
        XCTAssertEqual(TimeFormatter.parse("  1:30  "), 90)
    }

    func test_parse_invalidSeconds_returnsNil() {
        // Seconds must be 0–59
        XCTAssertNil(TimeFormatter.parse("0:60"))
        XCTAssertNil(TimeFormatter.parse("1:99"))
    }

    func test_parse_missingColon_returnsNil() {
        XCTAssertNil(TimeFormatter.parse("130"))
        XCTAssertNil(TimeFormatter.parse(""))
    }

    func test_parse_nonNumeric_returnsNil() {
        XCTAssertNil(TimeFormatter.parse("a:bc"))
        XCTAssertNil(TimeFormatter.parse("1:xx"))
    }

    func test_parse_negativeMinutes_returnsNil() {
        XCTAssertNil(TimeFormatter.parse("-1:00"))
    }

    func test_parse_negativeSeconds_returnsNil() {
        XCTAssertNil(TimeFormatter.parse("1:-5"))
    }

    func test_parse_tooManyParts_returnsNil() {
        XCTAssertNil(TimeFormatter.parse("1:2:3"))
    }

    // MARK: - Round-trip

    func test_roundTrip_formatThenParse() {
        let values: [TimeInterval] = [0, 30, 60, 90, 125, 600, 900]
        for value in values {
            let formatted = TimeFormatter.format(value)
            let parsed = TimeFormatter.parse(formatted)
            XCTAssertEqual(parsed, value, "Round-trip failed for \(value)s → \"\(formatted)\"")
        }
    }
}
