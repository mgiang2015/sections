# SectionsTests

Unit test suite for the Sections iOS app.

## Adding the Test Target in Xcode

1. In Xcode, go to **File → New → Target**
2. Choose **Unit Testing Bundle**
3. Name it `SectionsTests`
4. Make sure **Target to be Tested** is set to `Sections`
5. Click **Finish**
6. Delete the auto-generated `SectionsTests.swift` placeholder file
7. Drag all files from this folder into the `SectionsTests` group in Xcode
8. Make sure each file's **Target Membership** is set to `SectionsTests` only (not `Sections`)

## Running Tests

- Run all tests: **⌘U**
- Run a single test file: open the file and click the diamond next to the class name
- Run a single test: click the diamond next to the individual `func test_...`

## Test File Map

| File | What it tests |
|------|--------------|
| `TimeFormatterTests.swift` | `format()` and `parse()` — all edge cases including round-trips |
| `PlaybackModeTests.swift` | `PlaybackMode` enum — display names, raw values, Codable round-trip |
| `AudioSectionTests.swift` | `AudioSection` model — init, duration, formatted times, overlap allowance |
| `AudioFileTests.swift` | `AudioFile` model — init, resolvedURL, sectionsSortedByLastPlayed |
| `SectionExportTests.swift` | `SectionExport` / `AudioFileExport` DTOs — init, toSection(), JSON round-trip, schema shape |
| `AudioLibraryViewModelTests.swift` | Import validation (not-MP3, duplicate, copy), delete, error messages |
| `ExportImportViewModelTests.swift` | Export filename/content, import validation, merge logic, round-trip |
| `PlaybackViewModelTests.swift` | State machine — initial state, togglePlaybackMode, rate, no-crash guards |

## Coverage Notes

- **AVFoundation playback** (`AVAudioPlayer.play()`, timer ticks) cannot be tested in the unit test
  host because there is no audio hardware. `PlaybackViewModelTests` covers all testable state logic
  and documents behaviour at the boundary. Integration testing of actual playback should be done
  manually via TestFlight on a real device.

- **SwiftData persistence** is tested using `ModelConfiguration(isStoredInMemoryOnly: true)` so
  tests are fast, isolated, and require no cleanup of on-disk stores.

- **File system operations** use a per-test UUID temp directory created in `setUp` and deleted in
  `tearDown` to ensure full isolation.
