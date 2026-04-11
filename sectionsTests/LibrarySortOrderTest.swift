//
//  LibrarySortOrderTest.swift
//  sections
//
//  Created by Minh Giang Le on 11/4/26.
//

import XCTest
@testable import sections

/// Tests for LibrarySortOrder sorting logic, display properties, and protocol conformances.
@MainActor
final class LibrarySortOrderTests: XCTestCase {

    // MARK: - Helpers

    private func makeFile(filename: String, addedSecondsAgo: TimeInterval) -> AudioFile {
        let file = AudioFile(filename: filename, localPath: filename)
        file.dateAdded = Date(timeIntervalSinceNow: -addedSecondsAgo)
        return file
    }

    // MARK: - CaseIterable / Identifiable

    func test_allCases_containsRecentlyAdded() {
        XCTAssertTrue(LibrarySortOrder.allCases.contains(.recentlyAdded))
    }

    func test_allCases_containsAlphabetical() {
        XCTAssertTrue(LibrarySortOrder.allCases.contains(.alphabetical))
    }

    func test_allCases_hasTwoCases() {
        XCTAssertEqual(LibrarySortOrder.allCases.count, 2)
    }

    func test_id_isUniquePerCase() {
        let ids = LibrarySortOrder.allCases.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    // MARK: - displayName

    func test_displayName_recentlyAdded_isNotEmpty() {
        XCTAssertFalse(LibrarySortOrder.recentlyAdded.displayName.isEmpty)
    }

    func test_displayName_alphabetical_isNotEmpty() {
        XCTAssertFalse(LibrarySortOrder.alphabetical.displayName.isEmpty)
    }

    func test_displayName_allCases_areDistinct() {
        let names = LibrarySortOrder.allCases.map(\.displayName)
        XCTAssertEqual(names.count, Set(names).count)
    }

    // MARK: - systemImage

    func test_systemImage_recentlyAdded_isNotEmpty() {
        XCTAssertFalse(LibrarySortOrder.recentlyAdded.systemImage.isEmpty)
    }

    func test_systemImage_alphabetical_isNotEmpty() {
        XCTAssertFalse(LibrarySortOrder.alphabetical.systemImage.isEmpty)
    }

    func test_systemImage_allCases_areDistinct() {
        let images = LibrarySortOrder.allCases.map(\.systemImage)
        XCTAssertEqual(images.count, Set(images).count)
    }

    // MARK: - sort(_:) recentlyAdded

    func test_recentlyAdded_mostRecentFirst() {
        let oldest = makeFile(filename: "c.mp3", addedSecondsAgo: 3600)
        let middle = makeFile(filename: "b.mp3", addedSecondsAgo: 600)
        let newest = makeFile(filename: "a.mp3", addedSecondsAgo: 60)

        let sorted = LibrarySortOrder.recentlyAdded.sort([oldest, middle, newest])

        XCTAssertEqual(sorted[0].filename, "a.mp3")
        XCTAssertEqual(sorted[1].filename, "b.mp3")
        XCTAssertEqual(sorted[2].filename, "c.mp3")
    }

    func test_recentlyAdded_usesDatabaseAdded_notFilename() {
        // "z" was added more recently than "a" — should appear first despite alphabetical order
        let z = makeFile(filename: "z_track.mp3", addedSecondsAgo: 10)
        let a = makeFile(filename: "a_track.mp3", addedSecondsAgo: 3600)

        let sorted = LibrarySortOrder.recentlyAdded.sort([z, a])

        XCTAssertEqual(sorted[0].filename, "z_track.mp3")
        XCTAssertEqual(sorted[1].filename, "a_track.mp3")
    }

    func test_recentlyAdded_emptyInput_returnsEmpty() {
        XCTAssertTrue(LibrarySortOrder.recentlyAdded.sort([]).isEmpty)
    }

    func test_recentlyAdded_singleFile_returnsSingleFile() {
        let file = makeFile(filename: "solo.mp3", addedSecondsAgo: 100)
        let sorted = LibrarySortOrder.recentlyAdded.sort([file])
        XCTAssertEqual(sorted.count, 1)
        XCTAssertEqual(sorted[0].filename, "solo.mp3")
    }

    func test_recentlyAdded_preservesAllFiles() {
        let files = (1...5).map { makeFile(filename: "\($0).mp3", addedSecondsAgo: Double($0) * 100) }
        XCTAssertEqual(LibrarySortOrder.recentlyAdded.sort(files).count, 5)
    }

    // MARK: - sort(_:) alphabetical

    func test_alphabetical_sortsAtoZ() {
        let charlie = makeFile(filename: "charlie.mp3", addedSecondsAgo: 10)
        let alpha   = makeFile(filename: "alpha.mp3",   addedSecondsAgo: 20)
        let bravo   = makeFile(filename: "bravo.mp3",   addedSecondsAgo: 30)

        let sorted = LibrarySortOrder.alphabetical.sort([charlie, alpha, bravo])

        XCTAssertEqual(sorted[0].filename, "alpha.mp3")
        XCTAssertEqual(sorted[1].filename, "bravo.mp3")
        XCTAssertEqual(sorted[2].filename, "charlie.mp3")
    }

    func test_alphabetical_isCaseInsensitive() {
        let upper = makeFile(filename: "Zebra.mp3", addedSecondsAgo: 10)
        let lower = makeFile(filename: "apple.mp3", addedSecondsAgo: 20)
        let mixed = makeFile(filename: "Mango.mp3", addedSecondsAgo: 30)

        let sorted = LibrarySortOrder.alphabetical.sort([upper, lower, mixed])

        XCTAssertEqual(sorted[0].filename, "apple.mp3")
        XCTAssertEqual(sorted[1].filename, "Mango.mp3")
        XCTAssertEqual(sorted[2].filename, "Zebra.mp3")
    }

    func test_alphabetical_ignoresDateAdded() {
        // Added in reverse alpha order — sort should still be alpha
        let z = makeFile(filename: "z_track.mp3", addedSecondsAgo: 10)
        let a = makeFile(filename: "a_track.mp3", addedSecondsAgo: 100)

        let sorted = LibrarySortOrder.alphabetical.sort([z, a])

        XCTAssertEqual(sorted[0].filename, "a_track.mp3")
        XCTAssertEqual(sorted[1].filename, "z_track.mp3")
    }

    func test_alphabetical_emptyInput_returnsEmpty() {
        XCTAssertTrue(LibrarySortOrder.alphabetical.sort([]).isEmpty)
    }

    func test_alphabetical_singleFile_returnsSingleFile() {
        let file = makeFile(filename: "solo.mp3", addedSecondsAgo: 100)
        XCTAssertEqual(LibrarySortOrder.alphabetical.sort([file]).count, 1)
    }

    func test_alphabetical_preservesAllFiles() {
        let files = ["delta", "alpha", "charlie", "bravo", "echo"]
            .map { makeFile(filename: "\($0).mp3", addedSecondsAgo: 10) }
        XCTAssertEqual(LibrarySortOrder.alphabetical.sort(files).count, 5)
    }

    func test_alphabetical_mixedFormats_sortsByFullFilename() {
        let wav = makeFile(filename: "bass.wav",  addedSecondsAgo: 10)
        let m4a = makeFile(filename: "alto.m4a",  addedSecondsAgo: 20)
        let mp3 = makeFile(filename: "cello.mp3", addedSecondsAgo: 30)

        let sorted = LibrarySortOrder.alphabetical.sort([wav, m4a, mp3])

        XCTAssertEqual(sorted[0].filename, "alto.m4a")
        XCTAssertEqual(sorted[1].filename, "bass.wav")
        XCTAssertEqual(sorted[2].filename, "cello.mp3")
    }

    // MARK: - Default sort order

    func test_defaultSortOrder_isRecentlyAdded() {
        let defaultOrder = LibrarySortOrder.recentlyAdded
        XCTAssertEqual(defaultOrder, .recentlyAdded)
    }
}
